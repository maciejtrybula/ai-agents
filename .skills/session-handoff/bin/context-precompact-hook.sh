#!/usr/bin/env bash
# Claude Code PreCompact hook.
#
# Invoked by the Claude Code hooks subsystem right before a context compact.
# Writes a fresh mechanical snapshot to the handoff store so no work is lost
# when the window compacts. Same code path as the standalone CLI, so the
# snapshot format is identical. Silent on success.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/paths.sh"

# Delegate to the mechanical snapshot writer, passing along any stdin hook JSON.
INPUT_PROMPT_TEXT="${INPUT_PROMPT_TEXT:-}" \
  bash "$SCRIPT_DIR/context-autohandoff.sh" "$@" >/dev/null 2>&1 || true

exit 0
