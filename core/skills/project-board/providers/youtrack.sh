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

# ---- Input validation ----

_yt_validate_id() {
    local id="$1"
    if [[ ! "$id" =~ ^[A-Za-z][A-Za-z0-9_]+-[0-9]+$ ]]; then
        _pb_die "Invalid YouTrack issue ID format: $id (expected PROJECT-123)"
    fi
}

# ---- URL helpers ----

_yt_issue_url() { echo "${CC_YOUTRACK_URL}/issue/$1"; }

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
    encoded_query=$(_CC_QUERY="$query" python3 -c "import urllib.parse, os; print(urllib.parse.quote(os.environ['_CC_QUERY']))")

    _yt_api GET "/issues?query=${encoded_query}&fields=idReadable,summary,customFields(name,value(name)),reporter(login)&\$top=50"
}

pb_issue_create() {
    local title="" labels="" body="" assignee=""
    title="${1:-}"; shift 2>/dev/null || true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --labels)   labels="$2"; shift 2 ;;
            --body)     body="$2"; shift 2 ;;
            --assignee) assignee="$2"; shift 2 ;;
            *)          shift ;;
        esac
    done

    [[ -z "$title" ]] && _pb_die "Title required"

    local payload
    payload=$(_CC_PROJECT="$CC_YOUTRACK_PROJECT" _CC_TITLE="$title" _CC_BODY="${body:-}" python3 -c "
import json, os
data = {
    'project': {'id': os.environ['_CC_PROJECT']},
    'summary': os.environ['_CC_TITLE'],
    'description': os.environ['_CC_BODY']
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

    # Assign if provided
    if [[ -n "$assignee" ]]; then
        _yt_api POST "/issues/${issue_id}" \
            -d "{\"customFields\":[{\"name\":\"Assignee\",\"\$type\":\"SingleUserIssueCustomField\",\"value\":{\"login\":\"$assignee\"}}]}" >/dev/null 2>&1 || true
    fi

    echo "{\"id\":\"$issue_id\",\"url\":\"$(_yt_issue_url "$issue_id")\"}"
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

    local done_status
    done_status=$(_yt_status_name "done")
    _yt_api POST "/issues/${issue_id}" \
        -d "{\"customFields\":[{\"name\":\"State\",\"\$type\":\"StateIssueCustomField\",\"value\":{\"name\":\"${done_status}\"}}]}" >/dev/null

    _pb_success "Issue $issue_id closed"
}

pb_issue_reopen() {
    local issue_id="${1:?Issue ID required}"

    local todo_status
    todo_status=$(_yt_status_name "todo")
    _yt_api POST "/issues/${issue_id}" \
        -d "{\"customFields\":[{\"name\":\"State\",\"\$type\":\"StateIssueCustomField\",\"value\":{\"name\":\"${todo_status}\"}}]}" >/dev/null

    _pb_success "Issue $issue_id reopened"
}

pb_issue_view() {
    local issue_id="${1:?Issue ID required}"
    local url
    url=$(_yt_issue_url "$issue_id")
    _yt_api GET "/issues/${issue_id}?fields=idReadable,summary,description,customFields(name,value(name)),reporter(login),tags(name)" | _CC_URL="$url" python3 -c "
import json, sys, os
data = json.load(sys.stdin)
data['url'] = os.environ['_CC_URL']
json.dump(data, sys.stdout, indent=2)
"
}

pb_issue_comment() {
    local issue_id="${1:?Issue ID required}"
    local body="${2:?Comment body required}"

    local payload
    payload=$(_CC_BODY="$body" python3 -c "
import json, os; print(json.dumps({'text': os.environ['_CC_BODY']}))")
    _yt_api POST "/issues/${issue_id}/comments" \
        -d "$payload" >/dev/null

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

    echo "$result" | _CC_BASE_URL="${CC_YOUTRACK_URL}" _CC_PROJECT="${CC_YOUTRACK_PROJECT}" python3 -c "
import json, sys, os
from collections import Counter
data = json.load(sys.stdin)
counts = Counter()
for issue in data:
    state = 'Unknown'
    for cf in issue.get('customFields', []):
        if cf.get('name') == 'State' and cf.get('value'):
            state = cf['value'].get('name', 'Unknown')
    counts[state] += 1
base_url = os.environ['_CC_BASE_URL']
project = os.environ['_CC_PROJECT']
result = {
    'url': f'{base_url}/issues/{project}',
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

    echo "$result" | _CC_BASE_URL="${CC_YOUTRACK_URL}" python3 -c "
import json, sys, os
data = json.load(sys.stdin)
base_url = os.environ['_CC_BASE_URL']
state = 'Unknown'
assignee = 'Unassigned'
for cf in data.get('customFields', []):
    if cf.get('name') == 'State' and cf.get('value'):
        state = cf['value'].get('name', 'Unknown')
    if cf.get('name') == 'Assignee' and cf.get('value'):
        assignee = cf['value'].get('name', cf['value'].get('login', 'Unassigned'))
issue_id = data.get('idReadable', '')
json.dump({
    'id': issue_id,
    'status': state,
    'assignee': assignee,
    'url': f'{base_url}/issue/{issue_id}'
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

pb_board_approve() {
    local issue_id="${1:?Issue ID required}"
    shift
    local comment=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --comment) comment="$2"; shift 2 ;;
            *)         shift ;;
        esac
    done

    # Verify issue is in testing status
    local result current_status
    result=$(pb_issue_view "$issue_id")
    current_status=$(echo "$result" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for cf in data.get('customFields', []):
    if cf.get('name') == 'State' and cf.get('value'):
        print(cf['value'].get('name', '')); break
" 2>/dev/null)

    local testing_status
    testing_status=$(_yt_status_name "testing")
    if [[ "$current_status" != "$testing_status" ]]; then
        _pb_die "Cannot approve $issue_id — current status is '$current_status', expected '$testing_status'"
    fi

    # Add approval comment and transition to Done
    local approval_comment="Approved."
    [[ -n "$comment" ]] && approval_comment="Approved: ${comment}"
    pb_issue_comment "$issue_id" "$approval_comment"

    local done_status
    done_status=$(_yt_status_name "done")
    _yt_api POST "/issues/${issue_id}" \
        -d "{\"customFields\":[{\"name\":\"State\",\"\$type\":\"StateIssueCustomField\",\"value\":{\"name\":\"$done_status\"}}]}" >/dev/null

    _pb_success "Issue $issue_id approved and moved to $done_status"
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
    sprint_id=$(echo "$sprints" | _CC_SPRINT="$sprint_name" python3 -c "
import json, sys, os
target = os.environ['_CC_SPRINT']
for s in json.load(sys.stdin):
    if s['name'] == target:
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
_pb_validate_provider
_pb_route "$@"
