#!/bin/bash
# shellcheck disable=SC2034
# =============================================================================
# youtrack.sh — YouTrack provider for project-board skill
#
# Implements the project-board provider interface using YouTrack REST API.
# Supports YouTrack Cloud and YouTrack Standalone (on-prem).
#
# Prerequisites: curl, python3
# Config: CC_YOUTRACK_URL, CC_YOUTRACK_PROJECT, CC_YOUTRACK_TOKEN
#
# API Reference: https://www.jetbrains.com/help/youtrack/devportal/api-reference.html
#
# Usage: ./youtrack.sh <group> <command> [args...]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../_provider-lib.sh
source "$SCRIPT_DIR/../_provider-lib.sh"

# ---- Configuration ----

_yt_require_config() {
    local missing=()
    [[ -z "${CC_YOUTRACK_URL:-}" ]] && missing+=("CC_YOUTRACK_URL")
    [[ -z "${CC_YOUTRACK_PROJECT:-}" ]] && missing+=("CC_YOUTRACK_PROJECT")
    [[ -z "${CC_YOUTRACK_TOKEN:-}" ]] && missing+=("CC_YOUTRACK_TOKEN")
    if [[ ${#missing[@]} -gt 0 ]]; then
        _pb_die "Missing YouTrack config: ${missing[*]}. Set in cognitive-core.conf"
    fi
}

# ---- HTTP helpers ----

_yt_api() {
    local method="$1" endpoint="$2"
    shift 2
    local url="${CC_YOUTRACK_URL}/api${endpoint}"

    local response http_code
    response=$(curl -s -w "\n%{http_code}" \
        -X "$method" \
        -H "Authorization: Bearer ${CC_YOUTRACK_TOKEN}" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        "$@" \
        "$url")

    http_code=$(echo "$response" | tail -1)
    local body
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" -ge 400 ]]; then
        _pb_error "YouTrack API error ($http_code): $body"
        return 1
    fi
    echo "$body"
}

# ---- Status Mapping ----

_yt_status_name() {
    local key="$1"
    local map="${CC_YOUTRACK_STATUS_MAP:-roadmap=No State|backlog=Open|todo=To Do|progress=In Progress|testing=To Verify|done=Done|canceled=Canceled}"

    local pair
    IFS='|' read -ra pairs <<< "$map"
    for pair in "${pairs[@]}"; do
        local k="${pair%%=*}"
        local v="${pair#*=}"
        if [[ "$k" == "$key" ]]; then
            echo "$v"
            return 0
        fi
    done
    echo "$key"
}

# =============================================================================
# ISSUE COMMANDS
# =============================================================================

pb_issue_list() {
    local priority="" area="" state="open"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --priority) priority="$2"; shift 2 ;;
            --area)     area="$2"; shift 2 ;;
            --state)    state="$2"; shift 2 ;;
            *)          shift ;;
        esac
    done

    local query="project: ${CC_YOUTRACK_PROJECT}"
    if [[ "$state" == "open" ]]; then
        query+=" State: -Resolved,-Done,-Canceled"
    elif [[ "$state" == "closed" ]]; then
        query+=" State: Resolved,Done"
    fi
    if [[ -n "$priority" ]]; then
        query+=" Priority: $priority"
    fi

    local encoded_query
    encoded_query=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$query'))")

    _yt_api GET "/issues?query=${encoded_query}&fields=idReadable,summary,customFields(name,value(name)),reporter(login)&\$top=50"
}

