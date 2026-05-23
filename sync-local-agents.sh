#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$script_dir"
dry_run=false
delete_extra=false
interactive_mode=false
configure_api_keys=false
selected_platforms=()
sync_agents=true
sync_skills=true
sync_configs=false
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
[--sync both|agents|skills|config|all] [--interactive]
[--configure-api-keys]
[--claude-model MODEL]
[--opencode-model MODEL]
[--codex-model MODEL]

Copies agents and skills from this repository into the matching local config
directories in your home folder.

Options:
--dry-run Preview changes without writing files
--delete Remove local files that no longer exist in this repo
When syncing selected entries, deletion is scoped to those
selected directories only
--sync Non-interactive scope: both (default), agents, skills,
config, or all
--interactive
Prompt for sync scope, optional per-platform selection
of individual agents/skills, and config sync mode
(requires TTY)
--configure-api-keys
Prompt to configure API keys for opencode.json during sync.
Replaces ${NVIDIA_NIM_API_KEY}, ${STITCH_API_KEY}, and
${CONTEXT7_API_KEY} placeholders with actual values.
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
./sync-local-agents.sh --sync config --platform claude
./sync-local-agents.sh --sync skills --platform claude
./sync-local-agents.sh --sync all --platform opencode
./sync-local-agents.sh --interactive
./sync-local-agents.sh --interactive --configure-api-keys
./sync-local-agents.sh --platform claude --claude-model sonnet
./sync-local-agents.sh --platform opencode --configure-api-keys
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
      sync_configs=false
      sync_scope="both"
      ;;
    agents)
      sync_agents=true
      sync_skills=false
      sync_configs=false
      sync_scope="agents"
      ;;
    skills)
      sync_agents=false
      sync_skills=true
      sync_configs=false
      sync_scope="skills"
      ;;
    config)
      sync_agents=false
      sync_skills=false
      sync_configs=true
      sync_scope="config"
      ;;
    all)
      sync_agents=true
      sync_skills=true
      sync_configs=true
      sync_scope="all"
      ;;
    *)
      echo "Unsupported value for --sync: $value (expected: both|agents|skills|config|all)" >&2
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

# Function to prompt for API key securely
prompt_for_api_key() {
  local var_name="$1"
  local description="$2"
  local hint="$3"
  local value=""

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "API Key: $description"
  echo "Variable: $var_name"
  if [[ -n "$hint" ]]; then
    echo "Expected format: $hint"
  fi
  echo ""

  # Check if already set in environment
  if [[ -n "${!var_name:-}" ]]; then
    echo "Found $var_name in environment (${#var_name} chars)"
    read -rp "Use existing value? [Y/n]: " use_existing
    if [[ ! "$use_existing" =~ ^[Nn]$ ]]; then
      echo "${!var_name}"
      return
    fi
  fi

	# Prompt for value
	while true; do
		read -rsp "Enter $description (input hidden): " value
		echo ""

		# Strip CR/LF that read -rsp may leave on some terminals (macOS)
		value="${value//$'\r'/}"
		value="${value//$'\n'/}"

		if [[ -z "$value" ]]; then
			echo "Error: Value cannot be empty." >&2
			continue
		fi

		# Confirm the value
		read -rsp "Confirm $description (type again): " confirm_value
		echo ""

		confirm_value="${confirm_value//$'\r'/}"
		confirm_value="${confirm_value//$'\n'/}"

		if [[ "$value" != "$confirm_value" ]]; then
			echo "Error: Values do not match." >&2
			continue
		fi

		break
	done

	printf '%s' "$value"
}

