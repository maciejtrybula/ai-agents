#!/usr/bin/env bash
# Writes a mechanical session-handoff markdown snapshot for the active session,
# so a later session can continue the work. Silent on success (except the block
# path in the prompt hook). All paths resolve via lib/paths.sh.
#
# Optional stdin JSON may carry a ".workspace.current_dir" (same as context-monitor).
# The current submitted prompt may be supplied via INPUT_PROMPT_TEXT.
set -euo pipefail

# Source the shared, self-locating lib (bytes-identical across platform slots).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/paths.sh"

# --- Compute the context percent by delegating to context-monitor.sh ---------
PERCENT="$(printf '%s' "${STDIN_JSON:-}" | bash "$SCRIPT_DIR/context-monitor.sh" 2>/dev/null || true)"

# --- Build the output paths --------------------------------------------------
# Transcripts, handoffs: resolved by lib/paths.sh. Handoffs live under the
# project store (or the user-global store when not in a writable git tree).
TRANSCRIPT_PATH=""
resolve_transcript

HANDOFF_DIR="$HANDOFF_ROOT"
PACKAGE_DIR="$(dirname "$HANDOFF_ROOT")"   # <...>/<slug>
HANDOFF_PATH="$HANDOFF_DIR/${SESSION_ID}.md"
mkdir -p "$HANDOFF_DIR"

# If the transcript exists, publish an in-workspace symlink so the pointer never dangles.
if [ -n "$SESSION_ID" ] && [ -n "${TRANSCRIPT_PATH:-}" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  ln -sf "$TRANSCRIPT_PATH" "${PACKAGE_DIR}/${SESSION_ID}.jsonl"
fi

# Last real user prompt (skip task-notification noise) and touched files.
META="$(python3 -c '
import json, sys

transcript = sys.argv[1]
last_user = ""
files = set()

def scan(obj):
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k == "file_path" and isinstance(v, str) and v:
                files.add(v)
            else:
                scan(v)
    elif isinstance(obj, list):
        for item in obj:
            scan(item)

try:
    with open(transcript) as f:
        for line in f:
            try:
                d = json.loads(line)
            except Exception:
                continue
            if d.get("type") == "user":
                content = (d.get("message") or {}).get("content")
                if isinstance(content, str) and content.strip():
                    last_user = content.strip()
                elif isinstance(content, list):
                    parts = []
                    for c in content:
                        if isinstance(c, dict) and c.get("type") == "text" and c.get("text"):
                            parts.append(c["text"])
                        elif isinstance(c, str) and c.strip():
                            parts.append(c)
                    if parts:
                        last_user = " ".join(parts)
            scan((d.get("message") or {}).get("content"))
except Exception:
    pass

# Ignore internal task-notification messages.
clean = last_user
if clean.startswith("<task-notification>"):
    clean = ""

print(json.dumps({"lastUser": clean, "files": sorted(files)}))
' "$TRANSCRIPT_PATH" 2>/dev/null || printf '{"lastUser":"","files":[]}')"

LAST_USER="$(printf '%s' "$META" | python3 -c 'import sys,json;print(json.load(sys.stdin)["lastUser"])' 2>/dev/null || true)"
FILES="$(printf '%s' "$META" | python3 -c 'import sys,json
files=json.load(sys.stdin)["files"]
print("\n".join("- `"+f+"`" for f in files))' 2>/dev/null || true)"
if [ -z "${FILES:-}" ]; then
  FILES="(none detected)"
fi

# --- Gather git state for the workspace ---
GIT_STATE=""
if git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  GIT_STATE="Branch: $(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || true)
$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null || true)"
  if [ -z "$GIT_STATE" ]; then
    GIT_STATE="(clean working tree)"
  fi
else
  GIT_STATE="(not a git repo / git unavailable)"
fi

NOW="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

# --- Assemble the handoff markdown ---
{
  printf '# Session Handoff — %s\n' "$SESSION_ID"
  printf '_Auto-generated on %s — mechanical snapshot for continuation._\n\n' "$NOW"

  printf '## Context usage\n\n'
  if [ -n "${PERCENT:-}" ]; then
    printf 'Context at %s%% of configured window at generation time.\n\n' "$PERCENT"
  else
    printf 'Context usage could not be determined at generation time.\n\n'
  fi

  printf '## Task state\n\n'
  if [ -n "$LAST_USER" ]; then
    printf 'Transcript indicates the last user/assistant text.\n\n'
  else
    printf 'No user prompt text parsed from the transcript.\n\n'
  fi

  if [ -n "$LAST_USER" ]; then
    printf '## In-flight / last prompt\n\n'
    printf '%s\n\n' "$LAST_USER"
  fi

  if [ -n "${INPUT_PROMPT_TEXT:-}" ]; then
    printf '## Last submitted prompt\n\n'
    printf '%s\n\n' "$INPUT_PROMPT_TEXT"
    printf '_(submitted, not yet processed)_\n\n'
  fi

  printf '## Files touched\n\n'
  printf '%s\n\n' "$FILES"

  printf '## Git state\n\n'
  printf '\`\`\`\n%s\n\`\`\`\n\n' "$GIT_STATE"

  printf '## Transcript pointer\n\n'
  printf 'Transcript: `%s`\n\n' "$TRANSCRIPT_PATH"
  printf 'Resume: open a new session, then have Claude read %s and the transcript to continue.\n' "$HANDOFF_PATH"
  printf 'For a curated (LLM-written) summary, run the \`session-handoff\` skill.\n'
} > "$HANDOFF_PATH"

exit 0