pb_issue_create() {
    local title="" labels="" body=""
    title="${1:-}"; shift 2>/dev/null || true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --labels) labels="$2"; shift 2 ;;
            --body)   body="$2"; shift 2 ;;
            *)        shift ;;
        esac
    done

    [[ -z "$title" ]] && _pb_die "Title required"

    local payload
    payload=$(python3 -c "
import json
data = {
    'project': {'id': '${CC_YOUTRACK_PROJECT}'},
    'summary': '''$title''',
    'description': '''${body:-}'''
}
print(json.dumps(data))
")

    local result
    result=$(_yt_api POST "/issues?fields=idReadable,id" -d "$payload") || return 1

    local issue_id
    issue_id=$(echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('idReadable', d.get('id','')))")

    # Add tags/labels if provided
    if [[ -n "$labels" ]]; then
        IFS=',' read -ra label_arr <<< "$labels"
        for label in "${label_arr[@]}"; do
            label=$(echo "$label" | xargs)  # trim whitespace
            _yt_api POST "/issues/${issue_id}/tags?fields=id" \
                -d "{\"name\":\"$label\"}" 2>/dev/null || true
        done
    fi

    echo "{\"id\":\"$issue_id\",\"url\":\"${CC_YOUTRACK_URL}/issue/$issue_id\"}"
}

pb_issue_close() {
    local issue_id="${1:?Issue ID required}"
    shift
    local comment=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --comment) comment="$2"; shift 2 ;;
            *)         shift ;;
        esac
    done

    if [[ -n "$comment" ]]; then
        pb_issue_comment "$issue_id" "$comment"
    fi

    # Update State custom field to Done
    _yt_api POST "/issues/${issue_id}" \
        -d "{\"customFields\":[{\"name\":\"State\",\"\$type\":\"StateIssueCustomField\",\"value\":{\"name\":\"Done\"}}]}" >/dev/null

    _pb_success "Issue $issue_id closed"
}

pb_issue_reopen() {
    local issue_id="${1:?Issue ID required}"

    _yt_api POST "/issues/${issue_id}" \
        -d "{\"customFields\":[{\"name\":\"State\",\"\$type\":\"StateIssueCustomField\",\"value\":{\"name\":\"Open\"}}]}" >/dev/null

    _pb_success "Issue $issue_id reopened"
}

pb_issue_view() {
    local issue_id="${1:?Issue ID required}"
    _yt_api GET "/issues/${issue_id}?fields=idReadable,summary,description,customFields(name,value(name)),reporter(login),tags(name)"
}

pb_issue_comment() {
    local issue_id="${1:?Issue ID required}"
    local body="${2:?Comment body required}"

    _yt_api POST "/issues/${issue_id}/comments" \
        -d "{\"text\":\"$body\"}" >/dev/null

    _pb_success "Comment added to $issue_id"
}

pb_issue_assign() {
    local issue_id="${1:?Issue ID required}"
    local user="${2:?Username required}"

    _yt_api POST "/issues/${issue_id}" \
        -d "{\"customFields\":[{\"name\":\"Assignee\",\"\$type\":\"SingleUserIssueCustomField\",\"value\":{\"login\":\"$user\"}}]}" >/dev/null

    _pb_success "Assigned $user to $issue_id"
}

# =============================================================================
# BOARD COMMANDS
# =============================================================================

pb_board_summary() {
    local result
    result=$(pb_issue_list --state open)

    echo "$result" | python3 -c "
import json, sys
from collections import Counter
data = json.load(sys.stdin)
counts = Counter()
for issue in data:
    state = 'Unknown'
    for cf in issue.get('customFields', []):
        if cf.get('name') == 'State' and cf.get('value'):
            state = cf['value'].get('name', 'Unknown')
    counts[state] += 1
result = {
    'url': '${CC_YOUTRACK_URL}/issues/${CC_YOUTRACK_PROJECT}',
    'columns': dict(sorted(counts.items())),
    'total': sum(counts.values())
}
json.dump(result, sys.stdout, indent=2)
"
}

pb_board_status() {
    local issue_id="${1:?Issue ID required}"
    local result
    result=$(pb_issue_view "$issue_id")

    echo "$result" | python3 -c "
import json, sys
data = json.load(sys.stdin)
state = 'Unknown'
assignee = 'Unassigned'
for cf in data.get('customFields', []):
    if cf.get('name') == 'State' and cf.get('value'):
        state = cf['value'].get('name', 'Unknown')
    if cf.get('name') == 'Assignee' and cf.get('value'):
        assignee = cf['value'].get('name', cf['value'].get('login', 'Unassigned'))
json.dump({
    'id': data.get('idReadable', ''),
    'status': state,
    'assignee': assignee
}, sys.stdout, indent=2)
"
}

