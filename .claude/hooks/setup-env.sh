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

# ---- Session hygiene (glymphatic cleanup) ----
if [ -f "${SCRIPT_DIR}/_session-hygiene.sh" ]; then
    # shellcheck source=_session-hygiene.sh
    source "${SCRIPT_DIR}/_session-hygiene.sh"
    _HYGIENE_NOTICE=$(_cc_session_hygiene "$CC_PROJECT_DIR") || true
    if [ -n "$_HYGIENE_NOTICE" ]; then
        STATUS="${STATUS} ${_HYGIENE_NOTICE}"
    fi
fi

# ---- First-session onboarding ----
_ONBOARD_MARKER="${CC_PROJECT_DIR}/.claude/cognitive-core/.session-started"
if [ ! -f "$_ONBOARD_MARKER" ]; then
    # Count installed agents
    _agent_count=0
    _agent_names=""
    for _af in "${CC_PROJECT_DIR}/.claude/agents/"*.md; do
        [ -f "$_af" ] || continue
        _agent_count=$((_agent_count + 1))
        _agent_names="${_agent_names} $(basename "$_af" .md)"
    done

    # Count installed skills
    _skill_count=0
    _skill_names=""
    for _sd in "${CC_PROJECT_DIR}/.claude/skills/"*/; do
        [ -d "$_sd" ] || continue
        _skill_count=$((_skill_count + 1))
        _skill_names="${_skill_names} $(basename "$_sd")"
    done

    STATUS="${STATUS} FIRST SESSION: Welcome to cognitive-core! Agents (${_agent_count}):${_agent_names}. Skills (${_skill_count}):${_skill_names}. Quick start: '@code-standards-reviewer review my code', '/code-review', '@test-specialist create tests'. Full guide: .claude/AGENTS_README.md"

    # Create marker directory and file
    mkdir -p "$(dirname "$_ONBOARD_MARKER")" 2>/dev/null || true
    date +%s > "$_ONBOARD_MARKER" 2>/dev/null || true
fi

_cc_json_session_context "$STATUS"
