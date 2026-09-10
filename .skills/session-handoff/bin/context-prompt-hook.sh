#!/usr/bin/env bash
# Claude Code UserPromptSubmit hook.
#
# Invoked by the Claude Code hooks subsystem with a JSON payload on stdin that
# includes "workspace.current_dir" and "prompt". If context usage is at/above
# the configured blockPercent, this hook prints a suppression directive on
# stdout -- Claude blocks the submission and the user must decide (e.g. start
# a fresh session) instead of blowing the context window.
#
# Any unhandled failure (missing transcript, tags or precompacts not present
# yet) silently passes the prompt through -- this hook never blocks on error.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/paths.sh"

PERCENT="$(printf '%s' "${STDIN_JSON:-}" | bash "$SCRIPT_DIR/context-monitor.sh" 2>/dev/null || true)"
BLOCK_PERCENT="$(config_get blockPercent)"
BLOCK_PERCENT="${BLOCK_PERCENT:-95}"
if [ -z "$PERCENT" ]; then
  exit 0
fi

if [ "$PERCENT" -ge "$BLOCK_PERCENT" ] 2>/dev/null; then
  # Suppression directive: two streams, stdout is what Claude Code honors.
  printf 'Context is at %s%% (block threshold %s%%). Start a new session and run the session-handoff skill to continue.\n' "$PERCENT" "$BLOCK_PERCENT" >&2
  printf 'The context window is nearly full (%s%%). Starting a new session now is strongly recommended.\n' "$PERCENT"
fi

exit 0
