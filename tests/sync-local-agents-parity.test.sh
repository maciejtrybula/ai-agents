#!/usr/bin/env bash

# Body-parity (drift) test for the agent-hub.
#
# Core invariant: for every shared agent under .claude/agents/,
# .config/opencode/agents/ and .codex/agents/ (and skills under the matching
# skills/ trees), the markdown BODY must be byte-identical across all three
# trees. The YAML frontmatter (the leading `--- ... ---` block) is allowed to
# differ because each platform may carry platform-specific metadata (e.g. model
# overrides); the body may not.
#
# This test is runnable WITHOUT `rsync` installed.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

# Trees to compare. The FIRST tree is the canonical reference; every shared file
# under it must match in all other trees.
readonly CLAUDE_TREE="$repo_root/.claude"
readonly OPENCODE_TREE="$repo_root/.config/opencode"
readonly CODEX_TREE="$repo_root/.codex"

# Emit the markdown body of a file:
#   - If the file begins with a leading `---`-delimited YAML frontmatter block,
#     the body is everything after the closing `---` line.
#   - Otherwise (no frontmatter) the body is the whole file.
md_body() {
  local file="$1"
  awk '
    BEGIN { delim=0; has_fm=0 }
    {
      if (delim == 0 && $0 == "---") { delim=1; has_fm=1; next }
      if (delim == 1 && $0 == "---") { delim=2; next }
      if (delim >= 2) print
      if (delim == 0) print
    }
  ' "$file"
}

failures=0

# Check that every shared file under `$ref_root/<subdir>` has a byte-identical
# body in the two other trees. `subdir` is "agents" or "skills". On any drift,
# increments the global `failures` counter.
check_parity() {
  local ref_root="$1"
  local other_root_a="$2"
  local other_root_b="$3"
  local subdir="$4"
  local ref_dir="$ref_root/$subdir"

  if [[ ! -d "$ref_dir" ]]; then
    printf 'skip: reference tree has no %s directory\n' "$ref_dir" >&2
    return 0
  fi

  local rel=""
  local ref_file=""
  local other=""
  local ref_body=""
  local other_body=""

  while IFS= read -r ref_file; do
    rel="${ref_file#"$ref_dir"/}"
    for other in "$other_root_a/$subdir/$rel" "$other_root_b/$subdir/$rel"; do
      if [[ ! -f "$other" ]]; then
        printf 'FAIL: %s not present in %s (missing shared file)\n' "$rel" "$other" >&2
        failures=$((failures + 1))
        continue
      fi
      ref_body="$(md_body "$ref_file")"
      other_body="$(md_body "$other")"
      if [[ "$ref_body" != "$other_body" ]]; then
        printf 'FAIL: body drift for %s\n  reference: %s\n  drift:     %s\n' \
          "$rel" "$ref_file" "$other" >&2
        failures=$((failures + 1))
      fi
    done
  done < <(find "$ref_dir" -type f -name '*.md' | sort)
}

check_parity "$CLAUDE_TREE" "$OPENCODE_TREE" "$CODEX_TREE" "agents"
check_parity "$CLAUDE_TREE" "$OPENCODE_TREE" "$CODEX_TREE" "skills"

if [[ "$failures" -ne 0 ]]; then
  printf 'Body parity check FAILED with %d drift(s).\n' "$failures" >&2
  exit 1
fi

printf 'Body parity check passed for shared agents and skills.\n'

# -----------------------------------------------------------------------------
# Negative test: the check above must actually catch drift. Build a trio of temp
# trees where one shared agent body is deliberately drifted, then assert the full
# parity check FAILS.
# -----------------------------------------------------------------------------

neg_dir="$(mktemp -d)"
trap 'rm -rf "$neg_dir"' EXIT

neg_ref="$neg_dir/ref/.claude"
neg_opencode="$neg_dir/opencode"
neg_codex="$neg_dir/codex"

mkdir -p "$neg_ref/agents" "$neg_ref/skills"
mkdir -p "$neg_opencode/agents" "$neg_opencode/skills"
mkdir -p "$neg_codex/agents" "$neg_codex/skills"

# Copy the real shared agent (with its frontmatter) into all three temp trees,
# then intentionally corrupt the BODY of the opencode copy while leaving its
# frontmatter untouched. This mirrors the exact drift the parity check must catch.
cp -a "$CLAUDE_TREE/agents/backend-architect.md" "$neg_ref/agents/backend-architect.md"
cp -a "$CLAUDE_TREE/agents/backend-architect.md" "$neg_opencode/agents/backend-architect.md"
cp -a "$CLAUDE_TREE/agents/backend-architect.md" "$neg_codex/agents/backend-architect.md"

# Corrupt the body of the opencode copy (append to a body line; frontmatter is
# unaffected because it is the leading delimited block).
printf '\n# DRIFTED BODY LINE\n' >> "$neg_opencode/agents/backend-architect.md"

neg_failures=0
failures=0
check_parity "$neg_ref" "$neg_opencode" "$neg_codex" "agents"
neg_failures="$failures"

if [[ "$neg_failures" -eq 0 ]]; then
  printf 'FAIL: negative test did not detect the deliberate drift\n' >&2
  exit 1
fi

printf 'Negative test confirmed: parity check detects body drift (%d drift(s) flagged).\n' "$neg_failures"
printf 'Parity checks passed.\n'
