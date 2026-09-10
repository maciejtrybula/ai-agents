#!/usr/bin/env bash
# Wire test for the session-handoff auto-wiring in sync-local-agents.sh.
#
# Core assertions:
#   (a) --dry-run makes NO changes to settings.json / opencode.json / config.toml
#       and creates no .bak-* backups and no materialized skill files.
#   (b) A real run creates .bak-<ts> backups of pre-existing files before
#       mutating, and the hooks/plugin entry land.
#   (c) --no-wire still materializes the skill files but skips all settings
#       mutation.
#   (d) Idempotency: running the sync twice yields the same hooks/plugin entry
#       (no duplicates).
#   (e) Unrelated existing keys in settings.json and in the plugin array
#       survive.
#   (f) Codex needs no config wiring: config.toml is never created/mutated by
#       the skills sync (codex loads the skill from .agents/skills).
#
# The test is hermetic: SYNC_RSYNC points at an in-test mock rsync (a real
# recursive copy for apply runs, a listing for dry runs), so the assertions do
# not depend on rsync being installed.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

assert_file_contains() {
  local file_path="$1"
  local needle="$2"

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

  if grep -Fq "$needle" "$file_path"; then
    printf 'Expected %s to NOT contain: %s\n' "$file_path" "$needle" >&2
    printf 'Actual contents:\n' >&2
    cat "$file_path" >&2
    exit 1
  fi
}

assert_no_backups_under() { # a dry run must not leave any .bak-* files
  local base="$1"
  if find "$base" -name '*.bak-*' -print 2>/dev/null | grep -q .; then
    printf 'Expected no backups under %s on a dry run\n' "$base" >&2
    find "$base" -name '*.bak-*' >&2
    exit 1
  fi
}

tmp="$(mktemp -d)"
mock_rsync="$tmp/mock-rsync"
sync_home="$tmp/home"
target_dir="$tmp/target"
baseline="$tmp/baseline"

cleanup() {
  rm -rf "$tmp"
  # The Codex repo-root mirror is materialized into the real repo by the skills
  # sync; remove it so the test leaves no repo-side artifacts.
  rm -rf "$repo_root/.agents/skills"
}
trap cleanup EXIT

# A stale mirror from an interrupted earlier run would skew assertions.
rm -rf "$repo_root/.agents/skills"
mkdir -p "$sync_home" "$target_dir" "$baseline"

# --- in-test mock rsync: real copy on apply, listing on dry-run ----------------
cat >"$mock_rsync" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
dry=false
pos=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry=true; shift;;
    -a|-av|-v|-r|-q|-e|--delete) shift;;
    -*) shift;;
    *) pos+=("$1"); shift;;
  esac
done
[ ${#pos[@]} -ge 2 ] || exit 1
src="${pos[0]}"
dst="${pos[1]}"
if [ "$dry" = true ]; then
  if [ -d "$src" ]; then
    find "$src" -type f | sed "s#^$src/##" | sort
  elif [ -f "$src" ]; then
    printf '%s\n' "$(basename "$src")"
  fi
  exit 0
fi
if [ -d "$src" ]; then
  mkdir -p "$dst"
  cp -a "$src"/. "$dst"/
else
  mkdir -p "$(dirname "$dst")"
  cp -a "$src" "$dst"
fi
exit 0
EOF
chmod +x "$mock_rsync"

export SYNC_RSYNC="$mock_rsync"
export HOME="$sync_home"

# --- baseline state ------------------------------------------------------------
claude_settings="$target_dir/.claude/settings.json"
opencode_config="$target_dir/.config/opencode/opencode.json"
codex_config="$target_dir/.codex/config.toml"

mkdir -p "$(dirname "$claude_settings")" "$(dirname "$opencode_config")" "$(dirname "$codex_config")"

cat >"$claude_settings" <<'EOF'
{
  "model": "opus",
  "_disabledHooks": {
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "node /tmp/local-only-hook.mjs"
          }
        ]
      }
    ]
  }
}
EOF
cp "$claude_settings" "$baseline/claude-settings.json"

