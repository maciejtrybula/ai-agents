#!/usr/bin/env bash
# lib/wire-settings.sh -- platform activation glue (Claude Code).
#
# A pure-bash helper library for materializing Claude settings (hooks,
# statusline) into `~/.claude/settings.json` or `<project>/.claude/settings.json`.
#
# Contract:
#   - No repo-path hard-coding. The repo root is located by the same
#     BASH_SOURCE[0] ancestor-walk used in lib/paths.sh (self-locating).
#   - Never deletes keys we do not own. `merge_json` deep-merges files onto the
#     output using python3 (same temp-file pattern as lib/paths.sh `_merge_config`);
#     JSON that fails to parse is left untouched with an error message on stderr.
#   - Idempotent: `ensure_claude_hooks` adds exactly its two hook entries only
#     when the exact entries are absent; re-running is a no-op.
#   - This file is *sourced*, not executed (it defines functions, prints nothing).
set -euo pipefail

# Self-contained: this lib does NOT source lib/paths.sh (it is used by the
# platform-integration harness before/without the skill tree), so it defines
# its own logging helper.
log() { printf 'session-handoff: %s\n' "$*" >&2; }

# --- Self-location -------------------------------------------------------------
_wire_pwd_of() {
  local p="$1"
  (cd "$(dirname "$p")" 2>/dev/null && pwd) || dirname "$p"
}
WIRE_LIB_DIR="$(_wire_pwd_of "${BASH_SOURCE[0]}")"
WIRE_SKILL_ROOT="$WIRE_LIB_DIR/.."   # the session-handoff skill tree we live in
export WIRE_SKILL_ROOT

_wire_skill_bin() {   # absolute path of <skill-root>/bin/<name>
  local name="$1"
  printf '%s' "$WIRE_SKILL_ROOT/bin/$name"
}

# --- Permissions / existence helpers -------------------------------------------
_wire_has_claude_hook() { # settings file, verb, command -- exact block entry?
  local file="$1" verb="$2" cmd="$3"
  [ -f "$file" ] || return 1
  local hooks_has block_hooks
  hooks_has="$(python3 -c '
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
b = d.get("hooks")
if not isinstance(b, dict):
    sys.exit(1)
rows = b.get(sys.argv[2])
def present():
    if not isinstance(rows, list):
        return False
    for r in rows:
        if not isinstance(r, dict):
            continue
        for h in (r.get("hooks") or []):
            if isinstance(h, dict) and h.get("type") == "command" \
               and str(h.get("command", "")) == sys.argv[3]:
                return True
    return False
print("1" if present() else "0")
' "$file" "$verb" "$cmd" 2>/dev/null || printf '0')"
  [ "$hooks_has" = "1" ]
}

# --- backup_file ---------------------------------------------------------------
# Copies <path> to <path>.bak-<epoch timestamp> if the file exists and has not
# been backed up this run (tracks a per-run seen-set). Returns 0 always.
_backup_seen=()
backup_file() {
  local path="$1" ts bak
  [ -e "$path" ] || return 0
  local pkey p
  pkey="$(cd "$(dirname "$path")" 2>/dev/null && pwd; printf '/%s' "$(basename "$path")")"
  for p in "${_backup_seen[@]:-}"; do
    [ "$p" = "$pkey" ] && return 0
  done
  _backup_seen+=("$pkey")
  ts="$(date +%s 2>/dev/null || printf 0)"
  bak="${path}.bak-${ts}"
  cp -p "$path" "$bak" 2>/dev/null || { log "could not back up $path" >&2; return 0; }
  log "backed up $path -> $bak" >&2
}

