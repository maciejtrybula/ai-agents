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

output_file="$(mktemp)"
trap 'rm -f "$output_file"' EXIT

bash "$repo_root/sync-local-agents.sh" --dry-run --sync config --platform codex >"$output_file" 2>&1
output="$(<"$output_file")"

assert_contains "$output" 'Would sync repo-managed Codex config into'
assert_contains "$output" 'Would bootstrap Codex ponytail plugin via: codex plugin marketplace add DietrichGebert/ponytail'
assert_contains "$output" 'Would bootstrap Codex caveman skill via: npx skills add JuliusBrussee/caveman -a codex'

printf 'Codex bootstrap sync checks passed.\n'
