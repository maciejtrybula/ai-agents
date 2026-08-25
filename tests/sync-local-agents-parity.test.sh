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
# under it must match in all other trees. Agent files use Markdown in Claude and
# OpenCode, but TOML in Codex.
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

# Emit the developer-instructions body from a generated Codex agent TOML file.
codex_body() {
  local file="$1"

  awk '
    $0 == "developer_instructions = \"\"\"" { in_body=1; next }
    in_body && $0 == "\"\"\"" { exit }
    in_body { print }
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
  local codex_rel=""
  local ref_body=""
  local other_body=""

  while IFS= read -r ref_file; do
    rel="${ref_file#"$ref_dir"/}"
    ref_body="$(md_body "$ref_file")"

    other="$other_root_a/$subdir/$rel"
    if [[ ! -f "$other" ]]; then
      printf 'FAIL: %s not present in %s (missing shared file)\n' "$rel" "$other" >&2
      failures=$((failures + 1))
    else
      other_body="$(md_body "$other")"
      if [[ "$ref_body" != "$other_body" ]]; then
        printf 'FAIL: body drift for %s\n  reference: %s\n  drift:     %s\n' \
          "$rel" "$ref_file" "$other" >&2
        failures=$((failures + 1))
      fi
    fi

    codex_rel="$rel"
    if [[ "$subdir" == "agents" ]]; then
      codex_rel="${rel%.md}.toml"
    fi
    other="$other_root_b/$subdir/$codex_rel"
    if [[ ! -f "$other" ]]; then
      printf 'FAIL: %s not present in %s (missing shared file)\n' "$codex_rel" "$other" >&2
      failures=$((failures + 1))
      continue
    fi

    if [[ "$subdir" == "agents" ]]; then
      other_body="$(codex_body "$other")"
    else
      other_body="$(md_body "$other")"
    fi
    if [[ "$ref_body" != "$other_body" ]]; then
      printf 'FAIL: body drift for %s\n  reference: %s\n  drift:     %s\n' \
        "$rel" "$ref_file" "$other" >&2
      failures=$((failures + 1))
    fi
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

# Copy the real shared agent into all three temp trees, preserving each
# platform's native format, then intentionally corrupt the Codex instruction
# body. This mirrors the exact drift the parity check must catch.
cp -a "$CLAUDE_TREE/agents/backend-architect.md" "$neg_ref/agents/backend-architect.md"
cp -a "$CLAUDE_TREE/agents/backend-architect.md" "$neg_opencode/agents/backend-architect.md"
cp -a "$CODEX_TREE/agents/backend-architect.toml" "$neg_codex/agents/backend-architect.toml"

# Corrupt the Codex developer-instructions body while leaving its TOML fields
# and delimiters intact.
perl -0pi -e 's/(developer_instructions = """\n.*?)(\n""")/$1\n# DRIFTED BODY LINE$2/s' \
  "$neg_codex/agents/backend-architect.toml"

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
