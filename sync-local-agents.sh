#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$script_dir"
model_catalog_file="$repo_root/.config/model-catalog.json"

# Script map:
# 1. Shared state and terminal formatting
# 2. Small string and env parsing helpers
# 3. Model catalog lookup and validation helpers
# 4. Model override resolution and application helpers
# 5. Interactive entry and model picker helpers
# 6. Config sync and JSON merge helpers
# 7. Argument parsing and main sync flow

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
cli_agent_model_overrides=""
generated_agent_model_overrides=""
file_agent_model_overrides=""
env_agent_model_overrides=""
interactive_agent_model_overrides=""
interactive_claude_model=""
interactive_opencode_model=""
interactive_codex_model=""
use_recommended_models=false
use_recommended_fallback_models=false
cli_recommended_provider=""
supports_color=false
color_reset=""
color_bold=""
color_dim=""
color_red=""
color_green=""
color_yellow=""
color_blue=""
color_magenta=""
color_cyan=""

if [[ -t 1 && "${TERM:-}" != "dumb" ]]; then
  supports_color=true
  color_reset=$'\033[0m'
  color_bold=$'\033[1m'
  color_dim=$'\033[2m'
  color_red=$'\033[31m'
  color_green=$'\033[32m'
  color_yellow=$'\033[33m'
  color_blue=$'\033[34m'
  color_magenta=$'\033[35m'
  color_cyan=$'\033[36m'
fi

print_heading() {
  printf '%s%s%s\n' "$color_bold$color_cyan" "$1" "$color_reset"
}

print_success() {
  printf '%s%s%s\n' "$color_green" "$1" "$color_reset"
}

print_warning() {
  printf '%s%s%s\n' "$color_yellow" "$1" "$color_reset"
}

print_error() {
  printf '%s%s%s\n' "$color_red" "$1" "$color_reset" >&2
}

print_note() {
  printf '%s%s%s\n' "$color_dim" "$1" "$color_reset"
}

print_divider() {
  printf '%s────────────────────────────────────────────────────────────%s\n' "$color_dim" "$color_reset"
}

# -----------------------------------------------------------------------------
# Small string and env parsing helpers
# -----------------------------------------------------------------------------

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

normalize_agent_env_suffix() {
  local value="$1"

  value="$(to_lower "$value")"
  printf '%s' "${value//_/-}"
}

normalize_model_catalog_value() {
  local value="$1"

  value="$(trim "$value")"
  value="$(strip_wrapping_quotes "$value")"
  printf '%s' "$value"
}

env_claude_model="$(normalize_model_catalog_value "$env_claude_model")"
env_opencode_model="$(normalize_model_catalog_value "$env_opencode_model")"
env_codex_model="$(normalize_model_catalog_value "$env_codex_model")"

append_override_record() {
  local current_value="$1"
  local record="$2"

  if [[ -z "$current_value" ]]; then
    printf '%s' "$record"
  else
    printf '%s\n%s' "$current_value" "$record"
  fi
}

