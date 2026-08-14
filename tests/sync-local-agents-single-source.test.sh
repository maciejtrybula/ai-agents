#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

assert_file_contains() {
  local file_path="$1"
  local needle="$2"

  if [[ ! -f "$file_path" ]]; then
    printf 'Expected file to exist: %s\n' "$file_path" >&2
    exit 1
  fi

  if ! grep -Fq "$needle" "$file_path"; then
    printf 'Expected %s to contain: %s\n' "$file_path" "$needle" >&2
    printf 'Actual contents:\n' >&2
    cat "$file_path" >&2
    exit 1
  fi
}

assert_file_not_contains() {
  local file_path="$1"
  local needle="$2"

  if [[ ! -f "$file_path" ]]; then
    printf 'Expected file to exist: %s\n' "$file_path" >&2
    exit 1
  fi

  if grep -Fq "$needle" "$file_path"; then
    printf 'Expected %s to not contain: %s\n' "$file_path" "$needle" >&2
    printf 'Actual contents:\n' >&2
    cat "$file_path" >&2
    exit 1
  fi
}

body_marker="You are Task Master: a senior technical program lead and hands-on engineering coordinator."

# --- Default run writes the generated files into the repo staging dirs ---
if [[ ! -x "$repo_root/generate-agents.sh" ]]; then
  printf 'Missing generator at %s/generate-agents.sh — run tests/sync-local-agents-single-source.test.sh after creating it\n' "$repo_root" >&2
  exit 1
fi

bash "$repo_root/generate-agents.sh"

# Canonical body marker present in all 3 generated platform files.
assert_file_contains "$repo_root/.claude/agents/it-task-master.md" "$body_marker"
assert_file_contains "$repo_root/.codex/agents/it-task-master.md" "$body_marker"
assert_file_contains "$repo_root/.config/opencode/agents/it-task-master.md" "$body_marker"

# Shared frontmatter `name` present in all 3.
for file in \
  "$repo_root/.claude/agents/it-task-master.md" \
  "$repo_root/.codex/agents/it-task-master.md" \
  "$repo_root/.config/opencode/agents/it-task-master.md"; do
  assert_file_contains "$file" "name: it-task-master"
done

# Shared `color` present in Claude and Codex, but NOT in OpenCode (its
# platform convention omits the color line).
assert_file_contains "$repo_root/.claude/agents/it-task-master.md" "color: orange"
assert_file_contains "$repo_root/.codex/agents/it-task-master.md" "color: orange"

# Per-platform model present.
assert_file_contains "$repo_root/.claude/agents/it-task-master.md" "model: sonnet"
assert_file_contains "$repo_root/.codex/agents/it-task-master.md" "model: openai/gpt"
assert_file_contains "$repo_root/.config/opencode/agents/it-task-master.md" "model: openai/gpt"

# Per-platform temperature present (from platform config) in Codex and
# OpenCode, but NOT in Claude (no temperature defined for Claude).
assert_file_contains "$repo_root/.codex/agents/it-task-master.md" "temperature: 0.4"
assert_file_contains "$repo_root/.config/opencode/agents/it-task-master.md" "temperature: 0.4"
assert_file_not_contains "$repo_root/.claude/agents/it-task-master.md" "temperature:"

# OpenCode convention: no `color` line.
assert_file_not_contains "$repo_root/.config/opencode/agents/it-task-master.md" "color:"

# --- Full migration: all shared agents materialize on every platform ---
# Shared agents = every canonical .agents/*.md except README.md and the
# it-task-master pilot. native-mobile-engineer is now shared (no `platforms:`
# restriction) so it participates in the all-platforms parity assertions.
# Compute the slug list dynamically so it stays in sync as agents are added.
shared_agent_slugs=()
for canonical in "$repo_root"/.agents/*.md; do
  slug="$(basename "$canonical" .md)"
  case "$slug" in
    README|it-task-master) continue ;;
  esac
  shared_agent_slugs+=("$slug")
done

if [[ "${#shared_agent_slugs[@]}" -eq 0 ]]; then
  printf 'No shared agents found under %s/.agents — cannot verify parity\n' "$repo_root" >&2
  exit 1
fi

for slug in "${shared_agent_slugs[@]}"; do
  # Derive the expected `name:` from the canonical frontmatter (not the
  # filename slug — e.g. secops-auditor.md declares `name: secops-security-auditor`).
  expected_name="$(grep -m1 '^name:' "$repo_root/.agents/$slug.md" | sed 's/^name:[[:space:]]*//')"
  if [[ -z "$expected_name" ]]; then
    printf 'No `name:` frontmatter in %s/.agents/%s.md\n' "$repo_root" "$slug" >&2
    exit 1
  fi
  for dir in \
    "$repo_root/.claude/agents" \
    "$repo_root/.codex/agents" \
    "$repo_root/.config/opencode/agents"; do
    assert_file_contains "$dir/$slug.md" "name: $expected_name"
    assert_file_contains "$dir/$slug.md" "model:"
  done