# Function to substitute API keys in opencode.json
substitute_api_keys() {
  local input_file="$1"
  local output_file="$2"
  local nvim_key=""
  local stitch_key=""
  local context7_key=""

  echo ""
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║         OpenCode API Key Configuration                      ║"
  echo "║     Securely configure API keys during sync                ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
  echo "This will prompt you for API keys to embed in opencode.json"
  echo "Your keys will NOT be stored in the git repository."
  echo ""

  # Prompt for NVIDIA NIM API Key
  nvim_key=$(prompt_for_api_key "NVIDIA_NIM_API_KEY" \
    "NVIDIA NIM API Key" \
    "nvapi-... (get from https://build.nvidia.com/)" \
    || true)

  # Prompt for Stitch API Key
  stitch_key=$(prompt_for_api_key "STITCH_API_KEY" \
    "Stitch MCP API Key" \
    "AQ.xxx... (get from Google AI Studio)" \
    || true)

  # Prompt for Context7 API Key
  context7_key=$(prompt_for_api_key "CONTEXT7_API_KEY" \
    "Context7 MCP API Key" \
    "ctx7sk-... (get from https://context7.com)" \
    || true)

	# Copy and substitute values
	if [[ -n "$nvim_key" || -n "$stitch_key" || -n "$context7_key" ]]; then
		echo ""
		echo "Applying API key substitutions..."

		# Copy source to output first, then apply substitutions in-place
		cp "$input_file" "$output_file"

		# Use perl for reliable ${...} placeholder replacement (macOS sed
		# struggles with literal dollar-brace patterns in double quotes)
		if [[ -n "$nvim_key" ]]; then
			NVIDIA_NIM_API_KEY="$nvim_key" perl -pi -e 's/\$\{NVIDIA_NIM_API_KEY\}/$ENV{NVIDIA_NIM_API_KEY}/g' "$output_file"
		fi
		if [[ -n "$stitch_key" ]]; then
			STITCH_API_KEY="$stitch_key" perl -pi -e 's/\$\{STITCH_API_KEY\}/$ENV{STITCH_API_KEY}/g' "$output_file"
		fi
		if [[ -n "$context7_key" ]]; then
			CONTEXT7_API_KEY="$context7_key" perl -pi -e 's/\$\{CONTEXT7_API_KEY\}/$ENV{CONTEXT7_API_KEY}/g' "$output_file"
		fi

		echo "✓ API keys substituted successfully"
	else
		# No keys provided, just copy the file
		cp "$input_file" "$output_file"
	fi
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

require_node() {
  if ! command -v node >/dev/null 2>&1; then
    echo "node is required for MCP-only config sync but is not installed." >&2
    exit 1
  fi
}

list_json_object_keys() {
  local json_file="$1"
  local root_key="$2"

  [[ -f "$json_file" ]] || return 0

  require_node

  node - "$json_file" "$root_key" <<'NODE'
const fs = require("fs")

const [jsonFile, rootKey] = process.argv.slice(2)
const data = JSON.parse(fs.readFileSync(jsonFile, "utf8"))
const value = data?.[rootKey]

if (!value || typeof value !== "object" || Array.isArray(value)) {
  process.exit(0)
}

for (const key of Object.keys(value).sort()) {
  process.stdout.write(`${key}\n`)
}
NODE
}

collect_selected_json_keys() {
  local json_file="$1"
  local root_key="$2"
  local label="$3"
  local platform="$4"
  local __result_var="$5"
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
  done < <(list_json_object_keys "$json_file" "$root_key")

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

selected_json_object_contains_placeholders() {
  local json_file="$1"
  local root_key="$2"
  local selection="$3"

  require_node

  node - "$json_file" "$root_key" "$selection" <<'NODE'
const fs = require("fs")

const [jsonFile, rootKey, selection] = process.argv.slice(2)
const data = JSON.parse(fs.readFileSync(jsonFile, "utf8"))
const sourceRoot = data?.[rootKey] ?? {}
const selectedKeys = selection === "*" ? Object.keys(sourceRoot) : selection.split("|").filter(Boolean)
const placeholderPattern = /^\$\{[A-Z0-9_]+\}$/

function hasPlaceholder(value) {
  if (typeof value === "string") {
    return placeholderPattern.test(value)
  }
  if (Array.isArray(value)) {
    return value.some(hasPlaceholder)
  }
  if (value && typeof value === "object") {
    return Object.values(value).some(hasPlaceholder)
  }
  return false
}

for (const key of selectedKeys) {
  if (hasPlaceholder(sourceRoot[key])) {
    process.exit(0)
  }
}

process.exit(1)
NODE
}

merge_selected_json_object_keys() {
  local source_json="$1"
  local target_json="$2"
  local root_key="$3"
  local selection="$4"

  require_node

  mkdir -p "$(dirname "$target_json")"

  node - "$source_json" "$target_json" "$root_key" "$selection" <<'NODE'
const fs = require("fs")
const vm = require("vm")

const [sourceJson, targetJson, rootKey, selection] = process.argv.slice(2)

function parseConfigFile(filePath) {
  const text = fs.readFileSync(filePath, "utf8")

  try {
    return JSON.parse(text)
  } catch (_error) {
    return vm.runInNewContext(`(${text})`, {})
  }
}

const source = parseConfigFile(sourceJson)
const target = fs.existsSync(targetJson)
  ? parseConfigFile(targetJson)
  : {}
const sourceRoot = source?.[rootKey] ?? {}
const selectedKeys = selection === "*" ? Object.keys(sourceRoot) : selection.split("|").filter(Boolean)
const placeholderPattern = /^\$\{[A-Z0-9_]+\}$/

function preservePlaceholderValues(sourceValue, targetValue) {
  if (typeof sourceValue === "string") {
    if (placeholderPattern.test(sourceValue) && typeof targetValue === "string" && targetValue.length > 0) {
      return targetValue
    }
    return sourceValue
  }

  if (Array.isArray(sourceValue)) {
    const targetArray = Array.isArray(targetValue) ? targetValue : []
    return sourceValue.map((entry, index) => preservePlaceholderValues(entry, targetArray[index]))
  }

  if (sourceValue && typeof sourceValue === "object") {
    const targetObject = targetValue && typeof targetValue === "object" && !Array.isArray(targetValue)
      ? targetValue
      : {}
    const result = {}
    for (const [key, value] of Object.entries(sourceValue)) {
      result[key] = preservePlaceholderValues(value, targetObject[key])
    }
    return result
  }

  return sourceValue
}

if (!target[rootKey] || typeof target[rootKey] !== "object" || Array.isArray(target[rootKey])) {
  target[rootKey] = {}
}

if (source.$schema && !target.$schema) {
  target.$schema = source.$schema
}

for (const key of selectedKeys) {
  if (!(key in sourceRoot)) {
    continue
  }
  target[rootKey][key] = preservePlaceholderValues(sourceRoot[key], target[rootKey][key])
}

fs.writeFileSync(targetJson, `${JSON.stringify(target, null, 2)}\n`)
NODE
}

preview_selected_json_keys_sync() {
  local platform="$1"
  local target_json="$2"
  local label="$3"
  local selection="$4"
  local selected=()

  if [[ "$selection" == "*" ]]; then
    printf 'Would sync all %s for %s into %s\n' "$label" "$platform" "$target_json"
    return 0
  fi

  IFS='|' read -r -a selected <<< "$selection"
  printf 'Would sync %s for %s into %s:\n' "$label" "$platform" "$target_json"
  for entry in "${selected[@]}"; do
    printf '  - %s\n' "$entry"
  done
}

prompt_config_sync_mode() {
  local platform="$1"
  local config_name="$2"
  local __result_var="$3"
  local answer=""

  read -r -p "How do you want to sync $platform $config_name? [full/mcp/skip] (default: full): " answer
  answer="$(trim "$answer")"
  answer="$(to_lower "$answer")"

  case "$answer" in
    ""|full)
      printf -v "$__result_var" '%s' "full"
      ;;
    mcp)
      printf -v "$__result_var" '%s' "mcp"
      ;;
    skip)
      printf -v "$__result_var" '%s' "skip"
      ;;
    *)
      echo "Unsupported config sync mode: $answer (expected: full|mcp|skip)" >&2
      exit 1
      ;;
  esac
}

