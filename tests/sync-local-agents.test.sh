#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

assert_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'Expected output to contain: %s\n' "$needle" >&2
    exit 1
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "$haystack" == *"$needle"* ]]; then
    printf 'Expected output to not contain: %s\n' "$needle" >&2
    exit 1
  fi
}

run_and_capture() {
  local output_file
  output_file="$(mktemp)"

  if ! "$@" >"$output_file" 2>&1; then
    cat "$output_file" >&2
    rm -f "$output_file"
    return 1
  fi

  cat "$output_file"
  rm -f "$output_file"
}

run_and_capture_failure() {
  local output_file
  output_file="$(mktemp)"

  if "$@" >"$output_file" 2>&1; then
    cat "$output_file" >&2
    rm -f "$output_file"
    printf 'Expected command to fail but it succeeded\n' >&2
    return 1
  fi

  cat "$output_file"
  rm -f "$output_file"
}

recommended_output="$(run_and_capture bash "$repo_root/sync-local-agents.sh" --dry-run --sync agents --platform claude --use-recommended-models)"
assert_contains "$recommended_output" ".claude/agents/backend-architect.md -> opus"
assert_contains "$recommended_output" ".claude/agents/backend-engineer.md -> sonnet"
assert_contains "$recommended_output" ".claude/agents/content-writer.md -> haiku"

fallback_output="$(run_and_capture bash "$repo_root/sync-local-agents.sh" --dry-run --sync agents --platform claude --use-recommended-fallback-models)"
assert_contains "$fallback_output" ".claude/agents/backend-architect.md -> sonnet"
assert_contains "$fallback_output" ".claude/agents/backend-engineer.md -> haiku"
assert_contains "$fallback_output" ".claude/agents/content-writer.md -> sonnet"

opencode_default_output="$(run_and_capture bash "$repo_root/sync-local-agents.sh" --dry-run --sync agents --platform opencode --use-recommended-models)"
assert_contains "$opencode_default_output" ".config/opencode/agents/backend-engineer.md -> github-copilot/gpt-5.6-luna"
assert_not_contains "$opencode_default_output" ".config/opencode/agents/backend-engineer.md -> openai/gpt-5.3-codex"

codex_default_output="$(run_and_capture bash "$repo_root/sync-local-agents.sh" --dry-run --sync agents --platform codex --use-recommended-models)"
assert_contains "$codex_default_output" ".codex/agents/backend-engineer.toml -> github-copilot/gpt-5.6-luna"
assert_not_contains "$codex_default_output" ".codex/agents/backend-engineer.toml -> openai/gpt-5.4"

opencode_openai_output="$(run_and_capture bash "$repo_root/sync-local-agents.sh" --dry-run --sync agents --platform opencode --use-recommended-models --recommended-provider openai)"
assert_contains "$opencode_openai_output" ".config/opencode/agents/backend-engineer.md -> openai/gpt-5.6-luna"
assert_contains "$opencode_openai_output" ".config/opencode/agents/content-writer.md -> openai/gpt-5.6-luna"

opencode_openai_fallback_output="$(run_and_capture bash "$repo_root/sync-local-agents.sh" --dry-run --sync agents --platform opencode --use-recommended-fallback-models --recommended-provider openai)"
assert_contains "$opencode_openai_fallback_output" ".config/opencode/agents/backend-engineer.md -> openai/gpt-5.6-luna"
assert_contains "$opencode_openai_fallback_output" ".config/opencode/agents/content-writer.md -> openai/gpt-5.6-luna"

codex_openai_output="$(run_and_capture bash "$repo_root/sync-local-agents.sh" --dry-run --sync agents --platform codex --use-recommended-models --recommended-provider openai)"
assert_contains "$codex_openai_output" ".codex/agents/backend-engineer.toml -> openai/gpt-5.6-luna"
assert_contains "$codex_openai_output" ".codex/agents/backend-architect.toml -> openai/gpt-5.6-sol"

