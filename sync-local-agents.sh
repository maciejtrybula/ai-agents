#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$script_dir"
dry_run=false
delete_extra=false
selected_platforms=()
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

  [[ -n "$model_value" ]] || return
  [[ -d "$target_dir" ]] || return

  while IFS= read -r file; do
    MODEL_OVERRIDE="$model_value" perl -0pi -e 's/^model:\h*.*/model: $ENV{MODEL_OVERRIDE}/m' "$file"
  done < <(find "$target_dir" -type f -name '*.md' | sort)
}

preview_model_override() {
  local source_dir="$1"
  local model_value="$2"
  local file=""

  [[ -n "$model_value" ]] || return
  [[ -d "$source_dir" ]] || return

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
	       [--claude-model MODEL]
	       [--opencode-model MODEL]
	       [--codex-model MODEL]

Copies agents and skills from this repository into the matching local config
directories in your home folder.

Options:
  --dry-run   Preview changes without writing files
  --delete    Remove local files that no longer exist in this repo
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
  ./sync-local-agents.sh --platform claude --claude-model sonnet
  ./sync-local-agents.sh --platform opencode
  ./sync-local-agents.sh --opencode-model openai/gpt-5.4
  ./sync-local-agents.sh --platform codex --codex-model openai/gpt-5.4
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      dry_run=true
      ;;
    --delete)
      delete_extra=true
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

  if [[ -d "$source_base/agents" ]]; then
    run_rsync "$source_base/agents" "$target_base/agents"

    if [[ "$dry_run" == true ]]; then
      preview_model_override "$source_base/agents" "$model_override"
    else
      apply_model_override "$target_base/agents" "$model_override"
    fi
  fi

  if [[ -d "$source_base/skills" ]]; then
    run_rsync "$source_base/skills" "$target_base/skills"
  fi
}

for platform in "${selected_platforms[@]}"; do
  sync_platform "$platform"
done