done

# Per-agent model overrides.
assert_file_contains "$repo_root/.claude/agents/backend-architect.md" "model: opus"
assert_file_contains "$repo_root/.config/opencode/agents/backend-architect.md" "model: openai/gpt-5.6-sol"
assert_file_contains "$repo_root/.codex/agents/backend-architect.md" "model: openai/gpt-5.3-codex"

# A default-model agent still gets the platform default: devops-engineer has
# no claude override, so it falls back to the claude default `sonnet`.
assert_file_contains "$repo_root/.claude/agents/devops-engineer.md" "model: sonnet"
# content-writer has no codex model override, so it falls back to the codex
# default `openai/gpt-5.4`.
assert_file_contains "$repo_root/.codex/agents/content-writer.md" "model: openai/gpt-5.4"

# ux-ui-architect claude override.
assert_file_contains "$repo_root/.claude/agents/ux-ui-architect.md" "model: opus"

# native-mobile-engineer is now shared: emitted to all three dirs with its
# canonical `name:`.
assert_file_contains "$repo_root/.claude/agents/native-mobile-engineer.md" "name: native-mobile-engineer"
assert_file_contains "$repo_root/.codex/agents/native-mobile-engineer.md" "name: native-mobile-engineer"
assert_file_contains "$repo_root/.config/opencode/agents/native-mobile-engineer.md" "name: native-mobile-engineer"

# backend-engineer uses the short canonical description on ALL platforms
# (no per-platform description override remains in agent-platforms.json).
for dir in \
  "$repo_root/.claude/agents" \
  "$repo_root/.codex/agents" \
  "$repo_root/.config/opencode/agents"; do
  assert_file_contains "$dir/backend-engineer.md" "Handles code implementation, refactoring, test writing"
  assert_file_not_contains "$dir/backend-engineer.md" "Examples:"
done

# mode/permission survival: native-mobile-engineer carries both, copied
# verbatim into the claude, codex, and opencode generated outputs.
for dir in \
  "$repo_root/.claude/agents" \
  "$repo_root/.codex/agents" \
  "$repo_root/.config/opencode/agents"; do
  assert_file_contains "$dir/native-mobile-engineer.md" "mode: subagent"
  assert_file_contains "$dir/native-mobile-engineer.md" "permission:"
done

# --- --target-dir writes into a custom destination ---
target_dir="$(mktemp -d)"
trap 'rm -rf "$target_dir"' EXIT

bash "$repo_root/generate-agents.sh" --target-dir "$target_dir"

assert_file_contains "$target_dir/.claude/agents/it-task-master.md" "$body_marker"
assert_file_contains "$target_dir/.codex/agents/it-task-master.md" "$body_marker"
assert_file_contains "$target_dir/.opencode/agents/it-task-master.md" "$body_marker"

assert_file_contains "$target_dir/.claude/agents/it-task-master.md" "name: it-task-master"
assert_file_contains "$target_dir/.claude/agents/it-task-master.md" "color: orange"
assert_file_contains "$target_dir/.claude/agents/it-task-master.md" "model: sonnet"
assert_file_contains "$target_dir/.codex/agents/it-task-master.md" "model: openai/gpt"
assert_file_contains "$target_dir/.opencode/agents/it-task-master.md" "model: openai/gpt"
assert_file_not_contains "$target_dir/.opencode/agents/it-task-master.md" "color:"

# Per-platform temperature also present in the --target-dir output.
assert_file_contains "$target_dir/.codex/agents/it-task-master.md" "temperature: 0.4"
assert_file_contains "$target_dir/.opencode/agents/it-task-master.md" "temperature: 0.4"
assert_file_not_contains "$target_dir/.claude/agents/it-task-master.md" "temperature:"

# --- sync-local-agents.sh --target-dir writes into a custom destination ---
# (agents scope, claude platform; verify the custom path receives files and a
#  sandboxed $HOME receives none)
sync_target_dir="$(mktemp -d)"
sync_home="$(mktemp -d)"
sync_cleanup() {
  rm -rf "$sync_target_dir" "$sync_home"
}
trap 'sync_cleanup' EXIT

