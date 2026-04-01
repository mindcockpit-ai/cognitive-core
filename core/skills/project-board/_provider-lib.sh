#!/bin/bash
# =============================================================================
# _provider-lib.sh — Shared library for project-board providers
#
# Provides: config loading, JSON output helpers, status key mapping,
#           provider validation, and common utilities.
#
# Sourced by each provider script. Never executed directly.
# =============================================================================

# ---- Config Loading ----

_pb_load_config() {
    local dir="${PROJECT_DIR:-.}"
    local conf
    for conf in "$dir/cognitive-core.conf" "$dir/.claude/cognitive-core.conf" "$HOME/.cognitive-core/defaults.conf"; do
        if [[ -f "$conf" ]]; then
            # shellcheck source=/dev/null
            source "$conf"
            return 0
        fi
    done
    _pb_die "cognitive-core.conf not found in $dir or ~/.cognitive-core/"
}

# ---- Output Helpers ----

_pb_json_kv() {
    # Output a simple key-value JSON object
    # Usage: _pb_json_kv key1 val1 key2 val2 ...
    local out="{"
    local first=true
    while [[ $# -ge 2 ]]; do
        $first || out+=","
        first=false
        out+="\"$1\":\"$2\""
        shift 2
    done
    out+="}"
    echo "$out"
}

_pb_error() {
    echo "{\"error\": \"$1\"}" >&2
}

_pb_die() {
    _pb_error "$1"
    exit 1
}

_pb_success() {
    echo "{\"ok\":true,\"message\":\"$1\"}"
}

# ---- Status Key Mapping ----
# Canonical status keys used across all providers.
# Each provider maps these to its own status IDs/transitions.

PB_STATUS_DISPLAY_NAMES=(
    "roadmap:Roadmap"
    "backlog:Backlog"
    "todo:Todo"
    "progress:In Progress"
    "testing:To Be Tested"
    "done:Done"
    "canceled:Canceled"
)

_pb_status_display_name() {
    local key="$1"
    local entry
    for entry in "${PB_STATUS_DISPLAY_NAMES[@]}"; do
        if [[ "${entry%%:*}" == "$key" ]]; then
            echo "${entry#*:}"
            return 0
        fi
    done
    echo "$key"
}

# Reverse-map a provider-native status name to a canonical key.
# Checks the active provider's CC_*_STATUS_MAP; falls back to display name match.
# Usage: _pb_canonical_status "Zu erledigen" → "todo"
_pb_canonical_status() {
    local native="$1"
    local native_lower
    native_lower=$(echo "$native" | tr '[:upper:]' '[:lower:]')

    # Try provider-specific status map (covers custom Jira/YouTrack names)
    local map=""
    map="${CC_JIRA_STATUS_MAP:-}${CC_YOUTRACK_STATUS_MAP:-}${CC_GITHUB_STATUS_MAP:-}"
    if [[ -n "$map" ]]; then
        local pair
        IFS='|' read -ra pairs <<< "$map"
        for pair in "${pairs[@]}"; do
            local k="${pair%%=*}"
            local v="${pair#*=}"
            local v_lower
            v_lower=$(echo "$v" | tr '[:upper:]' '[:lower:]')
            if [[ "$v_lower" == "$native_lower" ]]; then
                echo "$k"
                return 0
            fi
        done
    fi

    # Fall back to display name table
    local entry
    for entry in "${PB_STATUS_DISPLAY_NAMES[@]}"; do
        local dk="${entry%%:*}"
        local dv="${entry#*:}"
        local dv_lower
        dv_lower=$(echo "$dv" | tr '[:upper:]' '[:lower:]')
        if [[ "$dv_lower" == "$native_lower" ]]; then
            echo "$dk"
            return 0
        fi
    done

    echo "$native"
}

# ---- Closure Guard ----
# Deterministic pre-check for pb_issue_close. Invoked by the router before
# dispatching to the provider's close function. Ensures:
#   1. Terminal states (Done/Canceled) cannot be re-closed
#   2. Approval gate enforced when CC_REQUIRE_HUMAN_APPROVAL=true
#   3. Acceptance criteria (checkboxes) are all checked before closure
# Exemptions: --force flag, "Canceled:" comment prefix

_pb_closure_guard() {
    local number="$1"
    shift
    local comment="" force="false"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --comment) comment="$2"; shift 2 ;;
            --force)   force="true"; shift ;;
            *)         shift ;;
        esac
    done

    # Cancel path: exempt from approval gate (but not terminal state check)
    local is_cancel="false"
    if [[ "$comment" == Canceled:* ]]; then
        is_cancel="true"
    fi

    # Force flag: bypass all guards (audit logged)
    if [[ "$force" == "true" ]]; then
        if declare -f _cc_security_log >/dev/null 2>&1; then
            _cc_security_log "WARN" "closure-guard-force" "Issue #$number force-closed by override"
        fi
        echo '{"warning":"Closure guard bypassed with --force"}' >&2
        return 0
    fi

    # Guard 1: Check board status (terminal states blocked)
    local status_json current_status
    status_json=$(pb_board_status "$number" 2>/dev/null) || true
    current_status=$(echo "$status_json" | _CC_FIELD="status" python3 -c "
import json, sys, os
try:
    data = json.load(sys.stdin)
    print(data.get(os.environ['_CC_FIELD'], 'Unknown'))
except Exception:
    print('Unknown')
" 2>/dev/null || echo "Unknown")

    local canonical_status
    canonical_status=$(_pb_canonical_status "$current_status")

    if [[ "$canonical_status" == "done" ]]; then
        _pb_die "Cannot close #$number — already Done ($current_status)"
    fi
    if [[ "$canonical_status" == "canceled" ]]; then
        _pb_die "Cannot close #$number — already Canceled ($current_status)"
    fi

    # Guard 2: Approval gate (skip for cancel path)
    if [[ "$is_cancel" == "false" ]]; then
        local approval_required="${CC_REQUIRE_HUMAN_APPROVAL:-true}"
        if [[ "$approval_required" == "true" && "$canonical_status" == "testing" ]]; then
            _pb_die "Cannot close #$number — status is '$current_status' and CC_REQUIRE_HUMAN_APPROVAL=true. Use /project-board approve $number instead"
        fi
    fi

    # Guard 3: Acceptance criteria check (skip for cancel path)
    if [[ "$is_cancel" == "false" ]]; then
        local issue_json unchecked
        issue_json=$(pb_issue_view "$number" 2>/dev/null) || true
        if [[ -n "$issue_json" ]]; then
            unchecked=$(echo "$issue_json" | python3 -c "
import json, sys, re
data = json.load(sys.stdin)
body = data.get('body', '') or data.get('description', '') or ''
if isinstance(body, dict):
    body = json.dumps(body)
total = len(re.findall(r'-\s*\[[ xX]\]', body))
checked = len(re.findall(r'-\s*\[[xX]\]', body))
unchecked = total - checked
if total > 0 and unchecked > 0:
    print(f'{unchecked} of {total} acceptance criteria unchecked')
" 2>/dev/null || echo "")
            if [[ -n "$unchecked" ]]; then
                _pb_die "Cannot close #$number — $unchecked"
            fi
        fi
    fi

    return 0
}

# ---- Provider Interface ----
# Each provider MUST implement these functions:
#
# Required:
#   pb_issue_list [--priority P] [--area A] [--state S]
#   pb_issue_create TITLE [--labels L] [--body B]
#   pb_issue_close NUMBER [--comment C]
#   pb_issue_reopen NUMBER
#   pb_issue_view NUMBER [--json FIELDS]
#       → JSON output MUST include a "url" field with the browse URL for the issue
#   pb_issue_comment NUMBER BODY
#   pb_issue_assign NUMBER USER
#   pb_board_summary
#   pb_board_status NUMBER
#       → JSON output MUST include a "url" field with the browse URL for the issue
#   pb_board_move NUMBER STATUS_KEY
#   pb_board_add NUMBER [--area A]
#   pb_board_approve NUMBER [--comment C]
#   pb_provider_info
#
# Optional (providers may return "not supported"):
#   pb_sprint_list [--all]
#   pb_sprint_assign SPRINT_TITLE NUMBERS...
#   pb_branch_create NUMBER TYPE SLUG [--base B]
#   pb_branch_list NUMBER
#   pb_board_label_add NUMBER LABEL
#   pb_board_label_remove NUMBER LABEL
#   pb_board_metrics [--sprint S]
#   pb_issue_timeline NUMBER  (returns status change events for metrics)

_pb_validate_provider() {
    local required_fns=(
        pb_issue_list pb_issue_create pb_issue_close pb_issue_reopen
        pb_issue_view pb_issue_comment pb_issue_assign
        pb_board_summary pb_board_status pb_board_move pb_board_add
        pb_provider_info
    )
    local fn missing=()
    for fn in "${required_fns[@]}"; do
        if ! declare -F "$fn" >/dev/null 2>&1; then
            missing+=("$fn")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        _pb_die "Provider missing required functions: ${missing[*]}"
    fi
}

# ---- Default Stubs for Optional Functions ----
# Providers may override these. Default stubs return "not supported" cleanly
# so the router never hits an undefined function error.

pb_board_label_add() {
    : "${1:?Issue identifier required}"
    : "${2:?Label required}"
    _pb_die "pb_board_label_add not supported by this provider"
}

pb_board_label_remove() {
    : "${1:?Issue identifier required}"
    : "${2:?Label required}"
    _pb_die "pb_board_label_remove not supported by this provider"
}

pb_board_metrics() {
    _pb_die "pb_board_metrics not supported by this provider"
}

pb_issue_timeline() {
    : "${1:?Issue identifier required}"
    _pb_die "pb_issue_timeline not supported by this provider"
}

pb_sprint_list() {
    _pb_die "pb_sprint_list not supported by this provider (configure sprint settings)"
}

pb_sprint_assign() {
    _pb_die "pb_sprint_assign not supported by this provider (configure sprint settings)"
}

pb_branch_create() {
    _pb_die "pb_branch_create not supported by this provider"
}

pb_branch_list() {
    _pb_die "pb_branch_list not supported by this provider"
}

# ---- Command Router ----
# Routes CLI invocations to provider functions.
# Usage: _pb_route <group> <command> [args...]

_pb_route() {
    local group="${1:-help}"
    local cmd="${2:-}"
    shift 2 2>/dev/null || true

    case "$group" in
        issue)
            case "$cmd" in
                list)    pb_issue_list "$@" ;;
                create)  pb_issue_create "$@" ;;
                close)   _pb_closure_guard "$@" && pb_issue_close "$@" ;;
                reopen)  pb_issue_reopen "$@" ;;
                view)    pb_issue_view "$@" ;;
                comment) pb_issue_comment "$@" ;;
                assign)  pb_issue_assign "$@" ;;
                *)       _pb_die "Unknown issue command: $cmd. Use: list|create|close|reopen|view|comment|assign" ;;
            esac
            ;;
        board)
            case "$cmd" in
                summary) pb_board_summary "$@" ;;
                status)  pb_board_status "$@" ;;
                move)    pb_board_move "$@" ;;
                add)     pb_board_add "$@" ;;
                approve)      pb_board_approve "$@" ;;
                blocked)      pb_board_label_add "$1" "blocked" "${@:2}" ;;
                unblock)      pb_board_label_remove "$1" "blocked" "${@:2}" ;;
                metrics)      pb_board_metrics "$@" ;;
                *)            _pb_die "Unknown board command: $cmd. Use: summary|status|move|add|approve|blocked|unblock|metrics" ;;
            esac
            ;;
        sprint)
            case "$cmd" in
                list)    pb_sprint_list "$@" ;;
                assign)  pb_sprint_assign "$@" ;;
                *)       _pb_die "Unknown sprint command: $cmd. Use: list|assign" ;;
            esac
            ;;
        branch)
            case "$cmd" in
                create)  pb_branch_create "$@" ;;
                list)    pb_branch_list "$@" ;;
                *)       _pb_die "Unknown branch command: $cmd. Use: create|list" ;;
            esac
            ;;
        provider)
            case "$cmd" in
                info)    pb_provider_info "$@" ;;
                *)       _pb_die "Unknown provider command: $cmd. Use: info" ;;
            esac
            ;;
        help|--help|-h)
            cat <<'USAGE'
project-board provider CLI

Usage: <provider>.sh <group> <command> [args...]

Groups:
  issue     list|create|close|reopen|view|comment|assign
  board     summary|status|move|add|approve|blocked|unblock|metrics
  sprint    list|assign
  branch    create|list
  provider  info

Examples:
  ./github.sh issue list --priority p1-high
  ./github.sh issue create "Fix login bug" --labels "bug,priority:p1-high"
  ./github.sh board move 42 progress
  ./github.sh sprint list
  ./github.sh provider info
USAGE
            ;;
        *)
            _pb_die "Unknown command group: $group. Use: issue|board|sprint|branch|provider|help"
            ;;
    esac
}
