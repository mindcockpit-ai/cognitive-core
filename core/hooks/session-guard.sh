#!/bin/bash
# cognitive-core hook: SessionStart — inter-session coordination guard
# Detects concurrent sessions on the same repo, warns about conflicts.
# Advisory only: warns, never denies.
#
# Lock mechanism: mkdir (POSIX atomic, portable macOS + Linux)
# Registry: .claude/sessions.json (JSON array of active sessions)
#
# See: docs/research/inter-session-coordination.md
# Issue: #144
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"
_cc_load_config

# jq is required for session coordination — skip guard entirely if absent
if ! command -v jq &>/dev/null; then
    exit 0
fi

# ---- Configuration ----
_STALE_THRESHOLD_SECONDS=7200  # 2 hours
_LOCKDIR="${CC_PROJECT_DIR}/.claude/session.lock.d"
_REGISTRY="${CC_PROJECT_DIR}/.claude/sessions.json"
_SESSION_ID="session-$(date +%s)-$$"
_SESSION_MARKER="${CC_PROJECT_DIR}/.claude/session.lock.d/.session-id"
_CURRENT_BRANCH=$(git -C "$CC_PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")
_CURRENT_PID=$$
_NOW=$(date +%s)

# ---- Helpers ----

# Get epoch from date string (portable macOS + Linux)
# Handles: ISO 8601 (2026-04-14T21:10:30Z) and ps lstart (Tue Apr 14 21:10:30 2026)
_cc_date_to_epoch() {
    local datestr="$1"
    local result
    # Strip timezone suffix for macOS date -j
    local stripped="${datestr%%[+-][0-9][0-9]:[0-9][0-9]}"
    stripped="${stripped%%Z}"
    # macOS: ISO 8601 format
    result=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" "+%s" 2>/dev/null) && { echo "$result"; return; }
    # macOS: ps lstart format (e.g., "Tue Apr 14 21:10:30 2026")
    result=$(date -j -f "%a %b %d %H:%M:%S %Y" "$stripped" "+%s" 2>/dev/null) && { echo "$result"; return; }
    # Linux: date -d (handles both ISO and lstart formats)
    result=$(date -d "$datestr" "+%s" 2>/dev/null) && { echo "$result"; return; }
    echo "0"
}

# Read sessions.json, return array content (or empty)
_cc_read_registry() {
    if [ -f "$_REGISTRY" ] && command -v jq &>/dev/null; then
        jq -r '.sessions // []' "$_REGISTRY" 2>/dev/null || echo "[]"
    else
        echo "[]"
    fi
}

# Write sessions array to registry
_cc_write_registry() {
    local sessions_array="$1"
    local dir
    dir=$(dirname "$_REGISTRY")
    mkdir -p "$dir" 2>/dev/null || true
    if command -v jq &>/dev/null; then
        jq -n --argjson sessions "$sessions_array" '{"sessions": $sessions}' > "$_REGISTRY"
    else
        printf '{"sessions":%s}\n' "$sessions_array" > "$_REGISTRY"
    fi
}

# ---- Step 1: Clean stale entries from registry ----
_active_sessions="[]"
_warnings=""

if [ -f "$_REGISTRY" ] && command -v jq &>/dev/null; then
    _all_sessions=$(_cc_read_registry)
    _cleaned="[]"

    # Iterate sessions, keep only live ones
    _count=$(echo "$_all_sessions" | jq 'length')
    _i=0
    while [ "$_i" -lt "$_count" ]; do
        _entry=$(echo "$_all_sessions" | jq ".[$_i]")
        _pid=$(echo "$_entry" | jq -r '.pid // 0')
        _started=$(echo "$_entry" | jq -r '.started // ""')

        # Check if PID is alive and belongs to the same process (TOCTOU race prevention)
        _pid_alive="false"
        if [ "$_pid" -gt 0 ] 2>/dev/null && kill -0 "$_pid" 2>/dev/null; then
            # Verify PID belongs to same process by comparing start times
            _ps_start=$(ps -p "$_pid" -o lstart= 2>/dev/null | tr -s ' ')
            if [ -n "$_started" ] && [ -n "$_ps_start" ]; then
                _stored_epoch=$(_cc_date_to_epoch "$_started")
                _ps_epoch=$(_cc_date_to_epoch "$_ps_start")
                _drift=$(( _stored_epoch - _ps_epoch ))
                [ "$_drift" -lt 0 ] && _drift=$(( -_drift ))
                if [ "$_drift" -le 2 ]; then
                    _pid_alive="true"
                fi
            else
                _pid_alive="true"  # No start time to compare — fallback to PID-only
            fi
        fi

        # Check if session is stale (>2h)
        _is_stale="false"
        if [ -n "$_started" ]; then
            _start_epoch=$(_cc_date_to_epoch "$_started")
            _age=$(( _NOW - _start_epoch ))
            if [ "$_age" -gt "$_STALE_THRESHOLD_SECONDS" ] 2>/dev/null; then
                _is_stale="true"
            fi
        fi

        # Keep if alive and not stale
        if [ "$_pid_alive" = "true" ] && [ "$_is_stale" = "false" ]; then
            _cleaned=$(echo "$_cleaned" | jq --argjson entry "$_entry" '. + [$entry]')
        fi

        _i=$((_i + 1))
    done

    _active_sessions="$_cleaned"
