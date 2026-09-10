#!/usr/bin/env bash
# Computes the current context usage percentage for the active session,
# based on cumulative input tokens reported in the transcript.
#
# Reads configuration from the merged context-monitor config (skill defaults
# overlaid with env/user/project overrides via lib/paths.sh). Optional stdin
# JSON may carry a ".workspace.current_dir" to locate the project.
# Prints an integer (0-100) representing used context percent, or nothing if
# unknown. Exits 0 always.
set -euo pipefail

# Source the shared, self-locating lib (this copies bytes-identically into every
# platform discovery slot; paths are resolved here, never hard-coded).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/paths.sh"

# --- Resolve the transcript --------------------------------------------------
resolve_transcript
if [ -z "${TRANSCRIPT_PATH:-}" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  exit 0
fi

# --- Read the most recent assistant usage block for cumulative input tokens ---
MODEL_JSON="$(python3 -c '
import json, sys
transcript = sys.argv[1]
last_tokens = None
last_model = ""
try:
    with open(transcript) as f:
        for line in f:
            try:
                d = json.loads(line)
            except Exception:
                continue
            if d.get("type") == "assistant":
                msg = d.get("message") or {}
                usage = msg.get("usage")
                if isinstance(usage, dict):
                    if usage.get("input_tokens") is not None:
                        last_tokens = usage.get("input_tokens")
                model = d.get("model") or ""
                if model:
                    last_model = model
except Exception:
    pass
print(json.dumps({"tokens": last_tokens, "model": last_model}))
' "$TRANSCRIPT_PATH" 2>/dev/null || true)"

if [ -z "$MODEL_JSON" ]; then
  exit 0
fi

TOKENS="$(printf '%s' "$MODEL_JSON" | python3 -c 'import sys,json;r=json.load(sys.stdin);print(r["tokens"] if r["tokens"] is not None else "")' 2>/dev/null || true)"
MODEL="$(printf '%s' "$MODEL_JSON" | python3 -c 'import sys,json;print(json.load(sys.stdin)["model"])' 2>/dev/null || true)"
if [ -z "${TOKENS:-}" ]; then
  exit 0
fi

# --- Read the context window from merged config and compute percent ----------
WINDOW="$(config_get contextWindow)"
# Fallback: model-keyed hint from config.
if [ -z "$WINDOW" ] || [ "${WINDOW:-0}" -le 0 ] 2>/dev/null; then
  if [ -n "${MODEL:-}" ]; then
    WINDOW="$(python3 -c '
import json, sys
d = json.loads(sys.argv[1])
model = (sys.argv[2] or "").lower()
for k, v in ((d.get("modelToWindowHint") or {}).items()):
    if (str(k).lower() in model) and v:
        print(v)
        break
' "$CONFIG_JSON" "$MODEL" 2>/dev/null || true)"
  fi
fi
if [ -z "$WINDOW" ] || [ "${WINDOW:-0}" -le 0 ] 2>/dev/null; then
  WINDOW=200000
fi

PERCENT=$(( TOKENS * 100 / WINDOW ))
printf '%d\n' "$PERCENT"