require_node() {
  if ! command -v node >/dev/null 2>&1; then
    print_error "node is required for model catalog validation and MCP-only config sync but is not installed."
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# Model catalog lookup and validation helpers
# -----------------------------------------------------------------------------

parse_model_catalog_entry() {
  local platform="$1"
  local requested_value="$2"

  require_node

  node - "$model_catalog_file" "$platform" "$requested_value" <<'NODE'
const fs = require("fs")

const [catalogFile, platform, requestedValue] = process.argv.slice(2)
const catalog = JSON.parse(fs.readFileSync(catalogFile, "utf8"))
const platformConfig = catalog?.platforms?.[platform]

if (!platformConfig) {
  console.error(`Unsupported platform in model catalog: ${platform}`)
  process.exit(1)
}

const models = []

for (const [provider, providerConfig] of Object.entries(platformConfig.providers ?? {})) {
  for (const model of providerConfig.models ?? []) {
    models.push({
      provider,
      id: model.id,
      target: model.target,
      description: model.description ?? "",
    })
  }
}

const normalizedRequestedValue = requestedValue.trim()
const match = models.find((model) => model.id === normalizedRequestedValue || model.target === normalizedRequestedValue)

if (!match) {
  console.error(`Unsupported model override for ${platform}: ${requestedValue}`)
  console.error("Allowed values:")
  for (const model of models) {
    const suffix = model.id === model.target ? "" : ` -> ${model.target}`
    console.error(`  - ${model.id}${suffix}`)
  }
  process.exit(1)
}

process.stdout.write(`${match.provider}\t${match.id}\t${match.target}\t${match.description}\n`)
NODE
}

list_model_catalog_entries() {
  local platform="$1"
  local provider_filter="${2:-}"

  require_node

  node - "$model_catalog_file" "$platform" "$provider_filter" <<'NODE'
const fs = require("fs")

const [catalogFile, platform, providerFilter] = process.argv.slice(2)
const catalog = JSON.parse(fs.readFileSync(catalogFile, "utf8"))
const platformConfig = catalog?.platforms?.[platform]

if (!platformConfig) {
  process.exit(0)
}

for (const [provider, providerConfig] of Object.entries(platformConfig.providers ?? {})) {
  if (providerFilter && provider !== providerFilter) {
    continue
  }
  for (const model of providerConfig.models ?? []) {
    const description = model.description ?? ""
    process.stdout.write(`${provider}\t${model.id}\t${model.target}\t${description}\n`)
  }
}
NODE
}

list_model_catalog_providers() {
  local platform="$1"

  require_node

  node - "$model_catalog_file" "$platform" <<'NODE'
const fs = require("fs")

const [catalogFile, platform] = process.argv.slice(2)
const catalog = JSON.parse(fs.readFileSync(catalogFile, "utf8"))
const platformConfig = catalog?.platforms?.[platform]

if (!platformConfig) {
  process.exit(0)
}

const providers = platformConfig.providers ?? {}
const providerOrder = Array.isArray(platformConfig.providerOrder) ? platformConfig.providerOrder : []
const favoriteProviders = new Set(Array.isArray(platformConfig.favoriteProviders) ? platformConfig.favoriteProviders : [])
const orderedProviders = []
const seenProviders = new Set()

for (const provider of providerOrder) {
  if (provider in providers && !seenProviders.has(provider)) {
    orderedProviders.push(provider)
    seenProviders.add(provider)
  }
}

for (const provider of Object.keys(providers)) {
  if (!seenProviders.has(provider)) {
    orderedProviders.push(provider)
    seenProviders.add(provider)
  }
}

for (const provider of orderedProviders) {
  process.stdout.write(`${provider}\t${favoriteProviders.has(provider) ? "favorite" : ""}\n`)
}
NODE
}

list_recommended_model_ids_for_agent() {
  local platform="$1"
  local agent_slug="$2"
  local provider="$3"

  require_node

  node - "$model_catalog_file" "$platform" "$agent_slug" "$provider" <<'NODE'
const fs = require("fs")

const [catalogFile, platform, agentSlug, provider] = process.argv.slice(2)
const catalog = JSON.parse(fs.readFileSync(catalogFile, "utf8"))
const recommendedModels = catalog?.platforms?.[platform]?.recommendedAgents?.[provider]?.[agentSlug]

if (!Array.isArray(recommendedModels)) {
  process.exit(0)
}

for (const modelId of recommendedModels) {
  process.stdout.write(`${modelId}\n`)
}
NODE
}

resolve_recommended_model_id_for_agent() {
  local platform="$1"
  local agent_slug="$2"
  local recommendation_index="$3"
  local provider="$4"

  require_node

  node - "$model_catalog_file" "$platform" "$agent_slug" "$recommendation_index" "$provider" <<'NODE'
const fs = require("fs")

const [catalogFile, platform, agentSlug, recommendationIndex, provider] = process.argv.slice(2)
const catalog = JSON.parse(fs.readFileSync(catalogFile, "utf8"))
const recommendedModels = catalog?.platforms?.[platform]?.recommendedAgents?.[provider]?.[agentSlug]
const index = Number.parseInt(recommendationIndex, 10)

if (!Array.isArray(recommendedModels) || Number.isNaN(index) || index < 0 || index >= recommendedModels.length) {
  process.exit(0)
}

process.stdout.write(`${recommendedModels[index]}\n`)
NODE
}

build_recommended_agent_model_overrides() {
  local platform="$1"
  local source_agents_dir="$2"
  local selection="$3"
  local recommendation_index="$4"
  local missing_label="$5"
  local provider="$6"
  local __result_var="$7"
  local current_overrides=""
  local file=""
  local agent_slug=""
  local recommended_model_id=""

  while IFS= read -r file; do
    [[ -n "$file" ]] || continue

    agent_slug="$(basename "$file" .md)"
    recommended_model_id="$(resolve_recommended_model_id_for_agent "$platform" "$agent_slug" "$recommendation_index" "$provider")"

    if [[ -z "$recommended_model_id" ]]; then
      print_error "Missing $missing_label for $platform agent: $agent_slug"
      print_note "Expected platforms.$platform.recommendedAgents.$provider.$agent_slug[$((recommendation_index + 1))] in ./.config/model-catalog.json"
      exit 1
    fi

    current_overrides="$(append_agent_model_override "$current_overrides" "$platform" "$agent_slug" "$recommended_model_id")"
  done < <(iterate_agent_markdown_files "$source_agents_dir" "$selection")

  printf -v "$__result_var" '%s' "$current_overrides"
}

resolve_default_recommended_provider() {
  local platform="$1"

  require_node

  node - "$model_catalog_file" "$platform" <<'NODE'
const fs = require("fs")

const [catalogFile, platform] = process.argv.slice(2)
const catalog = JSON.parse(fs.readFileSync(catalogFile, "utf8"))
const provider = catalog?.platforms?.[platform]?.defaultRecommendedProvider

if (typeof provider === "string" && provider.length > 0) {
  process.stdout.write(`${provider}\n`)
}
NODE
}

list_recommended_providers() {
  local platform="$1"

  require_node

  node - "$model_catalog_file" "$platform" <<'NODE'
const fs = require("fs")

const [catalogFile, platform] = process.argv.slice(2)
const catalog = JSON.parse(fs.readFileSync(catalogFile, "utf8"))
const platformConfig = catalog?.platforms?.[platform]

if (!platformConfig) {
  process.exit(0)
}

const recommendedAgents = platformConfig.recommendedAgents ?? {}
const providerOrder = Array.isArray(platformConfig.providerOrder) ? platformConfig.providerOrder : []
const defaultProvider = platformConfig.defaultRecommendedProvider ?? ""
const providers = []
const seenProviders = new Set()

for (const provider of providerOrder) {
  if (provider in recommendedAgents && !seenProviders.has(provider)) {
    providers.push(provider)
    seenProviders.add(provider)
  }
}

for (const provider of Object.keys(recommendedAgents)) {
  if (!seenProviders.has(provider)) {
    providers.push(provider)
    seenProviders.add(provider)
  }
}

for (const provider of providers) {
  process.stdout.write(`${provider}\t${provider === defaultProvider ? "default" : ""}\n`)
}
NODE
}

resolve_effective_recommended_provider() {
  local platform="$1"
  local requested_provider="$2"
  local resolved_provider=""
  local listed_entry=""
  local matched_provider=false

  if [[ -n "$requested_provider" ]]; then
    while IFS= read -r listed_entry; do
      [[ -n "$listed_entry" ]] || continue
      if [[ "${listed_entry%%$'\t'*}" == "$requested_provider" ]]; then
        printf '%s' "$requested_provider"
        return 0
      fi
    done < <(list_recommended_providers "$platform")

    print_error "Unsupported recommended provider for $platform: $requested_provider"
    print_note "Expected a provider from platforms.$platform.recommendedAgents in ./.config/model-catalog.json"
    exit 1
  fi

  resolved_provider="$(resolve_default_recommended_provider "$platform")"
  if [[ -n "$resolved_provider" ]]; then
    while IFS= read -r listed_entry; do
      [[ -n "$listed_entry" ]] || continue
      if [[ "${listed_entry%%$'\t'*}" == "$resolved_provider" ]]; then
        matched_provider=true
        break
      fi
    done < <(list_recommended_providers "$platform")

    if [[ "$matched_provider" == true ]]; then
      printf '%s' "$resolved_provider"
      return 0
    fi

    print_error "Missing recommended provider mapping for $platform: $resolved_provider"
    print_note "Expected platforms.$platform.recommendedAgents.$resolved_provider in ./.config/model-catalog.json"
    exit 1
  fi

  print_error "Missing default recommended provider for $platform"
  print_note "Expected platforms.$platform.defaultRecommendedProvider in ./.config/model-catalog.json"
  exit 1
}

validate_recommended_provider_selection() {
  local requested_provider="$1"
  local platform=""

  for platform in "${selected_platforms[@]}"; do
    resolve_effective_recommended_provider "$platform" "$requested_provider" >/dev/null
  done
}

resolve_catalog_model_target() {
  local platform="$1"
  local requested_value="$2"
  local parsed_entry=""
  local remaining=""

  [[ -n "$requested_value" ]] || return 0

  parsed_entry="$(parse_model_catalog_entry "$platform" "$requested_value")" || exit 1
  remaining="${parsed_entry#*$'\t'}"
  remaining="${remaining#*$'\t'}"
  printf '%s' "${remaining%%$'\t'*}"
}

append_agent_model_override() {
  local current_value="$1"
  local platform="$2"
  local agent_slug="$3"
  local requested_value="$4"
  local parsed_entry=""
  local provider=""
  local model_id=""
  local target_value=""

  parsed_entry="$(parse_model_catalog_entry "$platform" "$requested_value")" || exit 1
  provider="${parsed_entry%%$'\t'*}"
  parsed_entry="${parsed_entry#*$'\t'}"
  model_id="${parsed_entry%%$'\t'*}"
  parsed_entry="${parsed_entry#*$'\t'}"
  target_value="${parsed_entry%%$'\t'*}"

  append_override_record "$current_value" "$platform:$agent_slug:$model_id:$target_value:$provider"
}

find_agent_model_override_target() {
  local overrides="$1"
  local platform="$2"
  local agent_slug="$3"
  local record=""
  local record_platform=""
  local record_agent=""
  local remaining=""
  local target_value=""
  local matched_value=""

  [[ -n "$overrides" ]] || return 1

  while IFS= read -r record || [[ -n "$record" ]]; do
    [[ -n "$record" ]] || continue
    record_platform="${record%%:*}"
    remaining="${record#*:}"
    record_agent="${remaining%%:*}"
    remaining="${remaining#*:}"
    remaining="${remaining#*:}"
    target_value="${remaining%%:*}"

    if [[ "$record_platform" == "$platform" && "$record_agent" == "$agent_slug" ]]; then
      matched_value="$target_value"
    fi
  done <<< "$overrides"

  if [[ -n "$matched_value" ]]; then
    printf '%s' "$matched_value"
    return 0
  fi

  return 1
}

overrides_include_platform() {
  local overrides="$1"
  local platform="$2"
  local record=""

  [[ -n "$overrides" ]] || return 1

  while IFS= read -r record || [[ -n "$record" ]]; do
    [[ -n "$record" ]] || continue
    if [[ "${record%%:*}" == "$platform" ]]; then
      return 0
    fi
  done <<< "$overrides"

  return 1
}

resolve_agent_model_override() {
  local platform="$1"
  local agent_slug="$2"
  local resolved_value=""

  resolved_value="$(find_agent_model_override_target "$interactive_agent_model_overrides" "$platform" "$agent_slug" || true)"
  if [[ -n "$resolved_value" ]]; then
    printf '%s' "$resolved_value"
    return 0
  fi

  resolved_value="$(find_agent_model_override_target "$cli_agent_model_overrides" "$platform" "$agent_slug" || true)"
  if [[ -n "$resolved_value" ]]; then
    printf '%s' "$resolved_value"
    return 0
  fi

  resolved_value="$(find_agent_model_override_target "$generated_agent_model_overrides" "$platform" "$agent_slug" || true)"
  if [[ -n "$resolved_value" ]]; then
    printf '%s' "$resolved_value"
    return 0
  fi

  resolved_value="$(find_agent_model_override_target "$env_agent_model_overrides" "$platform" "$agent_slug" || true)"
  if [[ -n "$resolved_value" ]]; then
    printf '%s' "$resolved_value"
    return 0
  fi

  find_agent_model_override_target "$file_agent_model_overrides" "$platform" "$agent_slug" || true
}

load_model_settings_from_file() {
  local config_file="$1"
  local platform="$2"
  local expected_key="$3"
  local __model_result_var="$4"
  local __overrides_result_var="$5"
  local agent_prefix="${expected_key%_MODEL}_AGENT_MODEL_"
  local line=""
  local key=""
  local value=""
  local current_model_value="${!__model_result_var:-}"
  local current_overrides_value="${!__overrides_result_var:-}"
  local normalized_agent_slug=""

  [[ -f "$config_file" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(trim "$line")"
    [[ -z "$line" || "$line" == \#* ]] && continue
    [[ "$line" == *=* ]] || continue

    key="${line%%=*}"
    value="${line#*=}"

    key="$(trim "$key")"
    value="$(normalize_model_catalog_value "$value")"

    case "$key" in
      "$expected_key")
        current_model_value="$value"
        ;;
      ${agent_prefix}*)
        [[ -n "$value" ]] || continue
        normalized_agent_slug="$(normalize_agent_env_suffix "${key#${agent_prefix}}")"
        current_overrides_value="$(append_agent_model_override "$current_overrides_value" "$platform" "$normalized_agent_slug" "$value")"
        ;;
      *)
        print_warning "Ignoring unsupported setting in $config_file: $key"
        ;;
    esac
  done < "$config_file"

  printf -v "$__model_result_var" '%s' "$current_model_value"
  printf -v "$__overrides_result_var" '%s' "$current_overrides_value"
}

load_agent_model_overrides_from_environment() {
  local platform="$1"
  local prefix="$2"
  local __result_var="$3"
  local current_overrides_value="${!__result_var:-}"
  local key=""
  local value=""
  local normalized_agent_slug=""

  while IFS='=' read -r key value; do
    case "$key" in
      ${prefix}_AGENT_MODEL_*)
        [[ -n "$value" ]] || continue
        normalized_agent_slug="$(normalize_agent_env_suffix "${key#${prefix}_AGENT_MODEL_}")"
        value="$(normalize_model_catalog_value "$value")"
        current_overrides_value="$(append_agent_model_override "$current_overrides_value" "$platform" "$normalized_agent_slug" "$value")"
        ;;
    esac
  done < <(env)

  printf -v "$__result_var" '%s' "$current_overrides_value"
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

resolve_platform_model_override() {
  local platform="$1"
  local cli_value="$2"
  local env_value="$3"
  local file_value="$4"
  local requested_value=""

  requested_value="$(resolve_model_override "$cli_value" "$env_value" "$file_value")"
  [[ -n "$requested_value" ]] || return 0

  resolve_catalog_model_target "$platform" "$requested_value"
}

parse_cli_agent_model_override() {
  local argument_value="$1"
  local platform=""
  local remaining=""
  local agent_slug=""
  local requested_value=""

  if [[ "$argument_value" != *:*:* ]]; then
    print_error "Invalid --agent-model value: $argument_value"
    print_note "Expected format: platform:agent-slug:provider/model"
    exit 1
  fi

  platform="${argument_value%%:*}"
  remaining="${argument_value#*:}"
  agent_slug="${remaining%%:*}"
  requested_value="${remaining#*:}"

  case "$platform" in
    claude|opencode|codex)
      ;;
    *)
      print_error "Unsupported platform in --agent-model: $platform"
      exit 1
      ;;
  esac

  agent_slug="$(trim "$agent_slug")"
  requested_value="$(normalize_model_catalog_value "$requested_value")"

  if [[ -z "$agent_slug" || -z "$requested_value" ]]; then
    print_error "Invalid --agent-model value: $argument_value"
    print_note "Expected format: platform:agent-slug:provider/model"
    exit 1
  fi

  cli_agent_model_overrides="$(append_agent_model_override "$cli_agent_model_overrides" "$platform" "$agent_slug" "$requested_value")"
}

# -----------------------------------------------------------------------------
# Model override resolution and application helpers
# -----------------------------------------------------------------------------

iterate_agent_markdown_files() {
  local source_agents_dir="$1"
  local selection="$2"
  local entry=""
  local file=""
  local expanded_selection=""
  local selected_entries=()

  if [[ "$selection" == "*" ]]; then
    find "$source_agents_dir" -type f -name '*.md' | sort
    return 0
  fi

  expand_selection "$source_agents_dir" "$selection" expanded_selection
  [[ -n "$expanded_selection" ]] || return 0

  IFS='|' read -r -a selected_entries <<< "$expanded_selection"
  for entry in "${selected_entries[@]}"; do
    if [[ -d "$source_agents_dir/$entry" ]]; then
      while IFS= read -r file; do
        printf '%s\n' "$file"
      done < <(find "$source_agents_dir/$entry" -type f -name '*.md' | sort)
    elif [[ "$entry" == *.md ]]; then
      printf '%s\n' "$source_agents_dir/$entry"
    fi
  done
}

process_model_override_files() {
  local mode="$1"
  local platform="$2"
  local source_agents_dir="$3"
  local target_agents_dir="$4"
  local selection="$5"
  local platform_model_value="$6"
  local file=""
  local relative_path=""
  local target_file=""
  local output_file=""
  local agent_slug=""
  local effective_model_value=""

  [[ "$mode" == "apply" || "$mode" == "preview" ]] || return 1

  while IFS= read -r file; do
    [[ -n "$file" ]] || continue

    agent_slug="$(basename "$file" .md)"
    effective_model_value="$(resolve_effective_model_override "$platform" "$agent_slug" "$platform_model_value")"
    [[ -n "$effective_model_value" ]] || continue

    if [[ "$selection" == "*" ]]; then
      output_file="$file"
    else
      relative_path="${file#"$source_agents_dir/"}"
      output_file="$target_agents_dir/$relative_path"
      [[ "$mode" == "preview" || -f "$output_file" ]] || continue
    fi

    if [[ "$mode" == "preview" ]]; then
      printf 'Would override model in synced copy of %s -> %s\n' "$output_file" "$effective_model_value"
    else
      MODEL_OVERRIDE="$effective_model_value" perl -0pi -e 's/^model:\h*.*/model: $ENV{MODEL_OVERRIDE}/m' "$output_file"
    fi
  done < <(iterate_agent_markdown_files "$source_agents_dir" "$selection")
}

apply_model_override() {
  local platform="$1"
  local target_dir="$2"
  local platform_model_value="$3"

  [[ -d "$target_dir" ]] || return 0

  process_model_override_files "apply" "$platform" "$target_dir" "$target_dir" "*" "$platform_model_value"
}

resolve_effective_model_override() {
  local platform="$1"
  local agent_slug="$2"
  local platform_model_value="$3"
  local agent_model_value=""

  agent_model_value="$(resolve_agent_model_override "$platform" "$agent_slug" || true)"
  if [[ -n "$agent_model_value" ]]; then
    printf '%s' "$agent_model_value"
  else
    printf '%s' "$platform_model_value"
  fi
}

validate_agent_override_targets_exist() {
  local source_agents_dir="$1"
  local platform="$2"
  local overrides="$3"
  local record=""
  local record_platform=""
  local remaining=""
  local record_agent=""

  [[ -n "$overrides" ]] || return 0

  while IFS= read -r record || [[ -n "$record" ]]; do
    [[ -n "$record" ]] || continue
    record_platform="${record%%:*}"
    remaining="${record#*:}"
    record_agent="${remaining%%:*}"

    [[ "$record_platform" == "$platform" ]] || continue

    if [[ ! -f "$source_agents_dir/$record_agent.md" ]]; then
      print_error "Unknown $platform agent in model override: $record_agent"
      exit 1
    fi
  done <<< "$overrides"
}

preview_model_override() {
  local platform="$1"
  local source_dir="$2"
  local platform_model_value="$3"

  [[ -d "$source_dir" ]] || return 0

  process_model_override_files "preview" "$platform" "$source_dir" "$source_dir" "*" "$platform_model_value"
}

load_model_settings_from_file "$repo_root/.claude.local.env" "claude" "CLAUDE_MODEL" file_claude_model file_agent_model_overrides
load_model_settings_from_file "$repo_root/.opencode.local.env" "opencode" "OPENCODE_MODEL" file_opencode_model file_agent_model_overrides
load_model_settings_from_file "$repo_root/.codex.local.env" "codex" "CODEX_MODEL" file_codex_model file_agent_model_overrides
load_agent_model_overrides_from_environment "claude" "CLAUDE" env_agent_model_overrides
load_agent_model_overrides_from_environment "opencode" "OPENCODE" env_agent_model_overrides
load_agent_model_overrides_from_environment "codex" "CODEX" env_agent_model_overrides

usage() {
  cat <<'EOF'
Usage: ./sync-local-agents.sh [--dry-run] [--delete] [--platform claude|opencode|codex]
[--sync both|agents|skills|config|all] [--interactive]
[--configure-api-keys]
[--claude-model MODEL]
[--opencode-model MODEL]
[--codex-model MODEL]
[--agent-model platform:agent-slug:provider/model]
[--use-recommended-models]
[--use-recommended-fallback-models]
[--recommended-provider PROVIDER]

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
Override the fallback model used in synced Claude agent frontmatter
Precedence: --claude-model > CLAUDE_MODEL env var >
./.claude.local.env > repo defaults
--opencode-model
Override the fallback model used in synced OpenCode agent frontmatter
Precedence: --opencode-model > OPENCODE_MODEL env var >
./.opencode.local.env > repo defaults
--codex-model
Override the fallback model used in synced Codex agent frontmatter
Precedence: --codex-model > CODEX_MODEL env var >
./.codex.local.env > repo defaults
--agent-model
Repeatable per-agent override.
Format: platform:agent-slug:provider/model
Validated against ./.config/model-catalog.json
--use-recommended-models
Requires explicit --platform and supports claude/opencode/codex.
Uses the first model from
platforms.<platform>.recommendedAgents.<provider>
for each selected agent and expands it into per-agent overrides.
--use-recommended-fallback-models
Requires explicit --platform and supports claude/opencode/codex.
Uses the second model from
platforms.<platform>.recommendedAgents.<provider>
for each selected agent and expands it into per-agent overrides.
Fails if any selected agent does not define a second recommendation.
--recommended-provider
Optional provider selector for recommended-model modes.
Defaults to the platform's configured default recommended provider.

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
./sync-local-agents.sh --platform claude --claude-model anthropic/sonnet
./sync-local-agents.sh --agent-model claude:backend-engineer:anthropic/sonnet
./sync-local-agents.sh --platform claude --use-recommended-models
./sync-local-agents.sh --platform opencode --use-recommended-models
./sync-local-agents.sh --platform codex --use-recommended-fallback-models
./sync-local-agents.sh --platform opencode --use-recommended-models --recommended-provider openai
./sync-local-agents.sh --platform codex --use-recommended-fallback-models --recommended-provider openai
./sync-local-agents.sh --platform opencode --configure-api-keys
./sync-local-agents.sh --opencode-model openai/gpt-5.4
./sync-local-agents.sh --platform codex --codex-model openai/gpt-5.4
EOF
}

# -----------------------------------------------------------------------------
# Interactive entry and model picker helpers
# -----------------------------------------------------------------------------

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

  print_heading "Available $label for $platform"
  print_divider
  for entry in "${all_entries[@]}"; do
    printf '  %s[%d]%s %s\n' "$color_blue" "$index" "$color_reset" "$entry"
    ((index++))
  done

  printf '%sSync all %s for %s? [Y/n]:%s ' "$color_magenta" "$label" "$platform" "$color_reset"
  read -r answer
  answer="$(trim "$answer")"
  answer="$(to_lower "$answer")"

  if [[ -z "$answer" || "$answer" == "y" || "$answer" == "yes" ]]; then
    printf -v "$__result_var" '*'
    return
  fi

  printf '%sEnter comma-separated numbers to sync (empty = skip %s):%s ' "$color_magenta" "$label" "$color_reset"
  read -r input
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
      print_warning "Ignoring invalid selection: $token"
    fi
  done

  if [[ ${#selected_entries[@]} -eq 0 ]]; then
    printf -v "$__result_var" '%s' ""
    return
  fi

  printf -v "$__result_var" '%s' "$(IFS='|'; printf '%s' "${selected_entries[*]}")"
}

prompt_interactive_recommended_provider() {
  local platform="$1"
  local __result_var="$2"
  local provider_entries=()
  local available_providers=()
  local listed_entry=""
  local provider=""
  local provider_status=""
  local default_provider=""
  local configured_default_provider=""
  local answer=""
  local index=1

  while IFS= read -r listed_entry; do
    [[ -n "$listed_entry" ]] || continue
    provider_entries+=("$listed_entry")
    available_providers+=("${listed_entry%%$'\t'*}")
    if [[ "${listed_entry#*$'\t'}" == "default" ]]; then
      default_provider="${listed_entry%%$'\t'*}"
    fi
  done < <(list_recommended_providers "$platform")

  if [[ ${#available_providers[@]} -eq 0 ]]; then
    print_error "No recommended providers are defined for $platform"
    exit 1
  fi

  configured_default_provider="$(resolve_default_recommended_provider "$platform")"
  if [[ -z "$configured_default_provider" ]]; then
    print_error "Missing default recommended provider for $platform"
    print_note "Expected platforms.$platform.defaultRecommendedProvider in ./.config/model-catalog.json"
    exit 1
  fi

  if [[ -z "$default_provider" ]]; then
    print_error "Missing recommended provider mapping for $platform: $configured_default_provider"
    print_note "Expected platforms.$platform.recommendedAgents.$configured_default_provider in ./.config/model-catalog.json"
    exit 1
  fi

  if [[ ${#available_providers[@]} -eq 1 ]]; then
    printf -v "$__result_var" '%s' "${available_providers[0]}"
    return 0
  fi

  print_heading "Recommended provider for $platform"
  print_note "Choose which provider's recommended models to apply."
  print_divider

  for listed_entry in "${provider_entries[@]}"; do
    provider="${listed_entry%%$'\t'*}"
    provider_status="${listed_entry#*$'\t'}"

    if [[ "$provider_status" == "default" ]]; then
      printf '  %s[%d]%s %s%s%s %s(default)%s\n' "$color_blue" "$index" "$color_reset" "$color_bold" "$provider" "$color_reset" "$color_dim" "$color_reset"
    else
      printf '  %s[%d]%s %s%s%s\n' "$color_blue" "$index" "$color_reset" "$color_bold" "$provider" "$color_reset"
    fi
    ((index++))
  done

  while true; do
    printf '%sChoose a recommended provider number (default: %s):%s ' "$color_magenta" "${default_provider:-${available_providers[0]}}" "$color_reset"
    read -r answer
    answer="$(trim "$answer")"

    if [[ -z "$answer" ]]; then
      printf -v "$__result_var" '%s' "${default_provider:-${available_providers[0]}}"
      return 0
    fi

    if [[ "$answer" =~ ^[0-9]+$ ]] && (( answer >= 1 && answer <= ${#available_providers[@]} )); then
      printf -v "$__result_var" '%s' "${available_providers[answer-1]}"
      return 0
    fi

    print_warning "Please choose a valid number between 1 and ${#available_providers[@]}."
  done
}

select_catalog_model_interactively() {
  local platform="$1"
  local prompt_label="$2"
  local __result_var="$3"
  local agent_slug="${4:-}"
  local recommended_provider="${5:-}"
  local available_providers=()
  local provider_entries=()
  local model_entries=()
  local filtered_model_entries=()
  local selected_provider=""
  local provider_index=""
  local selected_index=""
  local index=1
  local listed_entry=""
  local provider=""
  local model_id=""
  local target_value=""
  local description=""
  local remaining=""
  local filter_input=""
  local normalized_filter_input=""
  local normalized_model_id=""
  local normalized_description=""
  local provider_status=""
  local recommended_model_ids=()
  local recommended_model_lookup=""
  local recommended_summary=""
  local recommended_badge=""
  local badge_provider=""

  while IFS= read -r listed_entry; do
    [[ -n "$listed_entry" ]] || continue
    provider_entries+=("$listed_entry")
    available_providers+=("${listed_entry%%$'\t'*}")
  done < <(list_model_catalog_providers "$platform")

  if [[ -n "$agent_slug" ]]; then
    badge_provider="$recommended_provider"
    if [[ -z "$badge_provider" ]]; then
      badge_provider="$(resolve_default_recommended_provider "$platform")"
    fi

    while IFS= read -r listed_entry; do
      [[ -n "$listed_entry" ]] || continue
      recommended_model_ids+=("$listed_entry")
    done < <(list_recommended_model_ids_for_agent "$platform" "$agent_slug" "$badge_provider")

    if [[ ${#recommended_model_ids[@]} -gt 0 ]]; then
      recommended_model_lookup="|$(IFS='|'; printf '%s' "${recommended_model_ids[*]}")|"
      recommended_summary="$(printf '%s' "${recommended_model_ids[0]}")"

      if [[ ${#recommended_model_ids[@]} -gt 1 ]]; then
        local recommended_index=1
        while (( recommended_index < ${#recommended_model_ids[@]} )); do
          recommended_summary="$recommended_summary, ${recommended_model_ids[recommended_index]}"
          ((recommended_index++))
        done
      fi
    fi
  fi

  if [[ ${#available_providers[@]} -eq 0 ]]; then
    print_error "No catalog providers are defined for $platform"
    exit 1
  fi

  if [[ ${#available_providers[@]} -eq 1 ]]; then
    selected_provider="${available_providers[0]}"
  else
    print_heading "$prompt_label"
    print_note "Choose a provider first."
    print_divider

    index=1
    for listed_entry in "${provider_entries[@]}"; do
      provider="${listed_entry%%$'\t'*}"
      provider_status="${listed_entry#*$'\t'}"

      if [[ "$provider_status" == "favorite" ]]; then
        printf '  %s[%d]%s %s★%s %s%s%s\n' "$color_blue" "$index" "$color_reset" "$color_yellow" "$color_reset" "$color_bold" "$provider" "$color_reset"
      else
        printf '  %s[%d]%s %s%s%s\n' "$color_blue" "$index" "$color_reset" "$color_bold" "$provider" "$color_reset"
      fi
      ((index++))
    done

    while true; do
      printf '%sChoose a provider number:%s ' "$color_magenta" "$color_reset"
      read -r provider_index
      provider_index="$(trim "$provider_index")"

      if [[ "$provider_index" =~ ^[0-9]+$ ]] && (( provider_index >= 1 && provider_index <= ${#available_providers[@]} )); then
        selected_provider="${available_providers[provider_index-1]}"
        break
      fi

      print_warning "Please choose a valid number between 1 and ${#available_providers[@]}."
    done
  fi

  while IFS= read -r listed_entry; do
    [[ -n "$listed_entry" ]] || continue
    model_entries+=("$listed_entry")
  done < <(list_model_catalog_entries "$platform" "$selected_provider")

  if [[ ${#model_entries[@]} -eq 0 ]]; then
    print_error "No catalog models are defined for $platform provider $selected_provider"
    exit 1
  fi

  while true; do
    filtered_model_entries=()

    print_heading "$prompt_label"
    if [[ ${#available_providers[@]} -gt 1 ]]; then
      print_note "Provider: $selected_provider"
    fi
    if [[ -n "$agent_slug" && ${#recommended_model_ids[@]} -gt 0 ]]; then
      print_note "Recommended for $agent_slug (${badge_provider}): $recommended_summary"
    fi
    printf '%sFilter models (empty = show all):%s ' "$color_magenta" "$color_reset"
    read -r filter_input
    filter_input="$(trim "$filter_input")"
    normalized_filter_input="$(to_lower "$filter_input")"

    for listed_entry in "${model_entries[@]}"; do
      remaining="${listed_entry#*$'\t'}"
      model_id="${remaining%%$'\t'*}"
      remaining="${remaining#*$'\t'}"
      remaining="${remaining#*$'\t'}"
      description="${remaining}"

      if [[ -z "$normalized_filter_input" ]]; then
        filtered_model_entries+=("$listed_entry")
        continue
      fi

      normalized_model_id="$(to_lower "$model_id")"
      normalized_description="$(to_lower "$description")"

      if [[ "$normalized_model_id" == *"$normalized_filter_input"* || "$normalized_description" == *"$normalized_filter_input"* ]]; then
        filtered_model_entries+=("$listed_entry")
      fi
    done

    if [[ ${#filtered_model_entries[@]} -eq 0 ]]; then
      print_warning "No models matched '$filter_input'. Try another filter."
      continue
    fi

    print_divider
    index=1

    for listed_entry in "${filtered_model_entries[@]}"; do
      provider="${listed_entry%%$'\t'*}"
      remaining="${listed_entry#*$'\t'}"
      model_id="${remaining%%$'\t'*}"
      remaining="${remaining#*$'\t'}"
      target_value="${remaining%%$'\t'*}"
      description="${remaining#*$'\t'}"
      recommended_badge=""

      if [[ -n "$recommended_model_lookup" && "$recommended_model_lookup" == *"|$model_id|"* ]]; then
        recommended_badge=" ${color_green}[recommended]${color_reset}"
      fi

      if [[ "$model_id" == "$target_value" ]]; then
        printf '  %s[%d]%s %s%s%s%s\n' "$color_blue" "$index" "$color_reset" "$color_bold" "$model_id" "$color_reset" "$recommended_badge"
      else
        printf '  %s[%d]%s %s%s%s %s→%s %s%s\n' "$color_blue" "$index" "$color_reset" "$color_bold" "$model_id" "$color_reset" "$color_dim" "$color_reset" "$target_value" "$recommended_badge"
      fi

      if [[ -n "$description" ]]; then
        printf '      %s%s%s\n' "$color_dim" "$description" "$color_reset"
      fi

      ((index++))
    done

    printf '%sChoose a model number:%s ' "$color_magenta" "$color_reset"
    read -r selected_index
    selected_index="$(trim "$selected_index")"

    if [[ "$selected_index" =~ ^[0-9]+$ ]] && (( selected_index >= 1 && selected_index <= ${#filtered_model_entries[@]} )); then
      listed_entry="${filtered_model_entries[selected_index-1]}"
      printf -v "$__result_var" '%s' "${listed_entry#*$'\t'}"
      return 0
    fi

    print_warning "Please choose a valid number between 1 and ${#filtered_model_entries[@]}."
  done
}

prompt_interactive_model_overrides() {
  local platform="$1"
  local source_agents_dir="$2"
  local agent_selection="$3"
  local current_platform_model="$4"
  local recommended_provider="$5"
  local answer=""
  local selected_joined=""
  local selected_entries=()
  local entry=""
  local agent_slug=""
  local chosen_entry=""
  local requested_model=""
  local target_value=""
  local platform_cli_model=""

  case "$platform" in
    claude) platform_cli_model="$cli_claude_model" ;;
    opencode) platform_cli_model="$cli_opencode_model" ;;
    codex) platform_cli_model="$cli_codex_model" ;;
  esac

  if [[ -n "$platform_cli_model" ]] || overrides_include_platform "$cli_agent_model_overrides" "$platform"; then
    return 0
  fi

  expand_selection "$source_agents_dir" "$agent_selection" selected_joined
  [[ -n "$selected_joined" ]] || return 0

  print_heading "Model overrides for $platform"
  print_note "Current platform fallback: ${current_platform_model:-repo defaults}"
  print_divider
  printf '  %s[1]%s Keep current precedence\n' "$color_blue" "$color_reset"
  printf '  %s[2]%s One catalog model for all selected agents\n' "$color_blue" "$color_reset"
  printf '  %s[3]%s Choose per-agent catalog models\n' "$color_blue" "$color_reset"

  while true; do
    printf '%sChoose override mode [1-3]:%s ' "$color_magenta" "$color_reset"
    read -r answer
    answer="$(trim "$answer")"
    [[ -z "$answer" ]] && answer="1"

    case "$answer" in
      1)
        return 0
        ;;
      2)
        select_catalog_model_interactively "$platform" "Pick the platform model for $platform" chosen_entry
        requested_model="${chosen_entry%%$'\t'*}"
        target_value="${chosen_entry#*$'\t'}"
        target_value="${target_value%%$'\t'*}"
        case "$platform" in
          claude) interactive_claude_model="$target_value" ;;
          opencode) interactive_opencode_model="$target_value" ;;
          codex) interactive_codex_model="$target_value" ;;
        esac
        return 0
        ;;
      3)
        IFS='|' read -r -a selected_entries <<< "$selected_joined"
        for entry in "${selected_entries[@]}"; do
          [[ "$entry" == *.md ]] || continue
          agent_slug="$(basename "$entry" .md)"
          print_divider
          printf '%sAgent:%s %s%s%s\n' "$color_magenta" "$color_reset" "$color_bold" "$agent_slug" "$color_reset"
          printf '%sOverride this agent? [y/N]:%s ' "$color_magenta" "$color_reset"
          read -r answer
          answer="$(to_lower "$(trim "$answer")")"
          if [[ "$answer" == "y" || "$answer" == "yes" ]]; then
            select_catalog_model_interactively "$platform" "Pick a model for $agent_slug" chosen_entry "$agent_slug" "$recommended_provider"
            requested_model="${chosen_entry%%$'\t'*}"
            interactive_agent_model_overrides="$(append_agent_model_override "$interactive_agent_model_overrides" "$platform" "$agent_slug" "$requested_model")"
          fi
        done
        return 0
        ;;
    esac

    print_warning "Please choose 1, 2, or 3."
  done
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
  local platform="$1"
  local source_agents_dir="$2"
  local selection="$3"
  local platform_model_value="$4"

  process_model_override_files "preview" "$platform" "$source_agents_dir" "$source_agents_dir" "$selection" "$platform_model_value"
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
  local platform="$1"
  local source_agents_dir="$2"
  local target_agents_dir="$3"
  local selection="$4"
  local platform_model_value="$5"

  [[ -d "$target_agents_dir" ]] || return 0

  process_model_override_files "apply" "$platform" "$source_agents_dir" "$target_agents_dir" "$selection" "$platform_model_value"
}

# -----------------------------------------------------------------------------
# Config sync and config merge helpers
# -----------------------------------------------------------------------------

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

list_toml_table_keys() {
  local toml_file="$1"
  local root_key="$2"

  [[ -f "$toml_file" ]] || return 0

  require_node

  node - "$toml_file" "$root_key" <<'NODE'
const fs = require("fs")

const [tomlFile, rootKey] = process.argv.slice(2)
const text = fs.readFileSync(tomlFile, "utf8")
const headerPattern = /^\[([^\]\r\n]+)\][ \t]*$/gm
const keys = new Set()
let match

while ((match = headerPattern.exec(text)) !== null) {
  const headerName = match[1]
  if (!headerName.startsWith(`${rootKey}.`)) {
    continue
  }

  const key = headerName.slice(rootKey.length + 1)
  if (key.length === 0 || key.includes(".")) {
    continue
  }

  keys.add(key)
}

for (const key of [...keys].sort()) {
  process.stdout.write(`${key}\n`)
}
NODE
}

collect_selected_config_keys() {
  local config_file="$1"
  local root_key="$2"
  local label="$3"
  local platform="$4"
  local config_format="$5"
  local __result_var="$6"
  local all_entries=()
  local selected_entries=()
  local index=1
  local answer=""
  local input=""
  local token=""
  local -a tokens=()
  local listed_entry=""

  if [[ "$config_format" == "toml" ]]; then
    while IFS= read -r listed_entry; do
      all_entries+=("$listed_entry")
    done < <(list_toml_table_keys "$config_file" "$root_key")
  else
    while IFS= read -r listed_entry; do
      all_entries+=("$listed_entry")
    done < <(list_json_object_keys "$config_file" "$root_key")
  fi

  if [[ ${#all_entries[@]} -eq 0 ]]; then
    printf -v "$__result_var" '%s' ""
    return
  fi

  print_heading "Available $label for $platform"
  print_divider
  for entry in "${all_entries[@]}"; do
    printf '  %s[%d]%s %s\n' "$color_blue" "$index" "$color_reset" "$entry"
    ((index++))
  done

  printf '%sSync all %s for %s? [Y/n]:%s ' "$color_magenta" "$label" "$platform" "$color_reset"
  read -r answer
  answer="$(trim "$answer")"
  answer="$(to_lower "$answer")"

  if [[ -z "$answer" || "$answer" == "y" || "$answer" == "yes" ]]; then
    printf -v "$__result_var" '*'
    return
  fi

  printf '%sEnter comma-separated numbers to sync (empty = skip %s):%s ' "$color_magenta" "$label" "$color_reset"
  read -r input
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
      print_warning "Ignoring invalid selection: $token"
    fi
  done

  if [[ ${#selected_entries[@]} -eq 0 ]]; then
    printf -v "$__result_var" '%s' ""
    return
  fi

  printf -v "$__result_var" '%s' "$(IFS='|'; printf '%s' "${selected_entries[*]}")"
}

collect_selected_json_keys() {
  local json_file="$1"
  local root_key="$2"
  local label="$3"
  local platform="$4"
  local __result_var="$5"
  collect_selected_config_keys "$json_file" "$root_key" "$label" "$platform" "json" "$__result_var"
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

merge_selected_toml_tables() {
  local source_toml="$1"
  local target_toml="$2"
  local root_key="$3"
  local selection="$4"

  require_node

  mkdir -p "$(dirname "$target_toml")"

  node - "$source_toml" "$target_toml" "$root_key" "$selection" <<'NODE'
const fs = require("fs")

const [sourceToml, targetToml, rootKey, selection] = process.argv.slice(2)
const sourceText = fs.readFileSync(sourceToml, "utf8")
const targetText = fs.existsSync(targetToml)
  ? fs.readFileSync(targetToml, "utf8")
  : ""

function parseBlocks(text, tableRoot) {
  const headerPattern = /^\[([^\]\r\n]+)\][ \t]*$/gm
  const headers = []
  let match

  while ((match = headerPattern.exec(text)) !== null) {
    headers.push({
      headerName: match[1],
      index: match.index,
    })
  }

  const blocks = new Map()
  const tablePrefix = `${tableRoot}.`

  for (let index = 0; index < headers.length; index += 1) {
    const currentHeader = headers[index]
    const blockStart = currentHeader.index
    const blockEnd = index + 1 < headers.length ? headers[index + 1].index : text.length

    if (!currentHeader.headerName.startsWith(tablePrefix)) {
      continue
    }

    const key = currentHeader.headerName.slice(tablePrefix.length)
    if (key.length === 0 || key.includes(".")) {
      continue
    }

    blocks.set(key, text.slice(blockStart, blockEnd).trimEnd())
  }

  return blocks
}

function removeSelectedBlocks(text, tableRoot, selectedKeys) {
  const headerPattern = /^\[([^\]\r\n]+)\][ \t]*$/gm
  const headers = []
  let match

  while ((match = headerPattern.exec(text)) !== null) {
    headers.push({
      headerName: match[1],
      index: match.index,
    })
  }

  const tablePrefix = `${tableRoot}.`
  let result = ""
  let cursor = 0

  for (let index = 0; index < headers.length; index += 1) {
    const currentHeader = headers[index]
    const blockStart = currentHeader.index
    const blockEnd = index + 1 < headers.length ? headers[index + 1].index : text.length

    if (!currentHeader.headerName.startsWith(tablePrefix)) {
      continue
    }

    const key = currentHeader.headerName.slice(tablePrefix.length)
    if (!selectedKeys.has(key) || key.includes(".")) {
      continue
    }

    result += text.slice(cursor, blockStart)
    cursor = blockEnd
  }

  result += text.slice(cursor)
  return result.trimEnd()
}

const sourceBlocks = parseBlocks(sourceText, rootKey)
const selectedKeys = selection === "*"
  ? [...sourceBlocks.keys()]
  : selection.split("|").filter(Boolean)
const existingKeys = new Set(selectedKeys.filter((key) => sourceBlocks.has(key)))
const mergedBody = removeSelectedBlocks(targetText, rootKey, existingKeys)
const appendedBlocks = selectedKeys
  .filter((key) => sourceBlocks.has(key))
  .map((key) => sourceBlocks.get(key))
  .join("\n\n")

const output = [mergedBody, appendedBlocks]
  .filter((value) => value.length > 0)
  .join("\n\n")

fs.writeFileSync(targetToml, output.length > 0 ? `${output}\n` : "")
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

  print_heading "Config sync for $platform"
  print_note "Target file: $config_name"
  printf '%sHow do you want to sync it? [full/mcp/skip] (default: full):%s ' "$color_magenta" "$color_reset"
  read -r answer
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
    print_error "Unsupported config sync mode: $answer (expected: full|mcp|skip)"
    exit 1
      ;;
  esac
}

prompt_interactive_scope() {
  local answer=""

  if [[ ! -t 0 || ! -t 1 ]]; then
    print_error "--interactive requires an interactive terminal (TTY stdin/stdout)."
    exit 1
  fi

  print_heading "Local agent sync"
  print_note "Interactive mode lets you narrow scope, entries, config, and model overrides."
  print_divider
  printf '%sWhat do you want to sync? [both/agents/skills/config/all] (default: %s):%s ' "$color_magenta" "$sync_scope" "$color_reset"
  read -r answer
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
        print_error "Missing value for --claude-model"
        exit 1
      fi
      cli_claude_model="$(normalize_model_catalog_value "$2")"
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
        print_error "Missing value for --opencode-model"
        exit 1
      fi
      cli_opencode_model="$(normalize_model_catalog_value "$2")"
      shift
      ;;
    --codex-model)
      if [[ $# -lt 2 ]]; then
        print_error "Missing value for --codex-model"
        exit 1
      fi
      cli_codex_model="$(normalize_model_catalog_value "$2")"
      shift
      ;;
    --agent-model)
      if [[ $# -lt 2 ]]; then
        print_error "Missing value for --agent-model"
        exit 1
      fi
      parse_cli_agent_model_override "$2"
      shift
      ;;
    --use-recommended-models)
      use_recommended_models=true
      ;;
    --use-recommended-fallback-models)
      use_recommended_fallback_models=true
      ;;
    --recommended-provider)
      if [[ $# -lt 2 ]]; then
        print_error "Missing value for --recommended-provider"
        exit 1
      fi
      cli_recommended_provider="$(normalize_model_catalog_value "$2")"
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
      print_error "Unknown argument: $1"
      usage >&2
      exit 1
      ;;
    esac
    shift
  done

if [[ "$use_recommended_models" == true && "$use_recommended_fallback_models" == true ]]; then
  print_error "Choose either --use-recommended-models or --use-recommended-fallback-models, not both."
  exit 1
fi

if [[ -n "$cli_recommended_provider" && "$use_recommended_models" != true && "$use_recommended_fallback_models" != true ]]; then
  print_error "--recommended-provider requires --use-recommended-models or --use-recommended-fallback-models."
  exit 1
fi

if [[ "$use_recommended_models" == true || "$use_recommended_fallback_models" == true ]]; then
  if [[ ${#selected_platforms[@]} -eq 0 ]]; then
    print_error "--use-recommended-models and --use-recommended-fallback-models require explicit --platform."
    exit 1
  fi

  for platform in "${selected_platforms[@]}"; do
    case "$platform" in
      claude|opencode|codex)
        ;;
      *)
        print_error "Recommended model flags support only claude, opencode, and codex: $platform"
        exit 1
        ;;
    esac
  done
fi

claude_model="$(resolve_platform_model_override "claude" "$cli_claude_model" "$env_claude_model" "$file_claude_model")"
opencode_model="$(resolve_platform_model_override "opencode" "$cli_opencode_model" "$env_opencode_model" "$file_opencode_model")"
codex_model="$(resolve_platform_model_override "codex" "$cli_codex_model" "$env_codex_model" "$file_codex_model")"

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync is required but not installed." >&2
  exit 1
fi

if [[ ${#selected_platforms[@]} -eq 0 ]]; then
  selected_platforms=(claude opencode codex)
fi

if [[ "$use_recommended_models" == true || "$use_recommended_fallback_models" == true ]]; then
  validate_recommended_provider_selection "$cli_recommended_provider"
fi

if [[ "$interactive_mode" == true ]]; then
  prompt_interactive_scope
fi

# -----------------------------------------------------------------------------
# Main sync flow
# -----------------------------------------------------------------------------

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

resolve_platform_settings() {
  local platform="$1"
  local __source_base_var="$2"
  local __target_base_var="$3"
  local __model_override_var="$4"
  local __config_source_var="$5"
  local __config_target_var="$6"
  local __mcp_root_key_var="$7"
  local source_base_value=""
  local target_base_value=""
  local model_override_value=""
  local config_source_value=""
  local config_target_value=""
  local mcp_root_key_value=""

  case "$platform" in
    claude)
      source_base_value="$repo_root/.claude"
      target_base_value="$HOME/.claude"
      model_override_value="$claude_model"
      config_source_value="$source_base_value/settings.json"
      config_target_value="$target_base_value/settings.json"
      mcp_root_key_value="mcpServers"
      ;;
    opencode)
      source_base_value="$repo_root/.config/opencode"
      target_base_value="$HOME/.config/opencode"
      model_override_value="$opencode_model"
      config_source_value="$source_base_value/opencode.json"
      config_target_value="$target_base_value/opencode.json"
      mcp_root_key_value="mcp"
      ;;
    codex)
      source_base_value="$repo_root/.codex"
      target_base_value="$HOME/.codex"
      model_override_value="$codex_model"
      config_source_value="$source_base_value/config.toml"
      config_target_value="$target_base_value/config.toml"
      mcp_root_key_value="mcp_servers"
      ;;
    *)
      print_error "Unsupported platform: $platform"
      exit 1
      ;;
  esac

  printf -v "$__source_base_var" '%s' "$source_base_value"
  printf -v "$__target_base_var" '%s' "$target_base_value"
  printf -v "$__model_override_var" '%s' "$model_override_value"
  printf -v "$__config_source_var" '%s' "$config_source_value"
  printf -v "$__config_target_var" '%s' "$config_target_value"
  printf -v "$__mcp_root_key_var" '%s' "$mcp_root_key_value"
}

resolve_interactive_platform_model_override() {
  local platform="$1"

  case "$platform" in
    claude)
      printf '%s' "$interactive_claude_model"
      ;;
    opencode)
      printf '%s' "$interactive_opencode_model"
      ;;
    codex)
      printf '%s' "$interactive_codex_model"
      ;;
  esac
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
  local interactive_model_override=""
  local recommended_overrides=""
  local recommended_provider=""

  resolve_platform_settings "$platform" source_base target_base model_override config_source config_target mcp_root_key

  if [[ ! -d "$source_base/agents" && ! -d "$source_base/skills" ]]; then
    echo "Skipping $platform: no agents or skills found in $source_base" >&2
    return
  fi

  print_heading "Syncing $platform"

  if [[ "$sync_agents" == true && -d "$source_base/agents" ]]; then
    validate_agent_override_targets_exist "$source_base/agents" "$platform" "$cli_agent_model_overrides"
    validate_agent_override_targets_exist "$source_base/agents" "$platform" "$env_agent_model_overrides"
    validate_agent_override_targets_exist "$source_base/agents" "$platform" "$file_agent_model_overrides"

    if [[ "$interactive_mode" == true ]]; then
      collect_selected_entries "$source_base/agents" "agents" "$platform" agent_selection

      if [[ "$use_recommended_models" == true || "$use_recommended_fallback_models" == true ]]; then
        if [[ -n "$cli_recommended_provider" ]]; then
          recommended_provider="$(resolve_effective_recommended_provider "$platform" "$cli_recommended_provider")"
        else
          prompt_interactive_recommended_provider "$platform" recommended_provider
        fi
      fi

      prompt_interactive_model_overrides "$platform" "$source_base/agents" "$agent_selection" "$model_override" "$recommended_provider"

      interactive_model_override="$(resolve_interactive_platform_model_override "$platform")"
      [[ -n "$interactive_model_override" ]] && model_override="$interactive_model_override"

      validate_agent_override_targets_exist "$source_base/agents" "$platform" "$interactive_agent_model_overrides"
    fi

    if [[ "$use_recommended_models" == true ]]; then
      [[ -z "$recommended_provider" ]] && recommended_provider="$(resolve_effective_recommended_provider "$platform" "$cli_recommended_provider")"
      build_recommended_agent_model_overrides "$platform" "$source_base/agents" "$agent_selection" 0 "recommended model" "$recommended_provider" recommended_overrides
      generated_agent_model_overrides="$(append_override_record "$generated_agent_model_overrides" "$recommended_overrides")"
    elif [[ "$use_recommended_fallback_models" == true ]]; then
      [[ -z "$recommended_provider" ]] && recommended_provider="$(resolve_effective_recommended_provider "$platform" "$cli_recommended_provider")"
      build_recommended_agent_model_overrides "$platform" "$source_base/agents" "$agent_selection" 1 "recommended fallback model" "$recommended_provider" recommended_overrides
      generated_agent_model_overrides="$(append_override_record "$generated_agent_model_overrides" "$recommended_overrides")"
    fi

    if [[ "$agent_selection" == "*" ]]; then
      run_rsync "$source_base/agents" "$target_base/agents"
      if [[ "$dry_run" == true ]]; then
        preview_model_override "$platform" "$source_base/agents" "$model_override"
      else
        apply_model_override "$platform" "$target_base/agents" "$model_override"
      fi
    elif [[ -n "$agent_selection" ]]; then
      expand_selection "$source_base/agents" "$agent_selection" selection_joined
      IFS='|' read -r -a selected_entries <<< "$selection_joined"
      for entry in "${selected_entries[@]}"; do
        run_rsync_entry "$source_base/agents/$entry" "$target_base/agents/$entry"
      done

      if [[ "$dry_run" == true ]]; then
        preview_model_override_for_entries "$platform" "$source_base/agents" "$agent_selection" "$model_override"
      else
        apply_model_override_for_entries "$platform" "$source_base/agents" "$target_base/agents" "$agent_selection" "$model_override"
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
      elif [[ "$platform" == "codex" ]]; then
        if [[ "$dry_run" == true ]]; then
          preview_selected_json_keys_sync "$platform" "$config_target" "repo-managed Codex MCP servers" "*"
        else
          merge_selected_toml_tables "$config_source" "$config_target" "$mcp_root_key" "*"
          echo "Synced repo-managed Codex MCP config into $config_target"
        fi
      else
        run_rsync_entry "$config_source" "$config_target"
      fi
      ;;
    mcp)
      if [[ "$platform" == "codex" ]]; then
        collect_selected_config_keys "$config_source" "$mcp_root_key" "MCP servers" "$platform" "toml" mcp_selection
      else
        collect_selected_json_keys "$config_source" "$mcp_root_key" "MCP servers" "$platform" mcp_selection
      fi

      if [[ -z "$mcp_selection" ]]; then
        echo "Skipping MCP sync for $platform"
        return 0
      fi

      if [[ "$platform" == "codex" ]]; then
        if [[ "$dry_run" == true ]]; then
          preview_selected_json_keys_sync "$platform" "$config_target" "MCP servers" "$mcp_selection"
        else
          merge_selected_toml_tables "$config_source" "$config_target" "$mcp_root_key" "$mcp_selection"
          echo "Synced selected MCP servers for $platform"
        fi
      else
        sync_selected_mcp_servers "$platform" "$config_source" "$config_target" "$mcp_root_key" "$mcp_selection"
      fi
      ;;
  esac
}

for platform in "${selected_platforms[@]}"; do
  sync_platform "$platform"
done
