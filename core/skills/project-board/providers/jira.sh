#!/bin/bash
# shellcheck disable=SC2034
# =============================================================================
# jira.sh — Jira Cloud/Data Center provider for project-board skill
#
# Implements the project-board provider interface using Jira REST API v3.
# Supports both Jira Cloud (Atlassian) and Jira Data Center (on-prem).
#
# Prerequisites: curl, jq (or python3 fallback)
# Config: CC_JIRA_URL, CC_JIRA_PROJECT, CC_JIRA_EMAIL, CC_JIRA_TOKEN
#
# Auth: Basic Auth (email:api_token) for Cloud, Bearer token for Data Center.
#       Set CC_JIRA_AUTH_TYPE="bearer" for Data Center.
#
# Usage: ./jira.sh <group> <command> [args...]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../_provider-lib.sh
source "$SCRIPT_DIR/../_provider-lib.sh"

# ---- Configuration ----

_jira_require_config() {
    local missing=()
    [[ -z "${CC_JIRA_URL:-}" ]] && missing+=("CC_JIRA_URL")
    [[ -z "${CC_JIRA_PROJECT:-}" ]] && missing+=("CC_JIRA_PROJECT")
    [[ -z "${CC_JIRA_TOKEN:-}" ]] && missing+=("CC_JIRA_TOKEN")
    if [[ ${#missing[@]} -gt 0 ]]; then
        _pb_die "Missing Jira config: ${missing[*]}. Set in cognitive-core.conf"
    fi
}

# ---- HTTP helpers ----

_jira_auth_header() {
    if [[ "${CC_JIRA_AUTH_TYPE:-basic}" == "bearer" ]]; then
        echo "Authorization: Bearer ${CC_JIRA_TOKEN}"
    else
        local encoded
        encoded=$(printf '%s:%s' "${CC_JIRA_EMAIL:-}" "$CC_JIRA_TOKEN" | base64)
        echo "Authorization: Basic ${encoded}"
    fi
}

_jira_api() {
    local method="$1" endpoint="$2"
    shift 2
    local url="${CC_JIRA_URL}/rest/api/3${endpoint}"
    local auth
    auth=$(_jira_auth_header)

    local response http_code
    response=$(curl -s -w "\n%{http_code}" \
        -X "$method" \
        -H "$auth" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        "$@" \
        "$url")

    http_code=$(echo "$response" | tail -1)
    local body
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" -ge 400 ]]; then
        _pb_error "Jira API error ($http_code): $body"
        return 1
    fi
    echo "$body"
}

_jira_agile_api() {
    local method="$1" endpoint="$2"
    shift 2
    local url="${CC_JIRA_URL}/rest/agile/1.0${endpoint}"
    local auth
    auth=$(_jira_auth_header)

    curl -s \
        -X "$method" \
        -H "$auth" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        "$@" \
        "$url"
}

# ---- Status Mapping ----
# Maps cognitive-core canonical status keys to Jira status names.
# Override via CC_JIRA_STATUS_MAP in cognitive-core.conf.
# Format: "roadmap=To Do|backlog=Backlog|todo=Selected|progress=In Progress|testing=In Review|done=Done|canceled=Canceled"

_jira_status_name() {
    local key="$1"
    local map="${CC_JIRA_STATUS_MAP:-roadmap=To Do|backlog=Backlog|todo=To Do|progress=In Progress|testing=In Review|done=Done|canceled=Canceled}"

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

# ---- Priority Mapping ----

_jira_priority_name() {
    local key="$1"
    case "$key" in
        p0-critical|p0) echo "Highest" ;;
        p1-high|p1)     echo "High" ;;
        p2-medium|p2)   echo "Medium" ;;
        p3-low|p3)      echo "Low" ;;
        *)              echo "Medium" ;;
    esac
}

# ---- Transition helpers ----

_jira_get_transitions() {
    local issue_key="$1"
    _jira_api GET "/issue/${issue_key}/transitions"
}

