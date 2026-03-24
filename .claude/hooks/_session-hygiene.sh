#!/bin/bash
# shellcheck disable=SC2009
# =============================================================================
# _session-hygiene.sh — Glymphatic cleanup at session start
# =============================================================================
# Biomimetic: brain's glymphatic system flushes metabolic waste during sleep.
# This library flushes stale processes, orphaned worktrees, and old temp files
# at session boundaries.
#
# Sourced by setup-env.sh. Not a standalone hook.
# See: docs/research/sleep-biomimetic-patterns.md (Section 1.2)
# =============================================================================

_cc_session_hygiene() {
    local project_dir="${1:-.}"
    local actions=""
    local warnings=""

    # ---- 1. Stale Claude processes (warn only, never kill) ----
    local stale_pids=""
    local stale_count=0
    local _line _pid _etime _total_hours _days _hours _colons

    while IFS= read -r _line; do
        [ -z "$_line" ] && continue
        _pid=$(echo "$_line" | awk '{print $1}')
        _etime=$(echo "$_line" | awk '{print $2}')
        _total_hours=0

        if echo "$_etime" | grep -q '-'; then
            # DD-HH:MM:SS format
            _days=$(echo "$_etime" | cut -d'-' -f1)
            _hours=$(echo "$_etime" | cut -d'-' -f2 | cut -d':' -f1)
            _total_hours=$(( _days * 24 + _hours ))
        else
            _colons=$(echo "$_etime" | tr -cd ':' | wc -c | tr -d ' ')
            if [ "$_colons" -ge 2 ] 2>/dev/null; then
                # HH:MM:SS format
                _hours=$(echo "$_etime" | cut -d':' -f1)
                _total_hours=$(( _hours ))
            fi
            # MM:SS = 0 hours, skip
        fi

        if [ "$_total_hours" -ge 8 ] 2>/dev/null; then
            stale_pids="${stale_pids:+${stale_pids}, }${_pid}"
            stale_count=$((stale_count + 1))
        fi
    done <<EOF
$(ps -eo pid,etime,command 2>/dev/null | grep '[c]laude' | awk '{print $1, $2}')
EOF

    if [ "$stale_count" -gt 0 ]; then
        warnings="${warnings:+${warnings}, }${stale_count} Claude process(es) >8h (PIDs: ${stale_pids})"
    fi

    # ---- 2. Orphaned git worktrees (auto-prune) ----
    if [ -d "${project_dir}/.git" ] || [ -f "${project_dir}/.git" ]; then
        local _pruned
        _pruned=$(git -C "$project_dir" worktree prune --dry-run 2>/dev/null | wc -l | tr -d ' ')
        if [ "${_pruned:-0}" -gt 0 ] 2>/dev/null; then
            git -C "$project_dir" worktree prune 2>/dev/null
            actions="${actions:+${actions}, }pruned ${_pruned} orphaned worktree(s)"
        fi
    fi

    # ---- 3. Old temp files (auto-delete, >24h) ----
    local _project_slug _tmp_dir
    _project_slug=$(echo "$project_dir" | tr '/' '-' | sed 's/^-//')
    _tmp_dir="/tmp/claude-${_project_slug}"

    if [ -d "$_tmp_dir" ]; then
        local _old_count
        _old_count=$(find "$_tmp_dir" -type f -mmin +1440 2>/dev/null | wc -l | tr -d ' ')
        if [ "${_old_count:-0}" -gt 0 ] 2>/dev/null; then
            find "$_tmp_dir" -type f -mmin +1440 -delete 2>/dev/null
            actions="${actions:+${actions}, }cleaned ${_old_count} temp file(s) >24h"
        fi
    fi

    # ---- 3b. Guard error files (auto-delete, >1h) ----
    local _guard_count
    _guard_count=$(find /tmp -maxdepth 1 -name "cc_guard_err_*" -mmin +60 2>/dev/null | wc -l | tr -d ' ')
    if [ "${_guard_count:-0}" -gt 0 ] 2>/dev/null; then
        find /tmp -maxdepth 1 -name "cc_guard_err_*" -mmin +60 -delete 2>/dev/null
        actions="${actions:+${actions}, }cleaned ${_guard_count} guard error file(s)"
    fi

    # ---- 4. Large temp accumulation (warn only, >50MB) ----
    if [ -d "$_tmp_dir" ]; then
        local _tmp_size_mb
        _tmp_size_mb=$(du -sm "$_tmp_dir" 2>/dev/null | cut -f1)
        if [ "${_tmp_size_mb:-0}" -ge 50 ] 2>/dev/null; then
            warnings="${warnings:+${warnings}, }temp dir ${_tmp_size_mb}MB — consider running context-cleanup.sh"
        fi
    fi

    # ---- 5. Background agent health check ----
    local _agent_warnings
    _agent_warnings=$(_cc_check_agent_health "$project_dir")
    if [ -n "$_agent_warnings" ]; then
        warnings="${warnings:+${warnings}, }${_agent_warnings}"
    fi

    # ---- Compose output (single line, empty if nothing to do) ----
    local result=""
    [ -n "$actions" ] && result="HYGIENE: ${actions}."
    [ -n "$warnings" ] && result="${result:+${result} }WARNING: ${warnings}."

    echo "$result"
}

