#!/usr/bin/env bash
# Prints a short context-percent string for the Claude Code statusline
# (statusLine.command), e.g. "ctx 45%". Prints nothing (exit 0) when usage
# cannot be determined, so the statusline shows no decoration for unknown state.
#
# The statusline runs once per render; it must stay cheap and never fail.
# All paths resolve via lib/paths.sh. Optional stdin JSON may carry a
# ".workspace.current_dir" (same as the other bin scripts).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/paths.sh"

PERCENT="$(printf '%s' "${STDIN_JSON:-}" | bash "$SCRIPT_DIR/context-monitor.sh" 2>/dev/null || true)"
if [ -z "$PERCENT" ]; then
  exit 0
fi

printf 'ctx %s%%\n' "$PERCENT"
exit 0