_jira_do_transition() {
    local issue_key="$1" target_status="$2"

    local transitions
    transitions=$(_jira_get_transitions "$issue_key") || return 1

    local transition_id
    transition_id=$(echo "$transitions" | python3 -c "
import json, sys
data = json.load(sys.stdin)
target = '$target_status'
for t in data.get('transitions', []):
    if t['to']['name'].lower() == target.lower():
        print(t['id'])
        sys.exit(0)
# Try partial match
for t in data.get('transitions', []):
    if target.lower() in t['to']['name'].lower():
        print(t['id'])
        sys.exit(0)
sys.exit(1)
" 2>/dev/null) || _pb_die "No transition to '$target_status' available from current status"

    _jira_api POST "/issue/${issue_key}/transitions" \
        -d "{\"transition\":{\"id\":\"$transition_id\"}}" >/dev/null
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

    local jql="project = ${CC_JIRA_PROJECT}"
    if [[ "$state" == "open" ]]; then
        jql+=" AND statusCategory != Done"
    elif [[ "$state" == "closed" ]]; then
        jql+=" AND statusCategory = Done"
    fi
    if [[ -n "$priority" ]]; then
        local jira_priority
        jira_priority=$(_jira_priority_name "$priority")
        jql+=" AND priority = \"$jira_priority\""
    fi
    if [[ -n "$area" ]]; then
        jql+=" AND labels = \"area:$area\""
    fi
    jql+=" ORDER BY priority ASC, created DESC"

    _jira_api GET "/search?jql=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$jql'))")&fields=summary,status,priority,assignee,labels&maxResults=50"
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

    # Build labels array
    local labels_json="[]"
    if [[ -n "$labels" ]]; then
        labels_json=$(echo "$labels" | python3 -c "
import sys, json
labels = [l.strip() for l in sys.stdin.read().split(',')]
print(json.dumps(labels))
")
    fi

    # Build description in ADF format
    local description_json="null"
    if [[ -n "$body" ]]; then
        description_json=$(python3 -c "
import json
print(json.dumps({
    'type': 'doc',
    'version': 1,
    'content': [{'type': 'paragraph', 'content': [{'type': 'text', 'text': '''$body'''}]}]
}))
")
    fi

    local payload
    payload=$(python3 -c "
import json
data = {
    'fields': {
        'project': {'key': '${CC_JIRA_PROJECT}'},
        'summary': '''$title''',
        'issuetype': {'name': 'Task'},
        'labels': $labels_json
    }
}
desc = $description_json
if desc:
    data['fields']['description'] = desc
assignee = '''${assignee}'''
if assignee:
    data['fields']['assignee'] = {'accountId': assignee}
print(json.dumps(data))
")

    local result
    result=$(_jira_api POST "/issue" -d "$payload") || return 1

    local issue_key
    issue_key=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin)['key'])")
    local issue_id
    issue_id=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

    echo "{\"key\":\"$issue_key\",\"id\":\"$issue_id\",\"url\":\"${CC_JIRA_URL}/browse/$issue_key\"}"
}

pb_issue_close() {
    local issue_key="${1:?Issue key required}"
    shift
    local comment=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --comment) comment="$2"; shift 2 ;;
            *)         shift ;;
        esac
    done

    if [[ -n "$comment" ]]; then
        pb_issue_comment "$issue_key" "$comment"
    fi

    _jira_do_transition "$issue_key" "Done"
    _pb_success "Issue $issue_key closed"
}

pb_issue_reopen() {
    local issue_key="${1:?Issue key required}"
    _jira_do_transition "$issue_key" "To Do"
    _pb_success "Issue $issue_key reopened"
}

pb_issue_view() {
    local issue_key="${1:?Issue key required}"
    shift
    local fields="summary,status,priority,assignee,labels,description,comment"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json) fields="$2"; shift 2 ;;
            *)      shift ;;
        esac
    done

    _jira_api GET "/issue/${issue_key}?fields=${fields}"
}

