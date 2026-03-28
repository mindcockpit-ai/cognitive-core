#!/bin/bash
# cognitive-core hook: Stop — session cleanup
# Removes this session from the registry and cleans up the lock dir.
#
# Paired with session-guard.sh (SessionStart).
# See: docs/research/inter-session-coordination.md
# Issue: #144
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"
_cc_load_config

# ---- Configuration ----
_LOCKDIR="${CC_PROJECT_DIR}/.claude/session.lock.d"
_REGISTRY="${CC_PROJECT_DIR}/.claude/sessions.json"

# ---- Step 1: Read session ID from lock dir ----
_SESSION_ID=""
if [ -f "$_LOCKDIR/.session-id" ]; then
    _SESSION_ID=$(cat "$_LOCKDIR/.session-id" 2>/dev/null || echo "")
fi

# ---- Step 2: Remove lock dir ----
if [ -d "$_LOCKDIR" ]; then
    rm -rf "$_LOCKDIR"
fi

# ---- Step 3: Remove our entry from sessions.json (match by session ID) ----
if [ -n "$_SESSION_ID" ] && [ -f "$_REGISTRY" ] && command -v jq &>/dev/null; then
    _updated=$(jq --arg sid "$_SESSION_ID" \
        '.sessions = [.sessions[] | select(.id != $sid)]' \
        "$_REGISTRY" 2>/dev/null)
    if [ -n "$_updated" ]; then
        echo "$_updated" > "$_REGISTRY"
    fi
fi

# Silent exit — Stop hooks should not produce output
exit 0
