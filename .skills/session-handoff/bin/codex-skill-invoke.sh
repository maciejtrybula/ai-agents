#!/usr/bin/env bash
# Thin executable wrapper for the Codex skill body and standalone CLI use.
#
# Codex (OpenAI CLI) has no hooks API: the model decides when context is full
# and asks to prepare a handoff. This wrapper marshals the Codex environment
# through lib/paths.sh (transcript root, session id, handoff root) and then
# executes the same mechanical snapshot writer every platform uses.
# Works the same way from the skill body (`bash bin/codex-skill-invoke.sh`)
# and when invoked directly on the command line.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# lib/paths.sh resolves paths and session id (Codex -> CODEX_SESSION_ID),
# then we hand off to the shared snapshot writer. Export defaults first so the
# resolution is deterministic whether or not the caller set them.
export SESSION_HANDOFF_PLATFORM="${SESSION_HANDOFF_PLATFORM:-codex}"
export CODEX_SESSION_ID="${CODEX_SESSION_ID:-${CODEX_CONVERSATION_ID:-}}"

# shellcheck source=../lib/paths.sh
source "$SCRIPT_DIR/../lib/paths.sh"

# exec so stdin / env / exit status pass straight through; the wrapper stays thin.
exec "$SCRIPT_DIR/context-autohandoff.sh" "$@"

# Not reached unless exec fails (e.g. the underlying script is missing).
exit 1