pb_issue_comment() {
    local issue_key="${1:?Issue key required}"
    local body="${2:?Comment body required}"

    local payload
    payload=$(python3 -c "
import json
print(json.dumps({
    'body': {
        'type': 'doc',
        'version': 1,
        'content': [{'type': 'paragraph', 'content': [{'type': 'text', 'text': '''$body'''}]}]
    }
}))
")

    _jira_api POST "/issue/${issue_key}/comment" -d "$payload" >/dev/null
    _pb_success "Comment added to $issue_key"
}

pb_issue_assign() {
    local issue_key="${1:?Issue key required}"
    local user="${2:?Username or account ID required}"

    # Try accountId first (Jira Cloud), fall back to name
    _jira_api PUT "/issue/${issue_key}/assignee" \
        -d "{\"accountId\":\"$user\"}" 2>/dev/null || \
    _jira_api PUT "/issue/${issue_key}/assignee" \
        -d "{\"name\":\"$user\"}" 2>/dev/null || \
        _pb_die "Could not assign $user to $issue_key"

    _pb_success "Assigned $user to $issue_key"
}

# =============================================================================
# BOARD COMMANDS
# =============================================================================

pb_board_summary() {
    local jql="project = ${CC_JIRA_PROJECT} AND statusCategory != Done"
    local result
    result=$(_jira_api GET "/search?jql=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$jql'))")&fields=status&maxResults=200")

    echo "$result" | python3 -c "
import json, sys
from collections import Counter
data = json.load(sys.stdin)
counts = Counter(
    issue['fields']['status']['name']
    for issue in data.get('issues', [])
)
result = {
    'url': '${CC_JIRA_URL}/jira/software/projects/${CC_JIRA_PROJECT}/board',
    'columns': dict(sorted(counts.items())),
    'total': data.get('total', 0)
}
json.dump(result, sys.stdout, indent=2)
"
}

pb_board_status() {
    local issue_key="${1:?Issue key required}"
    local result
    result=$(_jira_api GET "/issue/${issue_key}?fields=status,assignee")

    echo "$result" | python3 -c "
import json, sys
data = json.load(sys.stdin)
json.dump({
    'key': data['key'],
    'status': data['fields']['status']['name'],
    'status_category': data['fields']['status']['statusCategory']['name'],
    'assignee': data['fields'].get('assignee', {}).get('displayName', 'Unassigned')
}, sys.stdout, indent=2)
"
}

pb_board_move() {
    local issue_key="${1:?Issue key required}"
    local status_key="${2:?Status key required}"

    local target_status
    target_status=$(_jira_status_name "$status_key")

    _jira_do_transition "$issue_key" "$target_status"
    _pb_success "Issue $issue_key moved to $target_status"
}

pb_board_add() {
    # In Jira, issues are automatically on the board when they belong to the project.
    # This is a no-op for Jira, but we return success for interface compatibility.
    local issue_key="${1:?Issue key required}"
    _pb_success "Issue $issue_key is on the board (Jira: automatic)"
}

pb_board_approve() {
    local issue_key="${1:?Issue key required}"
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
    result=$(_jira_api GET "/issue/${issue_key}?fields=status,comment")
    current_status=$(echo "$result" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data['fields']['status']['name'])
" 2>/dev/null)

    local testing_status
    testing_status=$(_jira_status_name "testing")
    if [[ "$current_status" != "$testing_status" ]]; then
        _pb_die "Cannot approve $issue_key — current status is '$current_status', expected '$testing_status'"
    fi

    # Verify evidence exists (at least one comment)
    local comment_count
    comment_count=$(echo "$result" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(len(data['fields'].get('comment', {}).get('comments', [])))
" 2>/dev/null)

    if [[ "$comment_count" -eq 0 ]]; then
        _pb_die "Cannot approve $issue_key — no verification evidence found (0 comments)"
    fi

    # Add approval comment and transition to Done
    local approval_comment="Approved."
    [[ -n "$comment" ]] && approval_comment="Approved: ${comment}"
    pb_issue_comment "$issue_key" "$approval_comment"
    _jira_do_transition "$issue_key" "Done"

    _pb_success "Issue $issue_key approved and moved to Done"
}

# =============================================================================
# SPRINT COMMANDS
# =============================================================================

pb_sprint_list() {
    if [[ -z "${CC_JIRA_BOARD_ID:-}" ]]; then
        _pb_die "CC_JIRA_BOARD_ID required for sprint operations. Find it: ${CC_JIRA_URL}/rest/agile/1.0/board?projectKeyOrId=${CC_JIRA_PROJECT}"
    fi

    local state="active,future"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all) state="active,future,closed"; shift ;;
            *)     shift ;;
        esac
    done

    _jira_agile_api GET "/board/${CC_JIRA_BOARD_ID}/sprint?state=${state}"
}

