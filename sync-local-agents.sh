#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$script_dir"
dry_run=false
delete_extra=false
interactive_mode=false
selected_platforms=()
sync_agents=true
sync_skills=true
sync_scope="both"
cli_claude_model=""
cli_opencode_model=""
cli_codex_model=""
file_claude_model=""
file_opencode_model=""
file_codex_model=""
env_claude_model="${CLAUDE_MODEL:-}"
env_opencode_model="${OPENCODE_MODEL:-}"
env_codex_model="${CODEX_MODEL:-}"
claude_model=""
opencode_model=""
codex_model=""

trim() {
  local value="$1"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"

  printf '%s' "$value"
}

to_lower() {
  local value="$1"

  printf '%s' "$value" | tr '[:upper:]' '[:lower:]'
}

strip_wrapping_quotes() {
  local value="$1"

  if [[ "$value" == \"*\" && "$value" == *\" ]]; then
    value="${value:1:${#value}-2}"
  elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
    value="${value:1:${#value}-2}"
  fi

  printf '%s' "$value"
}

load_model_from_file() {
  local config_file="$1"
  local expected_key="$2"
  local line=""
  local key=""
  local value=""

  [[ -f "$config_file" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(trim "$line")"
    [[ -z "$line" || "$line" == \#* ]] && continue

    key="${line%%=*}"
    value="${line#*=}"

    key="$(trim "$key")"
    value="$(trim "$value")"

    case "$key" in
      "$expected_key")
        value="$(strip_wrapping_quotes "$value")"

        if [[ -n "$value" ]]; then
          printf '%s' "$value"
          return 0
        fi
        ;;
      *)
        echo "Ignoring unsupported setting in $config_file: $key" >&2
        ;;
    esac
  done < "$config_file"

  return 0
}

resolve_model_override() {
  local cli_value="$1"
  local env_value="$2"
  local file_value="$3"

  if [[ -n "$cli_value" ]]; then
    printf '%s' "$cli_value"
  elif [[ -n "$env_value" ]]; then
    printf '%s' "$env_value"
  else
    printf '%s' "$file_value"
  fi
}

apply_model_override() {
  local target_dir="$1"
  local model_value="$2"
  local file=""

  [[ -n "$model_value" ]] || return 0
  [[ -d "$target_dir" ]] || return 0

  while IFS= read -r file; do
    MODEL_OVERRIDE="$model_value" perl -0pi -e 's/^model:\h*.*/model: $ENV{MODEL_OVERRIDE}/m' "$file"
  done < <(find "$target_dir" -type f -name '*.md' | sort)
}

preview_model_override() {
  local source_dir="$1"
  local model_value="$2"
  local file=""

  [[ -n "$model_value" ]] || return 0
  [[ -d "$source_dir" ]] || return 0

  while IFS= read -r file; do
    printf 'Would override model in synced copy of %s -> %s\n' "$file" "$model_value"
  done < <(find "$source_dir" -type f -name '*.md' | sort)
}

file_claude_model="$(load_model_from_file "$repo_root/.claude.local.env" "CLAUDE_MODEL")"
file_opencode_model="$(load_model_from_file "$repo_root/.opencode.local.env" "OPENCODE_MODEL")"
file_codex_model="$(load_model_from_file "$repo_root/.codex.local.env" "CODEX_MODEL")"

usage() {
  cat <<'EOF'
Usage: ./sync-local-agents.sh [--dry-run] [--delete] [--platform claude|opencode|codex]
	       [--sync both|agents|skills] [--interactive]
	       [--claude-model MODEL]
	       [--opencode-model MODEL]
	       [--codex-model MODEL]

Copies agents and skills from this repository into the matching local config
directories in your home folder.

Options:
  --dry-run   Preview changes without writing files
  --delete    Remove local files that no longer exist in this repo
              When syncing selected entries, deletion is scoped to those
              selected directories only
  --sync      Non-interactive scope: both (default), agents, or skills
  --interactive
              Prompt for sync scope and optional per-platform selection
              of individual agents/skills (requires TTY)
  --claude-model
              Override the model used in synced Claude agent frontmatter
              Precedence: --claude-model > CLAUDE_MODEL env var >
              ./.claude.local.env > repo defaults
  --opencode-model
              Override the model used in synced OpenCode agent frontmatter
              Precedence: --opencode-model > OPENCODE_MODEL env var >
              ./.opencode.local.env > repo defaults
  --codex-model
              Override the model used in synced Codex agent frontmatter
              Precedence: --codex-model > CODEX_MODEL env var >
              ./.codex.local.env > repo defaults

Examples:
  ./sync-local-agents.sh
  ./sync-local-agents.sh --dry-run
  ./sync-local-agents.sh --delete
  ./sync-local-agents.sh --sync agents
  ./sync-local-agents.sh --sync skills --platform claude
  ./sync-local-agents.sh --interactive
  ./sync-local-agents.sh --platform claude --claude-model sonnet
  ./sync-local-agents.sh --platform opencode
  ./sync-local-agents.sh --opencode-model openai/gpt-5.4
  ./sync-local-agents.sh --platform codex --codex-model openai/gpt-5.4
EOF
}

set_sync_scope() {
  local value="$1"

  case "$value" in
    both)
      sync_agents=true
      sync_skills=true
      sync_scope="both"
      ;;
    agents)
      sync_agents=true
      sync_skills=false
      sync_scope="agents"
      ;;
    skills)
      sync_agents=false
      sync_skills=true
      sync_scope="skills"
      ;;
    *)
      echo "Unsupported value for --sync: $value (expected: both|agents|skills)" >&2
      exit 1
      ;;
  esac
}

