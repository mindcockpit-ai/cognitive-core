#!/bin/bash
# cognitive-core hook: SessionStart (startup|resume)
# Sets project environment variables and prints status
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"
_cc_load_config

# Set environment variables via CLAUDE_ENV_FILE (persists for session)
if [ -n "${CLAUDE_ENV_FILE:-}" ] && [ -n "${CC_ENV_VARS:-}" ]; then
    # Replace ${PROJECT_DIR} placeholder with actual path
    echo "${CC_ENV_VARS}" | sed "s|\${PROJECT_DIR}|${CC_PROJECT_DIR}|g" >> "$CLAUDE_ENV_FILE"
fi

# Gather project status
BRANCH=$(git -C "$CC_PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")
DIRTY_COUNT=$(git -C "$CC_PROJECT_DIR" status --porcelain 2>/dev/null | grep -c '.' || echo "0")

STATUS="${CC_PROJECT_NAME:-Project} session initialized on branch '${BRANCH}'."
if [ "$DIRTY_COUNT" -gt 0 ]; then
    STATUS="${STATUS} ${DIRTY_COUNT} uncommitted file(s)."
fi

_cc_json_session_context "$STATUS"
