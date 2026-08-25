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
  perl -0e '
    my $text = <>;
    my $body_start = 0;

    if ($text =~ /\A---(?:\r?\n|\z)/) {
      $body_start = $+[0];
      my $frontmatter = substr($text, $body_start);
      if ($frontmatter =~ /^---(?:\r?\n|\z)/m) {
        print substr($text, $body_start + $+[0]);
        exit 0;
      }
    }

    print $text;
  ' "$file"
}

# Emit the developer-instructions body from a generated Codex agent TOML file.
codex_body() {
  local file="$1"

  perl -0e '
    use Encode qw(encode);

    my $text = <>;
    my ($encoded_body) = $text =~ /^[ \t]*developer_instructions[ \t]*=[ \t]*"""\r?\n(.*?)^"""/ms;
    die "Missing developer_instructions multiline string\n" unless defined $encoded_body;

    my $decoded_body = "";
    while (length $encoded_body) {
      my $character = substr($encoded_body, 0, 1, "");
      if ($character ne "\\") {
        $decoded_body .= $character;
        next;
      }

      die "Invalid TOML escape at end of developer_instructions\n" unless length $encoded_body;
      my $escape = substr($encoded_body, 0, 1, "");
      if ($escape eq "\\") {
        $decoded_body .= "\\";
      } elsif ($escape eq "\"") {
        $decoded_body .= "\"";
      } elsif ($escape eq "b") {
        $decoded_body .= "\b";
      } elsif ($escape eq "f") {
        $decoded_body .= "\f";
      } elsif ($escape eq "n") {
        $decoded_body .= "\n";
      } elsif ($escape eq "r") {
        $decoded_body .= "\r";
      } elsif ($escape eq "t") {
        $decoded_body .= "\t";
      } elsif ($escape eq "u" || $escape eq "U") {
        my $hex_length = $escape eq "u" ? 4 : 8;
        die "Invalid TOML Unicode escape in developer_instructions\n"
          unless $encoded_body =~ s/\A([0-9A-Fa-f]{$hex_length})//;
        $decoded_body .= encode("UTF-8", chr(hex($1)));
      } else {
        die "Unsupported TOML escape in developer_instructions: $escape\n";
      }
    }

    print $decoded_body;
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
  local body_dir=""

  body_dir="$(mktemp -d)"

  while IFS= read -r ref_file; do
    rel="${ref_file#"$ref_dir"/}"

    other="$other_root_a/$subdir/$rel"
    if [[ ! -f "$other" ]]; then
      printf 'FAIL: %s not present in %s (missing shared file)\n' "$rel" "$other" >&2
      failures=$((failures + 1))
    else
      md_body "$ref_file" >"$body_dir/reference"
      md_body "$other" >"$body_dir/other"
      if ! cmp -s "$body_dir/reference" "$body_dir/other"; then
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
      if ! codex_body "$other" >"$body_dir/codex"; then
        printf 'FAIL: could not decode Codex body for %s\n  file: %s\n' \
          "$rel" "$other" >&2
        failures=$((failures + 1))
      elif ! cmp -s "$body_dir/reference" "$body_dir/codex"; then
        printf 'FAIL: body drift for %s\n  reference: %s\n  drift:     %s\n' \
          "$rel" "$ref_file" "$other" >&2
        failures=$((failures + 1))
      fi
    elif ! cmp -s "$body_dir/reference" "$body_dir/other"; then
      printf 'FAIL: body drift for %s\n  reference: %s\n  drift:     %s\n' \
        "$rel" "$ref_file" "$other" >&2
      failures=$((failures + 1))
    fi
  done < <(find "$ref_dir" -type f -name '*.md' | sort)

  rm -rf "$body_dir"
}

check_parity "$CLAUDE_TREE" "$OPENCODE_TREE" "$CODEX_TREE" "agents"
check_parity "$CLAUDE_TREE" "$OPENCODE_TREE" "$CODEX_TREE" "skills"

if [[ "$failures" -ne 0 ]]; then
  printf 'Body parity check FAILED with %d drift(s).\n' "$failures" >&2
  exit 1
fi

printf 'Body parity check passed for shared agents and skills.\n'

neg_dir="$(mktemp -d)"
trap 'rm -rf "$neg_dir"' EXIT

# -----------------------------------------------------------------------------
# Positive fixture: parity must decode the escapes used by the generated Codex
# multiline basic string without losing carriage returns or trailing newlines.
# -----------------------------------------------------------------------------

complex_ref="$neg_dir/complex-ref/.claude"
complex_opencode="$neg_dir/complex-opencode"
complex_codex="$neg_dir/complex-codex"

mkdir -p "$complex_ref/agents" "$complex_opencode/agents" "$complex_codex/agents"

for complex_file in "$complex_ref/agents/escaped-body.md" "$complex_opencode/agents/escaped-body.md"; do
  {
    printf '%s\n' '---'
    printf '%s\n' 'name: escaped-body'
    printf '%s\n' 'description: escaped body fixture'
    printf '%s\n' '---'
    printf '\n%s\n' 'literal \path'
    printf '%s' 'carriage' $'\r' 'return' $'\n'
    printf '%s\n' 'quote """'
    printf '%s\n' ''
  } >"$complex_file"
done

{
  printf '%s\n' 'name = "escaped-body"'
  printf '%s\n' 'description = "escaped body fixture"'
  printf '%s\n' 'model = "test-model"'
  printf '%s\n' 'developer_instructions = """'
  printf '%s\n' ''
  printf '%s\n' 'literal \\path'
  printf '%s\n' 'carriage\rreturn'
  printf '%s\n' 'quote \"""'
  printf '%s\n' ''
  printf '%s\n' '"""'
} >"$complex_codex/agents/escaped-body.toml"

failures=0
check_parity "$complex_ref" "$complex_opencode" "$complex_codex" "agents"
if [[ "$failures" -ne 0 ]]; then
  printf 'FAIL: Codex escaped-body fixture did not round-trip (%d drift(s)).\n' "$failures" >&2
  exit 1
fi
printf 'Codex escaped-body parity fixture passed.\n'

# -----------------------------------------------------------------------------
# Negative test: the check above must actually catch drift. Build a trio of temp
# trees where one shared agent body is deliberately drifted, then assert the full
# parity check FAILS.
# -----------------------------------------------------------------------------

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

cat >"$neg_ref/agents/invalid-body.md" <<'EOF'
---
name: invalid-body
description: invalid decoder fixture
---
decoder failure must not be reported as body drift
EOF
cp -a "$neg_ref/agents/invalid-body.md" "$neg_opencode/agents/invalid-body.md"
cat >"$neg_codex/agents/invalid-body.toml" <<'EOF'
name = "invalid-body"
description = "invalid decoder fixture"
model = "test-model"
EOF

printf '%s\n' 'skill body' >"$neg_ref/skills/trailing-newline.md"
cp -a "$neg_ref/skills/trailing-newline.md" "$neg_codex/skills/trailing-newline.md"
printf '%s\n\n' 'skill body' >"$neg_opencode/skills/trailing-newline.md"

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

failures=0
check_parity "$neg_ref" "$neg_opencode" "$neg_codex" "skills"
skill_neg_failures="$failures"
if [[ "$skill_neg_failures" -eq 0 ]]; then
  printf 'FAIL: negative skill test did not detect the deliberate trailing-newline drift\n' >&2
  exit 1
fi

printf 'Negative test confirmed: parity check detects trailing-newline drift (%d drift(s) flagged).\n' "$skill_neg_failures"
printf 'Parity checks passed.\n'