list_top_level_entries() {
  local source_dir="$1"

  [[ -d "$source_dir" ]] || return 0

  find "$source_dir" -mindepth 1 -maxdepth 1 -exec basename {} \; | sort
}

collect_selected_entries() {
  local source_dir="$1"
  local label="$2"
  local platform="$3"
  local __result_var="$4"
  local all_entries=()
  local selected_entries=()
  local index=1
  local answer=""
  local input=""
  local token=""
  local -a tokens=()
  local listed_entry=""

  while IFS= read -r listed_entry; do
    all_entries+=("$listed_entry")
  done < <(list_top_level_entries "$source_dir")

  if [[ ${#all_entries[@]} -eq 0 ]]; then
    printf -v "$__result_var" '%s' ""
    return
  fi

  printf 'Available %s for %s:\n' "$label" "$platform"
  for entry in "${all_entries[@]}"; do
    printf '  [%d] %s\n' "$index" "$entry"
    ((index++))
  done

  read -r -p "Sync all $label for $platform? [Y/n]: " answer
  answer="$(trim "$answer")"
  answer="$(to_lower "$answer")"

  if [[ -z "$answer" || "$answer" == "y" || "$answer" == "yes" ]]; then
    printf -v "$__result_var" '*'
    return
  fi

  read -r -p "Enter comma-separated numbers to sync (empty = skip $label): " input
  input="${input// /}"

  if [[ -z "$input" ]]; then
    printf -v "$__result_var" '%s' ""
    return
  fi

  IFS=',' read -r -a tokens <<< "$input"
  for token in "${tokens[@]}"; do
    if [[ "$token" =~ ^[0-9]+$ ]] && (( token >= 1 && token <= ${#all_entries[@]} )); then
      selected_entries+=("${all_entries[token-1]}")
    else
      echo "Ignoring invalid selection: $token" >&2
    fi
  done

  if [[ ${#selected_entries[@]} -eq 0 ]]; then
    printf -v "$__result_var" '%s' ""
    return
  fi

  printf -v "$__result_var" '%s' "$(IFS='|'; printf '%s' "${selected_entries[*]}")"
}

expand_selection() {
  local source_dir="$1"
  local selection="$2"
  local __result_var="$3"
  local entries=()
  local listed_entry=""

  if [[ "$selection" == "*" ]]; then
    while IFS= read -r listed_entry; do
      entries+=("$listed_entry")
    done < <(list_top_level_entries "$source_dir")
  elif [[ -n "$selection" ]]; then
    IFS='|' read -r -a entries <<< "$selection"
  fi

  printf -v "$__result_var" '%s' "$(IFS='|'; printf '%s' "${entries[*]-}")"
}

run_rsync_entry() {
  local source_path="$1"
  local target_path="$2"
  local args=()

  mkdir -p "$(dirname "$target_path")"

  if [[ -d "$source_path" ]]; then
    args=(-a "$source_path/" "$target_path/")
    if [[ "$delete_extra" == true ]]; then
      args=(--delete "${args[@]}")
    fi
  else
    args=(-a "$source_path" "$target_path")
  fi

  if [[ "$dry_run" == true ]]; then
    args=(--dry-run -av "${args[@]}")
  fi

  rsync "${args[@]}"
}

preview_model_override_for_entries() {
  local source_agents_dir="$1"
  local selection="$2"
  local model_value="$3"
  local selected_joined=""
  local selected=()
  local entry=""
  local file=""

  [[ -n "$model_value" ]] || return 0

  expand_selection "$source_agents_dir" "$selection" selected_joined
  if [[ -z "${selected_joined:-}" ]]; then
    return 0
  fi

  IFS='|' read -r -a selected <<< "$selected_joined"
  for entry in "${selected[@]}"; do
    if [[ -d "$source_agents_dir/$entry" ]]; then
      while IFS= read -r file; do
        printf 'Would override model in synced copy of %s -> %s\n' "$file" "$model_value"
      done < <(find "$source_agents_dir/$entry" -type f -name '*.md' | sort)
    elif [[ "$entry" == *.md ]]; then
      printf 'Would override model in synced copy of %s -> %s\n' "$source_agents_dir/$entry" "$model_value"
    fi
  done
}

apply_model_override_for_entries() {
  local source_agents_dir="$1"
  local target_agents_dir="$2"
  local selection="$3"
  local model_value="$4"
  local selected_joined=""
  local selected=()
  local entry=""
  local file=""
  local relative_path=""
  local target_file=""

  [[ -n "$model_value" ]] || return 0
  [[ -d "$target_agents_dir" ]] || return 0

  expand_selection "$source_agents_dir" "$selection" selected_joined
  if [[ -z "${selected_joined:-}" ]]; then
    return 0
  fi

  IFS='|' read -r -a selected <<< "$selected_joined"
  for entry in "${selected[@]}"; do
    if [[ -d "$source_agents_dir/$entry" ]]; then
      while IFS= read -r file; do
        relative_path="${file#"$source_agents_dir/"}"
        target_file="$target_agents_dir/$relative_path"
        [[ -f "$target_file" ]] || continue
        MODEL_OVERRIDE="$model_value" perl -0pi -e 's/^model:\h*.*/model: $ENV{MODEL_OVERRIDE}/m' "$target_file"
      done < <(find "$source_agents_dir/$entry" -type f -name '*.md' | sort)
    elif [[ "$entry" == *.md ]]; then
      target_file="$target_agents_dir/$entry"
      [[ -f "$target_file" ]] || continue
      MODEL_OVERRIDE="$model_value" perl -0pi -e 's/^model:\h*.*/model: $ENV{MODEL_OVERRIDE}/m' "$target_file"
    fi
  done
}

prompt_interactive_scope() {
  local answer=""

  if [[ ! -t 0 || ! -t 1 ]]; then
    echo "--interactive requires an interactive terminal (TTY stdin/stdout)." >&2
    exit 1
  fi

  read -r -p "What do you want to sync? [both/agents/skills] (default: $sync_scope): " answer
  answer="$(trim "$answer")"
  answer="$(to_lower "$answer")"
  [[ -z "$answer" ]] && answer="$sync_scope"
  set_sync_scope "$answer"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      dry_run=true
      ;;
    --delete)
      delete_extra=true
      ;;
    --interactive)
      interactive_mode=true
      ;;
    --sync)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --sync" >&2
        exit 1
      fi
      set_sync_scope "$2"
      shift
      ;;
    --claude-model)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --claude-model" >&2
        exit 1
      fi
      cli_claude_model="$2"
      shift
      ;;
    --platform)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --platform" >&2
        exit 1
      fi
      selected_platforms+=("$2")
      shift
      ;;
    --opencode-model)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --opencode-model" >&2
        exit 1
      fi
      cli_opencode_model="$2"
      shift
      ;;
    --codex-model)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --codex-model" >&2
        exit 1
      fi
      cli_codex_model="$2"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

claude_model="$(resolve_model_override "$cli_claude_model" "$env_claude_model" "$file_claude_model")"
opencode_model="$(resolve_model_override "$cli_opencode_model" "$env_opencode_model" "$file_opencode_model")"
codex_model="$(resolve_model_override "$cli_codex_model" "$env_codex_model" "$file_codex_model")"

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync is required but not installed." >&2
  exit 1
fi

if [[ ${#selected_platforms[@]} -eq 0 ]]; then
  selected_platforms=(claude opencode codex)
fi

if [[ "$interactive_mode" == true ]]; then
  prompt_interactive_scope
fi

run_rsync() {
  local source_dir="$1"
  local target_dir="$2"

  mkdir -p "$target_dir"

  local args=(-a "$source_dir/" "$target_dir/")
  if [[ "$delete_extra" == true ]]; then
    args=(--delete "${args[@]}")
  fi
  if [[ "$dry_run" == true ]]; then
    args=(--dry-run -av "${args[@]}")
  fi

  rsync "${args[@]}"
}

sync_platform() {
  local platform="$1"
  local source_base=""
  local target_base=""
  local model_override=""
  local agent_selection='*'
  local skill_selection='*'
  local selection_joined=""
  local selected_entries=()
  local entry=""

  case "$platform" in
    claude)
      source_base="$repo_root/.claude"
      target_base="$HOME/.claude"
      model_override="$claude_model"
      ;;
    opencode)
      source_base="$repo_root/.config/opencode"
      target_base="$HOME/.config/opencode"
      model_override="$opencode_model"
      ;;
    codex)
      source_base="$repo_root/.codex"
      target_base="$HOME/.codex"
      model_override="$codex_model"
      ;;
    *)
      echo "Unsupported platform: $platform" >&2
      exit 1
      ;;
  esac

  if [[ ! -d "$source_base/agents" && ! -d "$source_base/skills" ]]; then
    echo "Skipping $platform: no agents or skills found in $source_base" >&2
    return
  fi

  echo "Syncing $platform"

  if [[ "$sync_agents" == true && -d "$source_base/agents" ]]; then
    if [[ "$interactive_mode" == true ]]; then
      collect_selected_entries "$source_base/agents" "agents" "$platform" agent_selection
    fi

    if [[ "$agent_selection" == "*" ]]; then
      run_rsync "$source_base/agents" "$target_base/agents"
      if [[ "$dry_run" == true ]]; then
        preview_model_override "$source_base/agents" "$model_override"
      else
        apply_model_override "$target_base/agents" "$model_override"
      fi
    elif [[ -n "$agent_selection" ]]; then
      expand_selection "$source_base/agents" "$agent_selection" selection_joined
      IFS='|' read -r -a selected_entries <<< "$selection_joined"
      for entry in "${selected_entries[@]}"; do
        run_rsync_entry "$source_base/agents/$entry" "$target_base/agents/$entry"
      done

      if [[ "$dry_run" == true ]]; then
        preview_model_override_for_entries "$source_base/agents" "$agent_selection" "$model_override"
      else
        apply_model_override_for_entries "$source_base/agents" "$target_base/agents" "$agent_selection" "$model_override"
      fi
    fi
  fi

  if [[ "$sync_skills" == true && -d "$source_base/skills" ]]; then
    if [[ "$interactive_mode" == true ]]; then
      collect_selected_entries "$source_base/skills" "skills" "$platform" skill_selection
    fi

    if [[ "$skill_selection" == "*" ]]; then
      run_rsync "$source_base/skills" "$target_base/skills"
    elif [[ -n "$skill_selection" ]]; then
      expand_selection "$source_base/skills" "$skill_selection" selection_joined
      IFS='|' read -r -a selected_entries <<< "$selection_joined"
      for entry in "${selected_entries[@]}"; do
        run_rsync_entry "$source_base/skills/$entry" "$target_base/skills/$entry"
      done
    fi
  fi
}

for platform in "${selected_platforms[@]}"; do
  sync_platform "$platform"
done
