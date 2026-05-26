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
assert_contains "$opencode_default_output" ".config/opencode/agents/backend-engineer.md -> github-copilot/claude-sonnet-4.6"
assert_not_contains "$opencode_default_output" ".config/opencode/agents/backend-engineer.md -> openai/gpt-5.3-codex"

codex_default_output="$(run_and_capture bash "$repo_root/sync-local-agents.sh" --dry-run --sync agents --platform codex --use-recommended-models)"
assert_contains "$codex_default_output" ".codex/agents/backend-engineer.md -> github-copilot/claude-sonnet-4.6"
assert_not_contains "$codex_default_output" ".codex/agents/backend-engineer.md -> openai/gpt-5.4"

opencode_openai_output="$(run_and_capture bash "$repo_root/sync-local-agents.sh" --dry-run --sync agents --platform opencode --use-recommended-models --recommended-provider openai)"
assert_contains "$opencode_openai_output" ".config/opencode/agents/backend-engineer.md -> openai/gpt-5.3-codex"
assert_contains "$opencode_openai_output" ".config/opencode/agents/content-writer.md -> openai/gpt-5.4"

opencode_openai_fallback_output="$(run_and_capture bash "$repo_root/sync-local-agents.sh" --dry-run --sync agents --platform opencode --use-recommended-fallback-models --recommended-provider openai)"
assert_contains "$opencode_openai_fallback_output" ".config/opencode/agents/backend-engineer.md -> openai/gpt-5.4"
assert_contains "$opencode_openai_fallback_output" ".config/opencode/agents/content-writer.md -> openai/gpt-5.3-codex"

codex_openai_output="$(run_and_capture bash "$repo_root/sync-local-agents.sh" --dry-run --sync agents --platform codex --use-recommended-models --recommended-provider openai)"
assert_contains "$codex_openai_output" ".codex/agents/backend-engineer.md -> openai/gpt-5.4"
assert_contains "$codex_openai_output" ".codex/agents/backend-architect.md -> openai/gpt-5.4"

invalid_usage_output="$(run_and_capture_failure bash "$repo_root/sync-local-agents.sh" --dry-run --sync agents --platform opencode --recommended-provider openai)"
assert_contains "$invalid_usage_output" "--recommended-provider requires --use-recommended-models or --use-recommended-fallback-models."

unsupported_provider_output="$(run_and_capture_failure bash "$repo_root/sync-local-agents.sh" --dry-run --sync agents --platform opencode --platform claude --use-recommended-models --recommended-provider openai)"
assert_contains "$unsupported_provider_output" "Unsupported recommended provider for claude: openai"
assert_not_contains "$unsupported_provider_output" "Syncing opencode"

printf 'Recommended model sync checks passed.\n'