fi

# ---- Step 2: Also clean stale lock dirs ----
if [ -d "$_LOCKDIR" ]; then
    _lock_pid=$(cat "$_LOCKDIR/pid" 2>/dev/null || echo "0")
    if ! kill -0 "$_lock_pid" 2>/dev/null; then
        rm -rf "$_LOCKDIR"
    fi
fi

# ---- Step 3: Warn about active sessions ----
_active_count=0
if command -v jq &>/dev/null; then
    _active_count=$(echo "$_active_sessions" | jq 'length')
fi

if [ "$_active_count" -gt 0 ]; then
    _i=0
    while [ "$_i" -lt "$_active_count" ]; do
        _entry=$(echo "$_active_sessions" | jq ".[$_i]")
        _s_branch=$(echo "$_entry" | jq -r '.branch // "unknown"')
        _s_desc=$(echo "$_entry" | jq -r '.description // ""')
        _s_started=$(echo "$_entry" | jq -r '.started // ""')
        _s_pid=$(echo "$_entry" | jq -r '.pid // 0')

        # Calculate age
        _age_str="unknown"
        if [ -n "$_s_started" ]; then
            _s_epoch=$(_cc_date_to_epoch "$_s_started")
            _age_sec=$(( _NOW - _s_epoch ))
            _age_min=$(( _age_sec / 60 ))
            if [ "$_age_min" -lt 60 ]; then
                _age_str="${_age_min}min"
            else
                _age_str="$(( _age_min / 60 ))h $(( _age_min % 60 ))m"
            fi
        fi

        _session_info="Session on '${_s_branch}' (PID ${_s_pid}, ${_age_str} ago)"
        [ -n "$_s_desc" ] && _session_info="${_session_info}: ${_s_desc}"
        _warnings="${_warnings:+${_warnings} }CONCURRENT: ${_session_info}."

        # Extra warning if same branch
        if [ "$_s_branch" = "$_CURRENT_BRANCH" ]; then
            _warnings="${_warnings} CONFLICT: Another session is on the SAME branch '${_CURRENT_BRANCH}'. Consider: claude --worktree <name>."
        fi

        _i=$((_i + 1))
    done
fi

# ---- Step 4: Acquire lock ----
mkdir -p "$(dirname "$_LOCKDIR")" 2>/dev/null || true
if mkdir "$_LOCKDIR" 2>/dev/null; then
    echo "$_CURRENT_PID" > "$_LOCKDIR/pid"
    echo "$_SESSION_ID" > "$_LOCKDIR/.session-id"
    date -Iseconds > "$_LOCKDIR/started" 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S' > "$_LOCKDIR/started"
    # NOTE: no EXIT trap here — the lock dir persists for the session lifetime.
    # session-cleanup.sh (Stop hook) removes it. If the process crashes,
    # the next session-guard.sh detects the stale lock via PID check.
fi

# ---- Step 5: Register in sessions.json ----
_started_iso=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')
_new_entry="{\"id\":\"${_SESSION_ID}\",\"started\":\"${_started_iso}\",\"branch\":\"${_CURRENT_BRANCH}\",\"description\":\"\",\"pid\":${_CURRENT_PID}}"

if command -v jq &>/dev/null; then
    _updated=$(echo "$_active_sessions" | jq --argjson entry "$_new_entry" '. + [$entry]')
else
    # No jq: write minimal registry
    _updated="[${_new_entry}]"
fi
_cc_write_registry "$_updated"

# ---- Step 6: Output ----
_status="${CC_PROJECT_NAME:-Project} session guard: ${_active_count} other session(s) detected."
if [ -n "$_warnings" ]; then
    _status="${_status} ${_warnings}"
fi

_cc_json_session_context "$_status"