pb_board_move() {
    local issue_id="${1:?Issue ID required}"
    local status_key="${2:?Status key required}"

    local target_status
    target_status=$(_yt_status_name "$status_key")

    _yt_api POST "/issues/${issue_id}" \
        -d "{\"customFields\":[{\"name\":\"State\",\"\$type\":\"StateIssueCustomField\",\"value\":{\"name\":\"$target_status\"}}]}" >/dev/null

    _pb_success "Issue $issue_id moved to $target_status"
}

pb_board_add() {
    local issue_id="${1:?Issue ID required}"
    _pb_success "Issue $issue_id is on the board (YouTrack: automatic for project issues)"
}

# =============================================================================
# SPRINT COMMANDS
# =============================================================================

pb_sprint_list() {
    if [[ -z "${CC_YOUTRACK_AGILE_ID:-}" ]]; then
        _pb_die "CC_YOUTRACK_AGILE_ID required for sprint operations. Find it: ${CC_YOUTRACK_URL}/api/agiles?fields=id,name"
    fi

    _yt_api GET "/agiles/${CC_YOUTRACK_AGILE_ID}/sprints?fields=id,name,start,finish,goal,unresolvedIssuesCount&\$top=20"
}

pb_sprint_assign() {
    local sprint_name="${1:?Sprint name required}"
    shift
    [[ $# -eq 0 ]] && _pb_die "At least one issue ID required"

    if [[ -z "${CC_YOUTRACK_AGILE_ID:-}" ]]; then
        _pb_die "CC_YOUTRACK_AGILE_ID required for sprint operations"
    fi

    # Find sprint ID
    local sprints
    sprints=$(pb_sprint_list)
    local sprint_id
    sprint_id=$(echo "$sprints" | python3 -c "
import json, sys
for s in json.load(sys.stdin):
    if s['name'] == '$sprint_name':
        print(s['id'])
        sys.exit(0)
sys.exit(1)
" 2>/dev/null) || _pb_die "Sprint '$sprint_name' not found"

    # Add issues to sprint
    for issue_id in "$@"; do
        _yt_api POST "/agiles/${CC_YOUTRACK_AGILE_ID}/sprints/${sprint_id}/issues" \
            -d "{\"id\":\"$issue_id\"}" 2>/dev/null || true
    done

    _pb_success "Assigned $# issues to sprint '$sprint_name'"
}

# =============================================================================
# BRANCH COMMANDS
# =============================================================================

pb_branch_create() {
    local issue_id="${1:?Issue ID required}"
    local branch_type="${2:-feature}"
    local slug="${3:-}"
    local base="${CC_BRANCH_BASE:-main}"

    local branch_name="${branch_type}/${issue_id}-${slug}"

    if git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
        echo "{\"branch\":\"$branch_name\",\"created\":false}"
        return 0
    fi

    git checkout -b "$branch_name" "$base" 2>/dev/null
    echo "{\"branch\":\"$branch_name\",\"created\":true,\"base\":\"$base\"}"
}

pb_branch_list() {
    local issue_id="${1:?Issue ID required}"
    git branch --list "*${issue_id}*" 2>/dev/null | sed 's/^[* ]*//' || echo "[]"
}

# =============================================================================
# PROVIDER INFO
# =============================================================================

pb_provider_info() {
    cat <<JSON
{
    "provider": "youtrack",
    "name": "YouTrack (JetBrains)",
    "url": "${CC_YOUTRACK_URL:-}",
    "project": "${CC_YOUTRACK_PROJECT:-}",
    "board_url": "${CC_YOUTRACK_URL:-}/issues/${CC_YOUTRACK_PROJECT:-}",
    "capabilities": ["issues", "board", "sprints", "tags"],
    "cli": "curl"
}
JSON
}

# =============================================================================
# MAIN
# =============================================================================

_pb_load_config
_yt_require_config
_pb_route "$@"