# =============================================================================
# _cc_check_agent_health — Detect stuck background agents
# =============================================================================
# Checks for Claude agent/subagent processes that exceed the configured
# timeout threshold. Logs to agent-health.log and optionally recommends kill.
#
# Config (from cognitive-core.conf):
#   CC_AGENT_TIMEOUT_MINUTES  — default timeout (default: 30)
#   CC_AGENT_AUTO_KILL        — recommend kill when true (default: false)
# =============================================================================

_cc_check_agent_health() {
    local project_dir="${1:-.}"
    local timeout_minutes="${CC_AGENT_TIMEOUT_MINUTES:-30}"
    local auto_kill="${CC_AGENT_AUTO_KILL:-false}"
    local health_dir="${project_dir}/.claude/cognitive-core"
    local health_log="${health_dir}/agent-health.log"
    local stuck_count=0
    local stuck_info=""
    local _line _pid _etime _total_minutes _days _hours _mins _colons

    while IFS= read -r _line; do
        [ -z "$_line" ] && continue
        _pid=$(echo "$_line" | awk '{print $1}')
        _etime=$(echo "$_line" | awk '{print $2}')
        _total_minutes=0

        if echo "$_etime" | grep -q '-'; then
            # DD-HH:MM:SS format
            _days=$(echo "$_etime" | cut -d'-' -f1)
            _hours=$(echo "$_etime" | cut -d'-' -f2 | cut -d':' -f1)
            _mins=$(echo "$_etime" | cut -d'-' -f2 | cut -d':' -f2)
            _total_minutes=$(( _days * 1440 + _hours * 60 + _mins ))
        else
            _colons=$(echo "$_etime" | tr -cd ':' | wc -c | tr -d ' ')
            if [ "$_colons" -ge 2 ] 2>/dev/null; then
                # HH:MM:SS format
                _hours=$(echo "$_etime" | cut -d':' -f1)
                _mins=$(echo "$_etime" | cut -d':' -f2)
                _total_minutes=$(( _hours * 60 + _mins ))
            else
                # MM:SS format
                _mins=$(echo "$_etime" | cut -d':' -f1)
                _total_minutes=$(( _mins ))
            fi
        fi

        if [ "$_total_minutes" -ge "$timeout_minutes" ] 2>/dev/null; then
            stuck_count=$((stuck_count + 1))
            stuck_info="${stuck_info:+${stuck_info}, }PID ${_pid} (${_total_minutes}min)"

            # Log to health file
            if [ -d "$health_dir" ]; then
                echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') STUCK pid=${_pid} elapsed=${_total_minutes}min threshold=${timeout_minutes}min auto_kill=${auto_kill}" >> "$health_log"
            fi
        fi
    done <<EOF
$(ps -eo pid,etime,command 2>/dev/null | grep -E '[c]laude.*(agent|subagent|background)' | awk '{print $1, $2}')
EOF

    if [ "$stuck_count" -gt 0 ]; then
        local msg="${stuck_count} background agent(s) exceed ${timeout_minutes}min timeout: ${stuck_info}"
        if [ "$auto_kill" = "true" ]; then
            msg="${msg} — recommend TaskStop to terminate"
        fi
        echo "$msg"
    fi
}