cat >"$opencode_config" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": [
    "superpowers@git+https://github.com/obra/superpowers.git",
    "@dietrichgebert/ponytail",
    "./plugins/caveman/plugin.js"
  ],
  "model": "openai/gpt-5.6-luna"
}
EOF
cp "$opencode_config" "$baseline/opencode.json"

cat >"$codex_config" <<'EOF'
model = "gpt-5.3-codex"
default_permissions = "repo-workspace"
EOF
cp "$codex_config" "$baseline/config.toml"

# --- (a) --dry-run makes no changes -------------------------------------------
bash "$repo_root/sync-local-agents.sh" --dry-run --sync skills \
  --platform claude --platform opencode --platform codex \
  --target-dir "$target_dir" >"$tmp/dry.out" 2>&1

if ! diff -q "$claude_settings" "$baseline/claude-settings.json" >/dev/null; then
  printf 'FAIL: dry run mutated Claude settings.json\n' >&2
  exit 1
fi
if ! diff -q "$opencode_config" "$baseline/opencode.json" >/dev/null; then
  printf 'FAIL: dry run mutated opencode.json\n' >&2
  exit 1
fi
if ! diff -q "$codex_config" "$baseline/config.toml" >/dev/null; then
  printf 'FAIL: dry run mutated config.toml\n' >&2
  exit 1
fi
assert_no_backups_under "$target_dir"
assert_no_backups_under "$sync_home"
if find "$target_dir" -type f -path '*session-handoff*' -print 2>/dev/null | grep -q .; then
  printf 'FAIL: dry run materialized skill files\n' >&2
  exit 1
fi
if [[ -e "$repo_root/.agents/skills/session-handoff/SKILL.md" ]]; then
  printf 'FAIL: dry run materialized the repo-root codex mirror\n' >&2
  exit 1
fi
grep -Fq '# would wire hooks into' "$tmp/dry.out" || {
  printf 'FAIL: dry run missing would-wire-hooks preview\n' >&2
  exit 1
}
printf 'ok: --dry-run makes no changes and no backups\n'

# --- (b) real run backs up + wires --------------------------------------------
bash "$repo_root/sync-local-agents.sh" --sync skills \
  --platform claude --platform opencode --platform codex \
  --target-dir "$target_dir" >"$tmp/real.out" 2>&1

assert_file_contains "$claude_settings" '"hooks"'
assert_file_contains "$claude_settings" 'context-prompt-hook.sh'
assert_file_contains "$claude_settings" 'context-precompact-hook.sh'
assert_file_contains "$opencode_config" '"./skills/session-handoff/bin/opencode-plugin.js"'
assert_file_contains "$target_dir/.claude/skills/session-handoff/SKILL.md" 'session-handoff'
assert_file_contains "$target_dir/.config/opencode/skills/session-handoff/SKILL.md" 'session-handoff'
assert_file_contains "$target_dir/.codex/skills/session-handoff/SKILL.md" 'session-handoff'
assert_file_contains "$repo_root/.agents/skills/session-handoff/SKILL.md" 'session-handoff'
assert_file_contains "$sync_home/.agents/skills/session-handoff/SKILL.md" 'session-handoff'

claude_backups="$(find "$target_dir/.claude" -maxdepth 1 -name 'settings.json.bak-*' | wc -l)"
if [[ "$claude_backups" -lt 1 ]]; then
  printf 'FAIL: real run did not back up Claude settings.json before mutating\n' >&2
  exit 1
fi
opencode_backups="$(find "$target_dir/.config/opencode" -maxdepth 1 -name 'opencode.json.bak-*' | wc -l)"
if [[ "$opencode_backups" -lt 1 ]]; then
  printf 'FAIL: real run did not back up opencode.json before mutating\n' >&2
  exit 1