pb_sprint_assign() {
    local sprint_name="${1:?Sprint name required}"
    shift
    [[ $# -eq 0 ]] && _pb_die "At least one issue key required"

    if [[ -z "${CC_JIRA_BOARD_ID:-}" ]]; then
        _pb_die "CC_JIRA_BOARD_ID required for sprint operations"
    fi

    # Find sprint ID by name
    local sprints
    sprints=$(pb_sprint_list --all)
    local sprint_id
    sprint_id=$(echo "$sprints" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for s in data.get('values', []):
    if s['name'] == '$sprint_name':
        print(s['id'])
        sys.exit(0)
sys.exit(1)
" 2>/dev/null) || _pb_die "Sprint '$sprint_name' not found"

    # Move issues to sprint
    local issue_keys=()
    for key in "$@"; do
        issue_keys+=("\"$key\"")
    done
    local keys_json
    keys_json=$(IFS=,; echo "[${issue_keys[*]}]")

    _jira_agile_api POST "/sprint/${sprint_id}/issue" \
        -d "{\"issues\":$keys_json}" >/dev/null

    _pb_success "Assigned ${#issue_keys[@]} issues to sprint '$sprint_name'"
}

# =============================================================================
# BRANCH COMMANDS (Git-level, not Jira-specific)
# =============================================================================

pb_branch_create() {
    local issue_key="${1:?Issue key required}"
    local branch_type="${2:-feature}"
    local slug="${3:-}"
    local base="${CC_BRANCH_BASE:-main}"

    local branch_name="${branch_type}/${issue_key}-${slug}"

    if git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
        echo "{\"branch\":\"$branch_name\",\"created\":false,\"message\":\"Branch already exists\"}"
        return 0
    fi

    git checkout -b "$branch_name" "$base" 2>/dev/null
    echo "{\"branch\":\"$branch_name\",\"created\":true,\"base\":\"$base\"}"
}

pb_branch_list() {
    local issue_key="${1:?Issue key required}"
    git branch --list "*${issue_key}*" 2>/dev/null | sed 's/^[* ]*//' || echo "[]"
}

# =============================================================================
# PROVIDER INFO
# =============================================================================

pb_provider_info() {
    cat <<JSON
{
    "provider": "jira",
    "name": "Jira Cloud/Data Center",
    "url": "${CC_JIRA_URL:-}",
    "project": "${CC_JIRA_PROJECT:-}",
    "auth_type": "${CC_JIRA_AUTH_TYPE:-basic}",
    "board_url": "${CC_JIRA_URL:-}/jira/software/projects/${CC_JIRA_PROJECT:-}/board",
    "capabilities": ["issues", "board", "sprints", "labels"],
    "cli": "curl"
}
JSON
}

# =============================================================================
# MAIN
# =============================================================================

_pb_load_config
_jira_require_config
_pb_validate_provider
_pb_route "$@"
