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

# ---- Integrity verification ----
# Compare installed hook files against framework source directory (TOCTOU-safe)
_INTEGRITY_WARNINGS=""
_VERSION_FILE="${CC_PROJECT_DIR}/.claude/cognitive-core/version.json"
if [ -f "$_VERSION_FILE" ]; then
    _SOURCE_DIR=$(echo "$_VERSION_FILE" | xargs cat 2>/dev/null | _cc_json_get ".source")
    if [ -n "$_SOURCE_DIR" ] && [ -d "${_SOURCE_DIR}/core/hooks" ]; then
        for hook_file in "${CC_PROJECT_DIR}/.claude/hooks/"*.sh; do
            [ -f "$hook_file" ] || continue
            _basename=$(basename "$hook_file")
            _src_file="${_SOURCE_DIR}/core/hooks/${_basename}"
            if [ -f "$_src_file" ]; then
                _installed_sha=$(_cc_compute_sha256 "$hook_file")
                _source_sha=$(_cc_compute_sha256 "$_src_file")
                if [ "$_installed_sha" != "$_source_sha" ]; then
                    _INTEGRITY_WARNINGS="${_INTEGRITY_WARNINGS} ${_basename}"
                fi
            fi
        done
        if [ -n "$_INTEGRITY_WARNINGS" ]; then
            _cc_security_log "WARN" "integrity-mismatch" "Modified hooks:${_INTEGRITY_WARNINGS}"
        fi
    fi
fi

# Gather project status
BRANCH=$(git -C "$CC_PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")
DIRTY_COUNT=$(git -C "$CC_PROJECT_DIR" status --porcelain 2>/dev/null | grep -c '.' || echo "0")

STATUS="${CC_PROJECT_NAME:-Project} session initialized on branch '${BRANCH}'."
if [ "$DIRTY_COUNT" -gt 0 ]; then
    STATUS="${STATUS} ${DIRTY_COUNT} uncommitted file(s)."
fi

if [ -n "$_INTEGRITY_WARNINGS" ]; then
    STATUS="${STATUS} SECURITY: Hook files differ from framework source:${_INTEGRITY_WARNINGS}. Run update.sh or verify changes are intentional."
fi

# ---- Connected Projects: update check ----
_UPDATE_CHECK="${CC_PROJECT_DIR}/.claude/cognitive-core/check-update.sh"
if [ -f "$_UPDATE_CHECK" ] && [ -x "$_UPDATE_CHECK" ]; then
    _UPDATE_NOTICE=$("$_UPDATE_CHECK" 2>/dev/null) || true
    if [ -n "$_UPDATE_NOTICE" ]; then
        STATUS="${STATUS} ${_UPDATE_NOTICE}"
    fi
fi

_cc_json_session_context "$STATUS"
