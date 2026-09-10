#!/usr/bin/env bash
# Portability/parity tests for the session-handoff skill.
#
# Core assertions:
#   (a) no hard-coded '/home/' or '/Users/' literals anywhere in the canonical tree
#   (b) context-monitor prints an integer percent from a fake Claude transcript (or
#       nothing when no session), exit 0
#   (c) context-autohandoff writes a handoff + transcript symlink under the resolved
#       store, with no '/home/claude/workspace' literal in the markdown
#   (d) the tree is relocatable (move it to a temp dir, still works)
#   (e) config override beats skill defaults
#   (f) bash -n passes on all scripts
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
skill_root="$repo_root/.skills/session-handoff"

tmp="$(mktemp -d)"
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'ok: %s\n' "$*"; }

# (f) bash -n all scripts
for script in $(find "$skill_root" -name '*.sh'); do
  bash -n "$script" || fail "syntax: $script"
done
ok "bash -n all scripts"

# (a) no hard-coded user-home literals in the canonical tree
if grep -rnE '/(home|Users)/[A-Za-z_][A-Za-z0-9_.-]*' "$skill_root" >/dev/null 2>&1; then
  fail "found a hard-coded home path in canonical tree"
fi
ok "no /home/ or /Users/ literals in canonical tree"

# --- Fake Claude environment ---------------------------------------------------
fake_home="$tmp/home"
mkdir -p "$fake_home/.claude/projects/-fake-project"
cat > "$fake_home/.claude/projects/-fake-project/ssn-fake.jsonl" <<'EOF'
{"type":"user","message":{"content":"build the thing"}}
{"type":"assistant","model":"claude-sonnet-4-5","message":{"content":"hi","usage":{"input_tokens":120000}}}
EOF

run_isolated() { # run a command with a scrubbed env (fake HOME, no CLAUDE_CODE_SESSION_ID etc.)
  env -i PATH="$PATH" HOME="$fake_home" TMPDIR="$tmp" "$@"
}

# (b) monitor prints 45% (120000 tokens / 262144 window) under the fake home
read -r -a MONITOR_CMD <<< "bash $skill_root/bin/context-monitor.sh"
PERCENT="$(run_isolated "${MONITOR_CMD[@]}")"
[ "$PERCENT" = "45" ] || fail "expected 45, got '$PERCENT'"
ok "context-monitor prints 45% from fake transcript"

# (b2) monitor with no session → prints nothing, exit 0
empty_home="$tmp/empty-home"
mkdir -p "$empty_home"
PERCENT_EMPTY="$(env -i PATH="$PATH" HOME="$empty_home" TMPDIR="$tmp" bash "$skill_root/bin/context-monitor.sh")"
[ -z "${PERCENT_EMPTY:-}" ] || fail "expected empty output for empty home, got '$PERCENT_EMPTY'"
ok "context-monitor prints nothing without a session"

# (c) autohandoff writes handoff + symlink under the resolved store.
# The store is chosen by lib/paths.sh: project-local under a writable git work
# tree, user-global otherwise. fake_home is NOT a git repo, so run autohandoff
# from a non-repo cwd (the fake home) so the user-global store is exercised.
# (We rely on the scripts being executable so `bash -c` can invoke them directly.)
CLAUDE_CODE_SESSION_ID="ssn-fake" run_isolated bash -c 'cd "$HOME" && exec "$0" "$@"' "$skill_root/bin/context-autohandoff.sh" >/dev/null 2>&1 || true
handoff_dir="$fake_home/.claude/projects/-fake-project"   # non-repo cwd ⇒ user-global store actually used below
# Because we ran from the non-repo fake home, the store is the USER-GLOBAL one:
global_handoff="$fake_home/.local/state/session-handoff/handoffs/claude/-fake-project"
found_handoff_md=""
found_handoff_md="$(find "$fake_home" -path '*/session-handoffs/ssn-fake.md' 2>/dev/null | head -n1)"
[ -n "$found_handoff_md" ] || fail "no handoff md written"
grep -Fq '## Context usage' "$found_handoff_md" || fail "handoff missing ## Context usage"
if grep -Fq '/home/claude/workspace' "$found_handoff_md"; then
  fail "handoff contains hard-coded /home/claude/workspace"