HOME="$sync_home" bash "$repo_root/sync-local-agents.sh" \
  --sync agents --platform claude --target-dir "$sync_target_dir" >/dev/null 2>&1

assert_file_contains "$sync_target_dir/.claude/agents/it-task-master.md" "$body_marker"
assert_file_contains "$sync_target_dir/.claude/agents/it-task-master.md" "name: it-task-master"
assert_file_contains "$sync_target_dir/.claude/agents/it-task-master.md" "color: orange"
assert_file_contains "$sync_target_dir/.claude/agents/it-task-master.md" "model: sonnet"

# Nothing should be written under the sandboxed $HOME.
if find "$sync_home" -type f -name '*.md' 2>/dev/null | grep -q .; then
  printf 'Expected no agent files under sandboxed $HOME with --target-dir\n' >&2
  exit 1
fi

# --- Fresh-checkout resilience: sync auto-materializes missing sources ---
# The generated agent dirs are git-ignored, so a user can run sync-local-agents.sh
# before ever running generate-agents.sh. It must materialize the sources itself
# rather than silently copying nothing.
fresh_cleanup() {
  rm -rf "$repo_root/.claude/agents" "$repo_root/.codex/agents" "$repo_root/.config/opencode/agents"
  "$repo_root/generate-agents.sh" >/dev/null 2>&1
}
trap 'fresh_cleanup' EXIT

# Simulate a fresh checkout: drop the generated source dirs.
rm -rf "$repo_root/.claude/agents" "$repo_root/.codex/agents" "$repo_root/.config/opencode/agents"

fresh_target_dir="$(mktemp -d)"
fresh_home="$(mktemp -d)"
HOME="$fresh_home" bash "$repo_root/sync-local-agents.sh" \
  --sync agents --platform claude --target-dir "$fresh_target_dir" >/dev/null 2>&1

# All agents must reach the custom path even though the source dirs were absent.
assert_file_contains "$fresh_target_dir/.claude/agents/it-task-master.md" "$body_marker"
assert_file_contains "$fresh_target_dir/.claude/agents/it-task-master.md" "name: it-task-master"
assert_file_contains "$fresh_target_dir/.claude/agents/it-task-master.md" "model: sonnet"
# The missing source dirs are regenerated in the repo so they can be reused.
if [[ ! -d "$repo_root/.claude/agents" ]]; then
  printf 'Expected sync-local-agents.sh to regenerate missing .claude/agents\n' >&2
  exit 1
fi

fresh_cleanup

# --- Model-override precedence: explicit platform model wins over the per-agent
#     repo_default (opencode/it-task-master -> claude-sonnet-4.6) ---
precedence_target_dir="$(mktemp -d)"
precedence_home="$(mktemp -d)"
precedence_cleanup() {
  rm -rf "$precedence_target_dir" "$precedence_home"
}
trap 'precedence_cleanup' EXIT

# 1. Explicit --opencode-model must win for it-task-master (repo_default must
#    NOT shadow it).
HOME="$precedence_home" bash "$repo_root/sync-local-agents.sh" \
  --sync agents --platform opencode --target-dir "$precedence_target_dir" \
  --opencode-model github-copilot/gpt-5.6-luna >/dev/null 2>&1
assert_file_contains "$precedence_target_dir/.opencode/agents/it-task-master.md" "model: github-copilot/gpt-5.6-luna"
assert_file_not_contains "$precedence_target_dir/.opencode/agents/it-task-master.md" "model: github-copilot/claude-sonnet-4.6"

# 2. With no explicit platform model, the repo_default fallback still applies
#    for opencode/it-task-master.
precedence_target_dir_nod="$(mktemp -d)"
precedence_home_nod="$(mktemp -d)"
precedence_cleanup_nod() {
  rm -rf "$precedence_target_dir_nod" "$precedence_home_nod"
}
trap 'precedence_cleanup_nod' EXIT

HOME="$precedence_home_nod" bash "$repo_root/sync-local-agents.sh" \
  --sync agents --platform opencode --target-dir "$precedence_target_dir_nod" >/dev/null 2>&1
assert_file_contains "$precedence_target_dir_nod/.opencode/agents/it-task-master.md" "model: github-copilot/claude-sonnet-4.6"

printf 'Single-source agent generation checks passed.\n'