codex_sync_target_dir="$(mktemp -d)"
codex_sync_home="$(mktemp -d)"
HOME="$codex_sync_home" bash "$repo_root/sync-local-agents.sh" \
  --sync agents --platform codex --target-dir "$codex_sync_target_dir" \
  --codex-model openai/gpt-5.6-luna \
  --agent-model codex:backend-architect:openai/gpt-5.6-sol >/dev/null 2>&1

codex_synced_file="$codex_sync_target_dir/.codex/agents/backend-architect.toml"
codex_synced_content="$(cat "$codex_synced_file")"
assert_contains "$codex_synced_content" 'model = "openai/gpt-5.6-sol"'
assert_contains "$codex_synced_content" 'developer_instructions = """'
if [[ -e "$codex_sync_target_dir/.codex/agents/backend-architect.md" ]]; then
  printf 'Expected Codex sync to preserve native TOML output, not create Markdown\n' >&2
  exit 1
fi

codex_source_body="$(awk '
  $0 == "developer_instructions = \"\"\"" { in_body=1; next }
  in_body && $0 == "\"\"\"" { exit }
  in_body { print }
' "$repo_root/.codex/agents/backend-architect.toml")"
codex_synced_body="$(awk '
  $0 == "developer_instructions = \"\"\"" { in_body=1; next }
  in_body && $0 == "\"\"\"" { exit }
  in_body { print }
' "$codex_synced_file")"
if [[ "$codex_source_body" != "$codex_synced_body" ]]; then
  printf 'Expected Codex sync to preserve developer_instructions\n' >&2
  exit 1
fi

codex_invalid_source_file="$repo_root/.codex/agents/backend-architect.toml"
codex_invalid_source_backup="$(mktemp)"
codex_invalid_target_dir="$(mktemp -d)"
cp "$codex_invalid_source_file" "$codex_invalid_source_backup"
{
  printf '%s\n' 'name = "backend-architect"'
  printf '%s\n' 'description = "invalid test fixture"'
  printf '%s\n' '[nested]'
  printf '%s\n' 'model = "nested-model"'
  printf '%s\n' 'developer_instructions = """'
  printf '%s\n' 'model = "body-model"'
  printf '%s\n' '"""'
} >"$codex_invalid_source_file"

codex_invalid_output=""
if codex_invalid_output="$(run_and_capture_failure bash "$repo_root/sync-local-agents.sh" \
  --sync agents --platform codex --target-dir "$codex_invalid_target_dir" \
  --codex-model openai/gpt-5.6-luna)"; then
  codex_invalid_command_failed=true
else
  codex_invalid_command_failed=false
fi
mv "$codex_invalid_source_backup" "$codex_invalid_source_file"

if [[ "$codex_invalid_command_failed" != true ]]; then
  printf 'Expected Codex sync to fail when the top-level model key is missing\n' >&2
  exit 1
fi
assert_contains "$codex_invalid_output" "top-level model key"
codex_invalid_synced_content="$(cat "$codex_invalid_target_dir/.codex/agents/backend-architect.toml")"
assert_contains "$codex_invalid_synced_content" 'model = "nested-model"'
assert_contains "$codex_invalid_synced_content" 'model = "body-model"'
rm -rf "$codex_sync_target_dir" "$codex_sync_home" "$codex_invalid_target_dir" "$codex_invalid_source_backup"

invalid_usage_output="$(run_and_capture_failure bash "$repo_root/sync-local-agents.sh" --dry-run --sync agents --platform opencode --recommended-provider openai)"
assert_contains "$invalid_usage_output" "--recommended-provider requires --use-recommended-models or --use-recommended-fallback-models."

unsupported_provider_output="$(run_and_capture_failure bash "$repo_root/sync-local-agents.sh" --dry-run --sync agents --platform opencode --platform claude --use-recommended-models --recommended-provider openai)"
assert_contains "$unsupported_provider_output" "Unsupported recommended provider for claude: openai"
assert_not_contains "$unsupported_provider_output" "Syncing opencode"

printf 'Recommended model sync checks passed.\n'