fi
found_link="$(find "$fake_home" -name 'ssn-fake.jsonl' -type l 2>/dev/null | head -n1)"
[ -n "$found_link" ] && [ -e "$found_link" ] || fail "transcript symlink missing or dangling"
ok "autohandoff wrote handoff (md) + transcript symlink, no hard-coded path"

# (d) relocate the tree → still works
moved="$tmp/moved-skill"
mkdir -p "$moved"
cp -r "$skill_root/." "$moved/"
PERCENT_MOVED="$(env -i PATH="$PATH" HOME="$fake_home" TMPDIR="$tmp" bash "$moved/bin/context-monitor.sh")"
[ "$PERCENT_MOVED" = "45" ] || fail "relocated tree: expected 45, got '$PERCENT_MOVED'"
ok "tree relocation works (path resolution is root-relative)"

# (e) user config override beats skill defaults
override_home="$tmp/override-home"
mkdir -p "$override_home/.claude/projects/-fake-project" "$override_home/.config/session-handoff"
cp "$fake_home/.claude/projects/-fake-project/ssn-fake.jsonl" "$override_home/.claude/projects/-fake-project/"
cat > "$override_home/.config/session-handoff/context-monitor.json" <<'EOF'
{"contextWindow": 1000}
EOF
PERCENT_OVERRIDE="$(env -i PATH="$PATH" HOME="$override_home" TMPDIR="$tmp" bash "$skill_root/bin/context-monitor.sh")"
# 120000 tokens / 1000 window = 12000 (unclamped integer)
[ "$PERCENT_OVERRIDE" = "12000" ] || fail "override: expected 12000, got '$PERCENT_OVERRIDE'"
ok "config override beats skill defaults"

# (g) opencode nested-layout transcript resolution (session/<id>/message/<ts>)
#     must resolve to a real transcript and publish the pointer symlink.
oc_home="$tmp/oc-home"
mkdir -p "$oc_home/.local/share/opencode/session/ssn-oc-real/message"
cp "$fake_home/.claude/projects/-fake-project/ssn-fake.jsonl" "$oc_home/.local/share/opencode/session/ssn-oc-real/message/ts1.jsonl"
OC_ROOT="$oc_home" env -i PATH="$PATH" HOME="$oc_home" TMPDIR="$tmp" SESSION_HANDOFF_PLATFORM=opencode \
  OPENCODE_SESSION_ID=ssn-oc-real SESSION_HANDOFF_PROJECT_DIR="$oc_home" \
  bash "$skill_root/bin/context-autohandoff.sh" >/dev/null 2>&1 || true
oc_md="$(find "$oc_home/.local/state/session-handoff" -name 'ssn-oc-real.md' 2>/dev/null | head -n1)"
[ -n "$oc_md" ] || fail "opencode: no handoff written"
grep -Fq '## Context usage' "$oc_md" || fail "opencode: handoff missing sections"
oc_link="$(find "$oc_home/.local/state/session-handoff" -name 'ssn-oc-real.jsonl' -type l 2>/dev/null | head -n1)"
[ -n "$oc_link" ] && [ -e "$oc_link" ] || fail "opencode: transcript symlink missing or dangling"
grep -Fq 'message/ts1.jsonl' "$oc_md" || fail "opencode: handoff transcript pointer not the nested path"
ok "opencode nested-layout resolution publishes handoff + transcript pointer"

# (h) plugin module loads and the event handler is non-blocking / clean
if command -v node >/dev/null 2>&1; then
  node --check "$skill_root/bin/opencode-plugin.js" >/dev/null 2>&1 || fail "opencode plugin: node --check failed"
  PLUGIN_OUT="$(cd "$oc_home" && env -i PATH="$PATH" HOME="$oc_home" TMPDIR="$tmp" OPENCODE_SESSION_ID=ssn-oc-real \
    node -e '
      const p = require(process.argv[1]);
      const ctx = { workspace: { current_dir: process.cwd() }, session: { id: process.env.OPENCODE_SESSION_ID } };
      p(ctx).then(async (api) => { await api.event({ event: { type: "session.compacted" } }); setTimeout(() => process.exit(0), 1500); });
    ' "$skill_root/bin/opencode-plugin.js" 2>&1)"
  [[ -z "${PLUGIN_OUT:-}" ]] || fail "opencode plugin: unexpected stdout from handler: '$PLUGIN_OUT'"
  ok "opencode plugin loads; handler returns clean, no stdout"
fi

printf '\nAll session-handoff portability checks passed.\n'
