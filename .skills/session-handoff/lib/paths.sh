#!/usr/bin/env bash
# lib/paths.sh -- the ONLY place the session-handoff skill derives paths and
# runtime variables. Every bin/*.sh consumes these exports.
#
# Portability contract:
#   - Canonical home of the skill is platform-neutral (e.g. <repo>/.skills/session-handoff).
#     Each platform simply receives a materialized COPY of the same tree into its own
#     discovery slot (.claude/skills/, .config/opencode/skills/, .codex/skills/,
#     .agents/skills/, $HOME/.agents/skills/ ...). This lib makes every copy work
#     identically by self-locating -- NO per-agent or per-environment path script needed.
#   - Every value derives from $PWD / $HOME / XDG dirs / platform env vars /
#     stdin hook JSON. NO absolute paths are baked in anywhere.
#   - Silent on success: sourcing this file prints nothing to stdout.
#     It may write the merged config to $STATE_HOME/config/.
#   - Safe to source from any bin/ script or from a skill-body subshell:
#     `bash -c 'source lib/paths.sh; echo "$HANDOFF_ROOT"; echo "$SESSION_ID"'`
set -euo pipefail

log() { printf 'session-handoff: %s\n' "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

# --- Self-location: SKILL_ROOT -----------------------------------------------
# Sourced from within the skill tree (bin/*.sh or lib/transcript.sh); locate the
# skill root as the first ancestor of this file. BASH_SOURCE is source-safe
# (unlike $0, which is the invoking script).
_pwd_of() {
  local p="$1"
  (cd "$(dirname "$p")" 2>/dev/null && pwd) || dirname "$p"
}
SKILL_ROOT="$(_pwd_of "${BASH_SOURCE[0]}")"
while [ -n "$SKILL_ROOT" ] && [ "$SKILL_ROOT" != "/" ] && [ ! -f "$SKILL_ROOT/lib/paths.sh" ]; do
  SKILL_ROOT="$(dirname "$SKILL_ROOT")"
done
export SKILL_ROOT

# --- Captured stdin JSON (hook payloads) --------------------------------------
# Read stdin ONCE so PROJECT_DIR can derive from hook JSON and callers can
# re-use the payload (e.g. autohandoff passes it on downstream).
STDIN_JSON=""
if [ ! -t 0 ]; then
  STDIN_JSON="$(cat 2>/dev/null || true)"
fi
export STDIN_JSON

_json_project_dir() {
  python3 -c '
import sys, json
s = sys.argv[1]
try:
    d = json.loads(s)
except Exception:
    print(""); sys.exit(0)
w = d.get("workspace") or {}
v = w.get("current_dir") or d.get("cwd") or ""
print(v or "")
' "$STDIN_JSON" 2>/dev/null || true
}

# --- PROJECT_DIR / SLUG --------------------------------------------------------
PROJECT_DIR="${SESSION_HANDOFF_PROJECT_DIR:-}"
if [ -z "$PROJECT_DIR" ]; then
  PROJECT_DIR="$(_json_project_dir)"
fi
PROJECT_DIR="${PROJECT_DIR:-$PWD}"
if [ ! -d "$PROJECT_DIR" ]; then
  PROJECT_DIR="$PWD"
fi
export PROJECT_DIR

SLUG="$(printf '%s' "$PROJECT_DIR" | tr '/' '-')"
export SLUG

# --- PLATFORM detection --------------------------------------------------------
PLATFORM=""
if [ -n "${SESSION_HANDOFF_PLATFORM:-}" ]; then
  PLATFORM="$(printf '%s' "$SESSION_HANDOFF_PLATFORM" | tr '[:upper:]' '[:lower:]')"
  case "$PLATFORM" in
    claude|opencode|codex) : ;;
    *) die "invalid SESSION_HANDOFF_PLATFORM: $SESSION_HANDOFF_PLATFORM" ;;
  esac
elif [ -n "${CLAUDE_CODE_SESSION_ID:-}" ] || [ -n "${CLAUDE_CODE_ENTRYPOINT:-}" ]; then
  PLATFORM="claude"
else
  PLATFORM="claude"
fi
export PLATFORM

# --- STATE_HOME / TRANSCRIPT_ROOT ---------------------------------------------
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}/session-handoff"
export STATE_HOME

case "$PLATFORM" in
  claude)   TRANSCRIPT_ROOT="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}" ;;
  opencode) TRANSCRIPT_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/opencode" ;;
  codex)    TRANSCRIPT_ROOT="${CODEX_SESSIONS_DIR:-$HOME/.codex/sessions}" ;;
esac
export TRANSCRIPT_ROOT