# --- merge_json ----------------------------------------------------------------
# Deep-merges <base_files...> into <out> using python3 (the same temp-file
# approach as lib/paths.sh `_merge_config`): later files win, dictionaries are
# merged recursively, scalars/arrays replace. Keys already present in <out> but
# absent from the base files are preserved (we only overlay). Never deletes.
# On failure the original <out> is left untouched. Prints nothing.
merge_json() {
  [ "$#" -ge 2 ] || { log "merge_json: need <base_files...> <out>" >&2; return 1; }
  local out tmp tmpdir
  out="${*: -1}"
  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/session-handoff-wire.XXXXXX")"
  tmp="$tmpdir/merged.json"
  if ! python3 - "$@" "$tmp" <<'PY' 2>/dev/null; then
import json, os, sys
base_files = sys.argv[1:-2]
out_path = sys.argv[-2]
tmp_path = sys.argv[-1]

def deep_merge(base, overlay):
    for k, v in overlay.items():
        if isinstance(v, dict) and isinstance(base.get(k), dict):
            deep_merge(base[k], v)
        else:
            base[k] = v

target = {}
if os.path.exists(out_path):
    try:
        with open(out_path) as f:
            parsed = json.load(f)
        if isinstance(parsed, dict):
            target = parsed
    except Exception:
        pass
for p in base_files:
    if not p or not os.path.exists(p):
        continue
    try:
        with open(p) as f:
            data = json.load(f)
    except Exception:
        continue
    if isinstance(data, dict):
        deep_merge(target, data)
with open(tmp_path, "w") as f:
    json.dump(target, f, indent=2)
    f.write("\n")
PY
    log "merge_json: failed to merge into $out" >&2
    rm -rf "$tmpdir"
    return 1
  fi
  if ! python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$tmp" 2>/dev/null; then
    log "merge_json: merged output invalid; leaving $out untouched" >&2
    rm -rf "$tmpdir"
    return 1
  fi
  cp -f "$tmp" "$out" 2>/dev/null || { log "merge_json: cannot write $out" >&2; rm -rf "$tmpdir"; return 1; }
  rm -rf "$tmpdir"
  return 0
}

# --- ensure_claude_hooks -------------------------------------------------------
# Idempotently adds to <settings.json> the two hook blocks:
#   hooks.UserPromptSubmit -> <command-prefix>/bin/context-prompt-hook.sh
#   hooks.PreCompact       -> <command-prefix>/bin/context-precompact-hook.sh
# <command-prefix> is the resolved skill root that the harness computed from
# the materialized copy (e.g. "$HOME/.claude/skills/session-handoff" or
# "<project>/.claude/skills/session-handoff"). Not hard-coded here.
# Existing hooks (and everything else) are preserved. May modify the file;
# returns 0 always.
ensure_claude_hooks() {
  local file="$1" prefix="$2"
  [ -n "$prefix" ] || { log "ensure_claude_hooks: empty command prefix" >&2; return 1; }
  local prompt_hook precompact_hook
  prompt_hook="$prefix/bin/context-prompt-hook.sh"
  precompact_hook="$prefix/bin/context-precompact-hook.sh"

  if _wire_has_claude_hook "$file" "UserPromptSubmit" "$prompt_hook" \
    && _wire_has_claude_hook "$file" "PreCompact" "$precompact_hook"; then
    return 0
  fi

  backup_file "$file"
  if python3 - "$file" "$prompt_hook" "$precompact_hook" <<'PY' 2>/dev/null; then
import json, os, sys
path, prompt_hook, precompact_hook = sys.argv[1], sys.argv[2], sys.argv[3]

def block(cmd):
    return {"matchers": "*", "hooks": [{"type": "command", "command": cmd}]}

data = {}
if os.path.exists(path):
    try:
        with open(path) as f:
            parsed = json.load(f)
        if isinstance(parsed, dict):
            data = parsed
        else:
            data = {}
            print("invalid settings json; starting fresh", file=sys.stderr)
    except Exception:
        data = {}
        print("invalid settings json; starting fresh", file=sys.stderr)

hooks = data.get("hooks")
if not isinstance(hooks, dict):
    hooks = {}
    data["hooks"] = hooks

def hook_command_present(rows, cmd):
    if not isinstance(rows, list):
        return False
    for r in rows:
        if not isinstance(r, dict):
            continue
        for h in (r.get("hooks") or []):
            if isinstance(h, dict) and h.get("type") == "command" \
               and str(h.get("command", "")) == cmd:
                return True
    return False

def upsert(hooks, verb, cmd):
    rows = hooks.get(verb)
    if not isinstance(rows, list):
        rows = []
        hooks[verb] = rows
    if hook_command_present(rows, cmd):
        return
    rows.append(block(cmd))

upsert(hooks, "UserPromptSubmit", prompt_hook)
upsert(hooks, "PreCompact", precompact_hook)

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
    : # success
  else
    log "ensure_claude_hooks: could not update $file" >&2
  fi
}