fi
printf 'ok: real run creates backups and wires hooks + plugin\n'

# --- (c) --no-wire skips settings mutation but still materializes --------------
rm -rf "$target_dir" "$sync_home"
mkdir -p "$sync_home" "$target_dir"
mkdir -p "$(dirname "$claude_settings")" "$(dirname "$opencode_config")" "$(dirname "$codex_config")"
cp "$baseline/claude-settings.json" "$claude_settings"
cp "$baseline/opencode.json" "$opencode_config"
cp "$baseline/config.toml" "$codex_config"

bash "$repo_root/sync-local-agents.sh" --sync skills \
  --platform claude --platform opencode \
  --target-dir "$target_dir" --no-wire >"$tmp/nowire.out" 2>&1

assert_file_contains "$target_dir/.claude/skills/session-handoff/SKILL.md" 'session-handoff'
assert_file_contains "$target_dir/.config/opencode/skills/session-handoff/SKILL.md" 'session-handoff'
assert_file_not_contains "$claude_settings" 'UserPromptSubmit'
assert_file_not_contains "$claude_settings" 'PreCompact'
assert_file_not_contains "$opencode_config" 'opencode-plugin.js'
assert_no_backups_under "$target_dir"
printf 'ok: --no-wire materializes skills but skips settings mutation\n'

# --- (d) idempotency: two runs produce the same hooks/plugin (no duplicates) --
bash "$repo_root/sync-local-agents.sh" --sync skills \
  --platform claude --platform opencode \
  --target-dir "$target_dir" >/dev/null 2>&1
bash "$repo_root/sync-local-agents.sh" --sync skills \
  --platform claude --platform opencode \
  --target-dir "$target_dir" >/dev/null 2>&1

prompt_hook_count="$(grep -c 'context-prompt-hook.sh' "$claude_settings" || true)"
precompact_hook_count="$(grep -c 'context-precompact-hook.sh' "$claude_settings" || true)"
plugin_count="$(grep -c 'opencode-plugin.js' "$opencode_config" || true)"
if [[ "$prompt_hook_count" -ne 1 || "$precompact_hook_count" -ne 1 ]]; then
  printf 'FAIL: duplicate Claude hooks after two runs (prompt=%s precompact=%s)\n' \
    "$prompt_hook_count" "$precompact_hook_count" >&2
  exit 1
fi
if [[ "$plugin_count" -ne 1 ]]; then
  printf 'FAIL: duplicate opencode plugin entry after two runs (count=%s)\n' "$plugin_count" >&2
  exit 1
fi
printf 'ok: second run is idempotent (no duplicate hooks/plugin)\n'

# --- (e) unrelated keys survive ------------------------------------------------
assert_file_contains "$claude_settings" '"_disabledHooks"'
assert_file_contains "$claude_settings" 'node /tmp/local-only-hook.mjs'
assert_file_contains "$claude_settings" '"model": "opus"'
assert_file_contains "$opencode_config" 'superpowers@git+https://github.com/obra/superpowers.git'
assert_file_contains "$opencode_config" '@dietrichgebert/ponytail'
assert_file_contains "$opencode_config" '"./plugins/caveman/plugin.js"'
printf 'ok: unrelated settings keys and plugin entries survive\n'

# --- (f) codex: no config.toml wiring -----------------------------------------
bash "$repo_root/sync-local-agents.sh" --sync skills \
  --platform codex \
  --target-dir "$target_dir" >/dev/null 2>&1
if ! diff -q "$codex_config" "$baseline/config.toml" >/dev/null; then
  printf 'FAIL: codex skills sync mutated config.toml\n' >&2
  exit 1
fi
assert_file_contains "$repo_root/.agents/skills/session-handoff/SKILL.md" 'session-handoff'
printf 'ok: codex needs no config.toml wiring\n'

printf '\nAll session-handoff wiring checks passed.\n'