# --- SESSION_ID -----------------------------------------------------------------
# Newest *.jsonl basename (without extension) under $1, guarded for missing dirs.
# Recursive: transcript trees are <slug>/<session-id>.jsonl (Claude/Codex) or
# opencode's session/<id>/message/<ts>.jsonl, never a flat *.jsonl glob.
# Portable across GNU (Linux) and BSD (macOS) find/stat.
_newest_session_id() {
  local dir="$1" out f b
  [ -d "$dir" ] || return 0
  out="$(find "$dir" -type f -name '*.jsonl' 2>/dev/null)"
  [ -n "$out" ] || return 0
  f="$(printf '%s\n' "$out" | xargs ls -t 2>/dev/null | head -n 1)" || return 0
  b="${f##*/}"
  printf '%s' "${b%.jsonl}"
}

SESSION_ID=""
case "$PLATFORM" in
  claude)
    SESSION_ID="${CLAUDE_CODE_SESSION_ID:-}"
    if [ -z "$SESSION_ID" ]; then
      SESSION_ID="$(_newest_session_id "$TRANSCRIPT_ROOT/$SLUG")"
    fi
    if [ -z "$SESSION_ID" ]; then
      SESSION_ID="$(_newest_session_id "$TRANSCRIPT_ROOT")"
    fi
    # Last-resort fallback used by the original sandbox skill.
    if [ -z "$SESSION_ID" ] && [ -f "$HOME/.claude/sessions/7.json" ]; then
      SESSION_ID="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("sessionId",""))' "$HOME/.claude/sessions/7.json" 2>/dev/null || true)"
    fi
    ;;
  opencode)
    SESSION_ID="${OPENCODE_SESSION_ID:-}"
    if [ -z "$SESSION_ID" ]; then
      # Best-effort: newest file under the session store; the id is the path
      # segment after `session/` (opencode layout: session/<id>/message/<ts>).
      local f id findout
      findout="$(find "$TRANSCRIPT_ROOT" -type f \( -name '*.jsonl' -o -name '*.json' \) 2>/dev/null)"
      [ -n "$findout" ] || break
      f="$(printf '%s\n' "$findout" | xargs ls -t 2>/dev/null | head -n 1)" || true
      if [ -n "$f" ]; then
        if [[ "$f" == *"/session/"* ]]; then
          id="${f#*/session/}"
          id="${id%%/*}"
        else
          id="$(basename "$(dirname "$f")")"
        fi
        SESSION_ID="$id"
      fi
    fi
    ;;
  codex)
    SESSION_ID="${CODEX_SESSION_ID:-${CODEX_CONVERSATION_ID:-}}"
    if [ -z "$SESSION_ID" ]; then
      SESSION_ID="$(_newest_session_id "$TRANSCRIPT_ROOT")"
    fi
    ;;
esac
export SESSION_ID

# --- HANDOFF_ROOT: project-local when in a writable git work tree, else global --
_USE_PROJECT_STORE="no"
if git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [ -d "$PROJECT_DIR/.claude" ]; then
    [ -w "$PROJECT_DIR/.claude" ] && _USE_PROJECT_STORE="yes"
  else
    [ -w "$PROJECT_DIR" ] && _USE_PROJECT_STORE="yes"
  fi
fi

if [ "$_USE_PROJECT_STORE" = "yes" ]; then
  HANDOFF_ROOT="$PROJECT_DIR/.claude/handoff/$SLUG/session-handoffs"
else
  HANDOFF_ROOT="$STATE_HOME/handoffs/$PLATFORM/$SLUG/session-handoffs"
fi
export HANDOFF_ROOT

# --- Config merge ---------------------------------------------------------------
# Precedence (later wins): skill defaults < SESSION_HANDOFF_CONFIG <
# $HOME/.config/session-handoff/context-monitor.json < <project>/.claude/session-handoff.json
CONFIG_FILE="$STATE_HOME/config/context-monitor.merged.json"

# Merge into a temp file then mv; returning file contents is avoided because
# heredoc-in-command-substitution is fragile across shells. Validation is on the
# FINAL file, so CONFIG_JSON is always parseable JSON or "{}".
_merge_config() {
  local tmpdir tmp
  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/session-handoff-merge.XXXXXX")"
  tmp="$tmpdir/merged.json"
  python3 - "$@" > "$tmp" <<'PY' 2>/dev/null || rm -rf "$tmpdir"
import json, os, sys
merged = {}
def deep_merge(base, overlay):
    for k, v in overlay.items():
        if isinstance(v, dict) and isinstance(base.get(k), dict):
            deep_merge(base[k], v)
        else:
            base[k] = v
for path in sys.argv[1:]:
    if not path or not os.path.exists(path):
        continue
    try:
        with open(path) as f:
            data = json.load(f)
    except Exception:
        continue
    if not isinstance(data, dict):
        continue
    deep_merge(merged, data)
print(json.dumps(merged))
PY
  # Validate: good JSON stays, anything else is discarded.
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$tmp" 2>/dev/null \
    && cat "$tmp" || true
  rm -rf "$tmpdir"
}

