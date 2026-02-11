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
