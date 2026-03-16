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

# ---- Provider Interface ----
# Each provider MUST implement these functions:
#
# Required:
#   pb_issue_list [--priority P] [--area A] [--state S]
#   pb_issue_create TITLE [--labels L] [--body B]
#   pb_issue_close NUMBER [--comment C]
#   pb_issue_reopen NUMBER
#   pb_issue_view NUMBER [--json FIELDS]
#   pb_issue_comment NUMBER BODY
#   pb_issue_assign NUMBER USER
#   pb_board_summary
#   pb_board_status NUMBER
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
                close)   pb_issue_close "$@" ;;
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
                approve) pb_board_approve "$@" ;;
                *)       _pb_die "Unknown board command: $cmd. Use: summary|status|move|add|approve" ;;
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
  board     summary|status|move|add|approve
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