_CONFIG_PATHS=()
_CONFIG_PATHS_SRC=()
if [ -f "$SKILL_ROOT/context-monitor.json" ]; then
  _CONFIG_PATHS+=("$SKILL_ROOT/context-monitor.json")
  _CONFIG_PATHS_SRC+=("skill defaults")
fi
if [ -n "${SESSION_HANDOFF_CONFIG:-}" ]; then
  if [ -f "$SESSION_HANDOFF_CONFIG" ]; then
    _CONFIG_PATHS+=("$SESSION_HANDOFF_CONFIG")
    _CONFIG_PATHS_SRC+=("SESSION_HANDOFF_CONFIG")
  else
    log "ignoring SESSION_HANDOFF_CONFIG (not a readable file): $SESSION_HANDOFF_CONFIG"
  fi
fi
if [ -f "$HOME/.config/session-handoff/context-monitor.json" ]; then
  _CONFIG_PATHS+=("$HOME/.config/session-handoff/context-monitor.json")
  _CONFIG_PATHS_SRC+=("user config")
fi
if [ -f "$PROJECT_DIR/.claude/session-handoff.json" ]; then
  _CONFIG_PATHS+=("$PROJECT_DIR/.claude/session-handoff.json")
  _CONFIG_PATHS_SRC+=("project config")
fi

if [ "${#_CONFIG_PATHS[@]}" -gt 0 ]; then
  CONFIG_JSON="$(_merge_config "${_CONFIG_PATHS[@]}")"
  if [ -z "$CONFIG_JSON" ] || ! printf '%s' "$CONFIG_JSON" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
    CONFIG_JSON="{}"
  fi
else
  CONFIG_JSON="{}"
fi
export CONFIG_JSON

if mkdir -p "$(dirname "$CONFIG_FILE")" 2>/dev/null; then
  printf '%s\n' "$CONFIG_JSON" > "$CONFIG_FILE.tmp.$$" 2>/dev/null && mv -f "$CONFIG_FILE.tmp.$$" "$CONFIG_FILE" 2>/dev/null
  rm -f "$CONFIG_FILE.tmp.$$" 2>/dev/null
fi
export CONFIG_FILE

# Print a merged-config value by dotted key (e.g. contextWindow, warnPercent).
config_get() {
  local key="$1" out
  out="$(python3 -c '
import json, sys
d = json.loads(sys.argv[1])
cur = d
for k in sys.argv[2].split("."):
    if not isinstance(cur, dict) or k not in cur:
        sys.exit(0)
    cur = cur[k]
if isinstance(cur, bool):
    sys.stdout.write("true" if cur else "false")
elif cur is None:
    pass
else:
    sys.stdout.write(str(cur))
' "$CONFIG_JSON" "$key" 2>/dev/null || true)"
  printf '%s' "$out"
}

# Resolve the transcript for the active session; sets/clears $TRANSCRIPT_PATH.
# Handles both layouts:
#   flat:      <TRANSCRIPT_ROOT>/<slug>/<SESSION_ID>.jsonl   (Claude, Codex)
#   nested:    <TRANSCRIPT_ROOT>/session/<SESSION_ID>/message/<ts>.jsonl (OpenCode)
resolve_transcript() {
  TRANSCRIPT_PATH=""
  local base f
  if [ -n "$SESSION_ID" ]; then
    base="$TRANSCRIPT_ROOT/$SLUG/$SESSION_ID.jsonl"
    if [ -f "$base" ]; then
      TRANSCRIPT_PATH="$base"
    else
      f="$(find "$TRANSCRIPT_ROOT" -type f -name "${SESSION_ID}.jsonl" 2>/dev/null | head -n 1)" || true
      [ -n "$f" ] && TRANSCRIPT_PATH="$f"
    fi
  fi
  # OpenCode nested layout: session/<id>/message/<ts>.json[l]. Pick the newest
  # message under the matched session dir (never a whole-store glob, so a
  # different active session never leaks in).
  if [ -z "$TRANSCRIPT_PATH" ] && [ -n "$SESSION_ID" ] && [ -d "$TRANSCRIPT_ROOT/session/$SESSION_ID" ]; then
    # Use xargs-ls for portability (same as _newest_session_id).
    f="$(find "$TRANSCRIPT_ROOT/session/$SESSION_ID" -type f \( -name '*.jsonl' -o -name '*.json' \) 2>/dev/null | xargs ls -t 2>/dev/null | head -n 1)" || true
    [ -n "$f" ] && TRANSCRIPT_PATH="$f"
  fi
  export TRANSCRIPT_PATH
  return 0

}