prompt_interactive_scope() {
  local answer=""

  if [[ ! -t 0 || ! -t 1 ]]; then
    echo "--interactive requires an interactive terminal (TTY stdin/stdout)." >&2
    exit 1
  fi

  read -r -p "What do you want to sync? [both/agents/skills/config/all] (default: $sync_scope): " answer
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
    --configure-api-keys)
      configure_api_keys=true
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
  local config_source=""
  local config_target=""
  local mcp_root_key=""
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
      config_source="$source_base/settings.json"
      config_target="$target_base/settings.json"
      mcp_root_key="mcpServers"
      ;;
    opencode)
      source_base="$repo_root/.config/opencode"
      target_base="$HOME/.config/opencode"
      model_override="$opencode_model"
      config_source="$source_base/opencode.json"
      config_target="$target_base/opencode.json"
      mcp_root_key="mcp"
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

  if [[ "$sync_configs" == true ]]; then
    sync_platform_config "$platform" "$config_source" "$config_target" "$mcp_root_key"
  fi
}

# Special handling for opencode.json - prompt for API keys
sync_opencode_json() {
  local source_base="$1"
  local target_base="$2"
  local json_source="$source_base/opencode.json"
  local json_target="$target_base/opencode.json"
  local configure_keys=""

  if [[ ! -f "$json_source" ]]; then
    return 0
  fi

  if [[ "$dry_run" == true ]]; then
    echo "Would sync $json_source to $json_target with API key substitution"
    return 0
  fi

  # Check if opencode.json contains placeholders that need substitution
  if grep -q '\${NVIDIA_NIM_API_KEY}\|\${STITCH_API_KEY}\|\${CONTEXT7_API_KEY}' "$json_source" 2>/dev/null; then
    echo ""
    echo "opencode.json contains API key placeholders."

    # If --configure-api-keys flag is set, automatically configure
    if [[ "$configure_api_keys" == true ]]; then
      substitute_api_keys "$json_source" "$json_target"
      return 0
    fi

    # Otherwise, prompt interactively
    read -rp "Configure API keys now? [Y/n]: " configure_keys
    if [[ ! "$configure_keys" =~ ^[Nn]$ ]]; then
      substitute_api_keys "$json_source" "$json_target"
    else
      merge_selected_json_object_keys "$json_source" "$json_target" "provider" "*"
      merge_selected_json_object_keys "$json_source" "$json_target" "mcp" "*"
      echo "Synced opencode.json while preserving any existing local API keys in $json_target"
    fi
  else
    # No placeholders, just copy
    mkdir -p "$(dirname "$json_target")"
    cp "$json_source" "$json_target"
    echo "Copied opencode.json"
  fi
}

