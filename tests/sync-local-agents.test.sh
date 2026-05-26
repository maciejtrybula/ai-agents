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

recommended_output="$(run_and_capture bash "$repo_root/sync-local-agents.sh" --dry-run --sync agents --platform claude --use-recommended-models)"
assert_contains "$recommended_output" ".claude/agents/backend-architect.md -> opus"
assert_contains "$recommended_output" ".claude/agents/backend-engineer.md -> sonnet"
assert_contains "$recommended_output" ".claude/agents/content-writer.md -> haiku"

fallback_output="$(run_and_capture bash "$repo_root/sync-local-agents.sh" --dry-run --sync agents --platform claude --use-recommended-fallback-models)"
assert_contains "$fallback_output" ".claude/agents/backend-architect.md -> sonnet"
assert_contains "$fallback_output" ".claude/agents/backend-engineer.md -> haiku"
assert_contains "$fallback_output" ".claude/agents/content-writer.md -> sonnet"

printf 'Claude recommended model sync checks passed.\n'