# --- wire_claude_settings ------------------------------------------------------
# Decides project vs user-global target for the Claude settings file:
#   <cwd_for_project_detection> inside a writable repo + writable project
#   settings file -> <repo>/.claude/settings.json
#   else          -> ~/.claude/settings.json (if writable)
# Backs up the target, deep-merges any <extra_json_files...> (optional base
# files; does not need to be passed when only the hook blocks matter), and
# ensures our hooks. Always prints a one-line summary ("# wired hooks into
# <path>" or "# skipped (no write-able target)"). Returns 0 always.
wire_claude_settings() {
  local cwd_for_detection="$1" repo_root="$2"
  shift 2
  local extra_files=("$@")

  local target
  target="$( _claude_settings_target_for "$cwd_for_detection" "$repo_root" )" || target=""
  if [ -z "$target" ]; then
    printf '# skipped (no write-able target)\n'
    return 0
  fi

  backup_file "$target"
  if [ "${#extra_files[@]}" -gt 0 ]; then
    merge_json "${extra_files[@]}" "$target" || true
  fi

  local prefix
  prefix="$( _claude_settings_prefix_for "$target" )"
  if [ -n "$prefix" ]; then
    ensure_claude_hooks "$target" "$prefix"
  fi
  printf '# wired hooks into %s\n' "$target"
}

# --- helpers for wire_claude_settings ------------------------------------------
_claude_settings_target_for() { # cwd_for_detection, repo_root -> path or ""
  local cwd="$1" repo_root="$2"
  local settings=""
  if [ -d "$cwd" ] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # Inside a repo: prefer the repo's own .claude/ (git_root or $repo_root),
    # not an unrelated parent repo, so project installs never leak into global
    # settings while they should be project-local.
    local git_root
    git_root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$git_root" ]; then
      if [ "$git_root" = "$repo_root" ] || [ "$(cd "$git_root" && pwd)" = "$(cd "$repo_root" && pwd 2>/dev/null)" ]; then
        if [ -d "$git_root/.claude" ] && [ -w "$git_root/.claude" ]; then
          settings="$git_root/.claude/settings.json"
        elif [ -w "$git_root" ]; then
          settings="$git_root/.claude/settings.json"
        fi
      fi
    fi
    # Fall back to repo_root when cwd is deeper inside $repo_root but its
    # .claude/ is missing (refresh repo copy case).
    if [ -z "$settings" ] && [ -n "$repo_root" ] && [ -d "$repo_root/.git" ]; then
      if [ -d "$repo_root/.claude" ] && [ -w "$repo_root/.claude" ]; then
        settings="$repo_root/.claude/settings.json"
      elif [ -w "$repo_root" ]; then
        settings="$repo_root/.claude/settings.json"
      fi
    fi
  fi
  if [ -z "$settings" ]; then
    if [ -n "${HOME:-}" ] && [ -d "$HOME/.claude" ] && [ -w "$HOME/.claude" ]; then
      settings="$HOME/.claude/settings.json"
    elif [ -n "${HOME:-}" ] && [ -w "$HOME" ]; then
      settings="$HOME/.claude/settings.json"
    fi
  fi
  printf '%s' "$settings"
}

_claude_settings_prefix_for() { # settings path -> skill root prefix ("" if none)
  local settings="$1"
  local prefix=""
  case "$settings" in
    "$HOME/.claude/"*)
      prefix="$HOME/.claude/skills/session-handoff"
      ;;
    *"/.claude/settings.json")
      prefix="${settings%/.claude/settings.json}/.claude/skills/session-handoff"
      ;;
  esac
  printf '%s' "$prefix"
}