sync_selected_mcp_servers() {
  local platform="$1"
  local source_json="$2"
  local target_json="$3"
  local root_key="$4"
  local selection="$5"
  local prepared_source="$source_json"
  local temp_source=""
  local configure_keys=""

  if [[ "$platform" == "opencode" ]] && selected_json_object_contains_placeholders "$source_json" "$root_key" "$selection"; then
    echo ""
    echo "Selected OpenCode MCP servers contain API key placeholders."

    if [[ "$configure_api_keys" == true ]]; then
      temp_source="$(mktemp)"
      substitute_api_keys "$source_json" "$temp_source"
      prepared_source="$temp_source"
    elif [[ "$interactive_mode" == true ]]; then
      read -rp "Configure API keys now? [Y/n]: " configure_keys
      if [[ ! "$configure_keys" =~ ^[Nn]$ ]]; then
        temp_source="$(mktemp)"
        substitute_api_keys "$source_json" "$temp_source"
        prepared_source="$temp_source"
      else
        echo "Keeping any existing API keys already present in $target_json"
      fi
    fi
  fi

  if [[ "$dry_run" == true ]]; then
    preview_selected_json_keys_sync "$platform" "$target_json" "MCP servers" "$selection"
  else
    merge_selected_json_object_keys "$prepared_source" "$target_json" "$root_key" "$selection"
    echo "Synced selected MCP servers for $platform"
  fi

  if [[ -n "$temp_source" && -f "$temp_source" ]]; then
    rm -f "$temp_source"
  fi
}

sync_platform_config() {
  local platform="$1"
  local config_source="$2"
  local config_target="$3"
  local mcp_root_key="$4"
  local config_mode="full"
  local mcp_selection="*"

  if [[ -z "$config_source" || ! -f "$config_source" ]]; then
    echo "Skipping $platform config: no repo-managed config file found in this repository" >&2
    return 0
  fi

  if [[ "$interactive_mode" == true ]]; then
    prompt_config_sync_mode "$platform" "$(basename "$config_source")" config_mode
  fi

  case "$config_mode" in
    skip)
      return 0
      ;;
    full)
      if [[ "$platform" == "opencode" ]]; then
        sync_opencode_json "$(dirname "$config_source")" "$(dirname "$config_target")"
      else
        run_rsync_entry "$config_source" "$config_target"
      fi
      ;;
    mcp)
      collect_selected_json_keys "$config_source" "$mcp_root_key" "MCP servers" "$platform" mcp_selection

      if [[ -z "$mcp_selection" ]]; then
        echo "Skipping MCP sync for $platform"
        return 0
      fi

      sync_selected_mcp_servers "$platform" "$config_source" "$config_target" "$mcp_root_key" "$mcp_selection"
      ;;
  esac
}

for platform in "${selected_platforms[@]}"; do
  sync_platform "$platform"
done
