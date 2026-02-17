#!/bin/bash
# cognitive-core shared hook library
# Sourced by all hook scripts for config loading and JSON output helpers

# Resolve project directory
CC_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Load configuration (resolution order: project root > .claude/ > user defaults > env)
_cc_load_config() {
    local conf=""
    if [ -f "${CC_PROJECT_DIR}/cognitive-core.conf" ]; then
        conf="${CC_PROJECT_DIR}/cognitive-core.conf"
    elif [ -f "${CC_PROJECT_DIR}/.claude/cognitive-core.conf" ]; then
        conf="${CC_PROJECT_DIR}/.claude/cognitive-core.conf"
    elif [ -f "${HOME}/.cognitive-core/defaults.conf" ]; then
        conf="${HOME}/.cognitive-core/defaults.conf"
    fi
    if [ -n "$conf" ]; then
        # shellcheck disable=SC1090
        source "$conf"
    fi
}

# Output JSON using jq if available, otherwise fallback to printf
# Usage: _cc_json_output "hookEventName" "fieldName" "fieldValue"
_cc_json_session_context() {
    local ctx="$1"
    if command -v jq &>/dev/null; then
        jq -n --arg ctx "$ctx" '{
            hookSpecificOutput: {
                hookEventName: "SessionStart",
                additionalContext: $ctx
            }
        }'
    else
        local escaped
        escaped=$(printf '%s' "$ctx" | sed 's/"/\\"/g' | tr '\n' '\\n')
        printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}' "$escaped"
    fi
}

_cc_json_pretool_deny() {
    local reason="$1"
    if command -v jq &>/dev/null; then
        jq -n --arg reason "$reason" '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "deny",
                permissionDecisionReason: $reason
            }
        }'
    else
        local escaped
        escaped=$(printf '%s' "$reason" | sed 's/"/\\"/g')
        printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}' "$escaped"
    fi
}

_cc_json_posttool_context() {
    local ctx="$1"
    if command -v jq &>/dev/null; then
        jq -n --arg ctx "$ctx" '{
            hookSpecificOutput: {
                hookEventName: "PostToolUse",
                additionalContext: $ctx
            }
        }'
    else
        local escaped
        escaped=$(printf '%s' "$ctx" | sed 's/"/\\"/g' | tr '\n' '\\n')
        printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}' "$escaped"
    fi
}

# PreToolUse "ask" decision (escalate to human)
_cc_json_pretool_ask() {
    local reason="$1"
    if command -v jq &>/dev/null; then
        jq -n --arg reason "$reason" '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "ask",
                permissionDecisionReason: $reason
            }
        }'
    else
        local escaped
        escaped=$(printf '%s' "$reason" | sed 's/"/\\"/g')
        printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}' "$escaped"
    fi
}

# Security event logging
_cc_security_log() {
    local level="$1" event="$2" detail="$3"
    local logfile="${CC_PROJECT_DIR}/.claude/cognitive-core/security.log"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local logdir
    logdir=$(dirname "$logfile")
    [ -d "$logdir" ] || mkdir -p "$logdir"
    echo "${timestamp} [${level}] ${event}: ${detail}" >> "$logfile"
    # Log rotation: truncate if >1MB
    if [ -f "$logfile" ] && [ "$(wc -c < "$logfile" | tr -d ' ')" -gt 1048576 ]; then
        tail -500 "$logfile" > "${logfile}.tmp" && mv "${logfile}.tmp" "$logfile"
    fi
}

# Cross-platform SHA256
_cc_compute_sha256() {
    local file="$1"
    if command -v sha256sum &>/dev/null; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v shasum &>/dev/null; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        openssl dgst -sha256 "$file" | awk '{print $NF}'
    fi
}

# Guard wrapper: isolates guard execution, catches errors
_cc_guard_run() {
    local guard_name="$1"
    shift
    local err_file="/tmp/cc_guard_err_$$"
    if ! "$@" 2>"$err_file"; then
        local err_msg
        err_msg=$(cat "$err_file" 2>/dev/null || echo "unknown error")
        _cc_security_log "ERROR" "guard-failure" "${guard_name}: ${err_msg}"
        rm -f "$err_file"
        return 0  # NEVER crash the framework
    fi
    rm -f "$err_file"
}

# Extract field from stdin JSON
# Usage: echo "$JSON" | _cc_json_get ".tool_input.command"
_cc_json_get() {
    local path="$1"
    if command -v jq &>/dev/null; then
        jq -r "${path} // \"\"" 2>/dev/null
    else
        # Basic fallback: extract simple string fields
        local key
        key=$(echo "$path" | sed 's/.*\.//')
        grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*: *"//;s/"$//'
    fi
}
