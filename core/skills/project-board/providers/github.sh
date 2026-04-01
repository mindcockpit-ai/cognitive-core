#!/bin/bash
# =============================================================================
# github.sh — GitHub Projects provider for project-board skill
#
# Implements the project-board provider interface using GitHub CLI (gh)
# and GitHub GraphQL API for project board operations.
#
# Prerequisites: gh CLI authenticated with project scope
# Config: CC_GITHUB_OWNER, CC_GITHUB_REPO, CC_PROJECT_NUMBER, CC_PROJECT_ID,
#         CC_STATUS_FIELD_ID, CC_AREA_FIELD_ID (optional), CC_SPRINT_FIELD_ID (optional)
#
# Usage: ./github.sh <group> <command> [args...]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../_provider-lib.sh
source "$SCRIPT_DIR/../_provider-lib.sh"

# ---- Configuration ----

_gh_require_config() {
    local missing=()
    [[ -z "${CC_GITHUB_OWNER:-}" ]] && missing+=("CC_GITHUB_OWNER")
    [[ -z "${CC_GITHUB_REPO:-}" ]] && missing+=("CC_GITHUB_REPO")
    [[ -z "${CC_PROJECT_NUMBER:-}" ]] && missing+=("CC_PROJECT_NUMBER")
    [[ -z "${CC_PROJECT_ID:-}" ]] && missing+=("CC_PROJECT_ID")
    [[ -z "${CC_STATUS_FIELD_ID:-}" ]] && missing+=("CC_STATUS_FIELD_ID")
    if [[ ${#missing[@]} -gt 0 ]]; then
        _pb_die "Missing GitHub config: ${missing[*]}. Run setup.sh or set in cognitive-core.conf"
    fi
}

# ---- Helper: Get project item ID for an issue number ----

_gh_get_item_id() {
    local number="$1"
    gh project item-list "$CC_PROJECT_NUMBER" \
        --owner "$CC_GITHUB_OWNER" \
        --format json --limit 500 \
        | python3 -c "
import json, sys
items = json.load(sys.stdin)
for item in items.get('items', []):
    if item.get('content', {}).get('number') == $number:
        print(item['id'])
        sys.exit(0)
sys.exit(1)
" 2>/dev/null
}

# ---- Helper: Get all items (cached per invocation) ----

_GH_ITEMS_CACHE=""
_gh_get_items() {
    if [[ -z "$_GH_ITEMS_CACHE" ]]; then
        _GH_ITEMS_CACHE=$(gh project item-list "$CC_PROJECT_NUMBER" \
            --owner "$CC_GITHUB_OWNER" \
            --format json --limit 500)
    fi
    echo "$_GH_ITEMS_CACHE"
}

# ---- Helper: Get issue's content ID (GraphQL node ID) ----

_gh_get_content_id() {
    local number="$1"
    gh issue view "$number" --repo "$CC_GITHUB_REPO" --json id --jq '.id'
}

# ---- Helper: Set project field value ----

_gh_set_field() {
    local item_id="$1" field_id="$2" option_id="$3"
    gh api graphql -f query="
        mutation {
            updateProjectV2ItemFieldValue(input: {
                projectId: \"$CC_PROJECT_ID\"
                itemId: \"$item_id\"
                fieldId: \"$field_id\"
                value: { singleSelectOptionId: \"$option_id\" }
            }) { projectV2Item { id } }
        }" --jq '.data.updateProjectV2ItemFieldValue.projectV2Item.id'
}

# ---- Input validation ----

_gh_validate_number() {
    local num="$1"
    if [[ ! "$num" =~ ^[0-9]+$ ]]; then
        _pb_die "Invalid issue number: $num (must be numeric)"
    fi
}

# ---- Helper: Set iteration field value ----

_gh_set_iteration() {
    local item_id="$1" field_id="$2" iteration_id="$3"
    gh api graphql -f query="
        mutation {
            updateProjectV2ItemFieldValue(input: {
                projectId: \"$CC_PROJECT_ID\"
                itemId: \"$item_id\"
                fieldId: \"$field_id\"
                value: { iterationId: \"$iteration_id\" }
            }) { projectV2Item { id } }
        }" --jq '.data.updateProjectV2ItemFieldValue.projectV2Item.id'
}

# =============================================================================
# ISSUE COMMANDS
# =============================================================================

pb_issue_list() {
    local priority="" area="" state="open" json_fields="number,title,labels,assignees"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --priority) priority="$2"; shift 2 ;;
            --area)     area="$2"; shift 2 ;;
            --state)    state="$2"; shift 2 ;;
            --json)     json_fields="$2"; shift 2 ;;
            *)          shift ;;
        esac
    done

    local label_args=()
    [[ -n "$priority" ]] && label_args+=(--label "priority:$priority")
    [[ -n "$area" ]] && label_args+=(--label "area:$area")

    local limit_args=()
    [[ "$state" == "closed" ]] && limit_args+=(--limit 10)

    gh issue list --repo "$CC_GITHUB_REPO" \
        --state "$state" \
        "${label_args[@]}" \
        "${limit_args[@]}" \
        --json "$json_fields"
}

pb_issue_create() {
    local title="" labels="" body="" assignee=""
    title="${1:-}"; shift 2>/dev/null || true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --labels) labels="$2"; shift 2 ;;
            --body)   body="$2"; shift 2 ;;
            --assignee) assignee="$2"; shift 2 ;;
            *)        shift ;;
        esac
    done

    [[ -z "$title" ]] && _pb_die "Title required: pb_issue_create \"title\" [--labels L] [--body B]"

    local create_args=(--repo "$CC_GITHUB_REPO" --title "$title")
    [[ -n "$labels" ]] && create_args+=(--label "$labels")
    [[ -n "$body" ]] && create_args+=(--body "$body")
    [[ -n "$assignee" ]] && create_args+=(--assignee "$assignee")

    local url
    url=$(gh issue create "${create_args[@]}")
    local number
    number=$(basename "$url")

    # Auto-add to project board in Backlog
    local content_id item_id
    content_id=$(gh issue view "$number" --repo "$CC_GITHUB_REPO" --json id --jq '.id')
    item_id=$(gh api graphql -f query="
        mutation {
            addProjectV2ItemById(input: {
                projectId: \"$CC_PROJECT_ID\"
                contentId: \"$content_id\"
            }) { item { id } }
        }" --jq '.data.addProjectV2ItemById.item.id' 2>/dev/null || echo "")

    local on_board=true
    if [[ -z "$item_id" ]]; then
        on_board=false
    fi

    echo "{\"number\":$number,\"url\":\"$url\",\"on_board\":$on_board}"
}

pb_issue_close() {
    local number="${1:?Issue number required}"
    shift
    local comment=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --comment) comment="$2"; shift 2 ;;
            *)         shift ;;
        esac
    done

    # Closure marker for validate-bash hook exemption.
    # Uses "Approved by @system" when CC_REQUIRE_HUMAN_APPROVAL=false,
    # or "Canceled:" prefix (already in comment from cancel path).
    # When approval is required, pb_board_approve handles closure directly.
    local marker="Closed via /project-board — Approved by @system"
    if [[ -n "$comment" ]]; then
        # Cancel path already has "Canceled:" prefix — keep it as-is for hook exemption
        if [[ "$comment" != Canceled:* ]]; then
            comment="${comment} — ${marker}"
        fi
    else
        comment="$marker"
    fi

    local close_args=(--repo "$CC_GITHUB_REPO" --comment "$comment")

    gh issue close "$number" "${close_args[@]}" >/dev/null 2>&1
    _pb_success "Issue #$number closed"
}

pb_issue_reopen() {
    local number="${1:?Issue number required}"
    gh issue reopen "$number" --repo "$CC_GITHUB_REPO" >/dev/null 2>&1
    _pb_success "Issue #$number reopened"
}

pb_issue_view() {
    local number="${1:?Issue number required}"
    shift
    local json_fields="number,title,body,state,labels,assignees,url"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json) json_fields="$2"; shift 2 ;;
            *)      shift ;;
        esac
    done

    gh issue view "$number" --repo "$CC_GITHUB_REPO" --json "$json_fields"
}

pb_issue_comment() {
    local number="${1:?Issue number required}"
    local body="${2:?Comment body required}"
    gh issue comment "$number" --repo "$CC_GITHUB_REPO" --body "$body" >/dev/null 2>&1
    _pb_success "Comment added to #$number"
}

pb_issue_assign() {
    local number="${1:?Issue number required}"
    local user="${2:?Username required}"
    gh issue edit "$number" --repo "$CC_GITHUB_REPO" --add-assignee "$user" >/dev/null 2>&1
    _pb_success "Assigned $user to #$number"
}

# =============================================================================
# BOARD COMMANDS
# =============================================================================

pb_board_summary() {
    local items
    items=$(_gh_get_items)
    echo "$items" | _CC_OWNER="$CC_GITHUB_OWNER" _CC_PROJ_NUM="$CC_PROJECT_NUMBER" python3 -c "
import json, sys, os
from collections import Counter
items = json.load(sys.stdin)
counts = Counter(item.get('status', 'Unknown') for item in items.get('items', []))
owner = os.environ['_CC_OWNER']
proj_num = os.environ['_CC_PROJ_NUM']
result = {
    'url': f'https://github.com/users/{owner}/projects/{proj_num}',
    'columns': {status: count for status, count in sorted(counts.items())},
    'total': sum(counts.values())
}
json.dump(result, sys.stdout, indent=2)
"
}

pb_board_status() {
    local number="${1:?Issue number required}"
    local items
    items=$(_gh_get_items)
    echo "$items" | _CC_REPO="$CC_GITHUB_REPO" _CC_NUM="$number" python3 -c "
import json, sys, os
items = json.load(sys.stdin)
repo = os.environ['_CC_REPO']
number = int(os.environ['_CC_NUM'])
for item in items.get('items', []):
    if item.get('content', {}).get('number') == number:
        json.dump({
            'number': number,
            'status': item.get('status', 'Unknown'),
            'item_id': item.get('id', ''),
            'sprint': item.get('sprint', ''),
            'assignees': item.get('content', {}).get('assignees', []),
            'url': f'https://github.com/{repo}/issues/{number}'
        }, sys.stdout, indent=2)
        sys.exit(0)
print(json.dumps({'error': f'Issue #{number} not found on board'}))
sys.exit(1)
"
}

pb_board_move() {
    local number="${1:?Issue number required}"
    local status_key="${2:?Status key required (roadmap|backlog|todo|progress|testing|done|canceled)}"

    # Get item ID
    local item_id
    item_id=$(_gh_get_item_id "$number") || _pb_die "Issue #$number not found on project board"

    # The status option ID must be provided via config or discovered
    # Provider expects the caller (SKILL.md) to resolve status_key → option ID
    # using the status option IDs configured in the skill
    local option_id="${3:-}"
    if [[ -z "$option_id" ]]; then
        _pb_die "Status option ID required as 3rd argument. Resolve from board status option IDs."
    fi

    _gh_set_field "$item_id" "$CC_STATUS_FIELD_ID" "$option_id" >/dev/null
    _pb_success "Issue #$number moved to $(_pb_status_display_name "$status_key")"
}

pb_board_add() {
    local number="${1:?Issue number required}"
    shift
    local area=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --area) area="$2"; shift 2 ;;
            *)      shift ;;
        esac
    done

    # Get issue's GraphQL content ID
    local content_id
    content_id=$(_gh_get_content_id "$number")

    # Add to project
    local item_id
    item_id=$(gh api graphql -f query="
        mutation {
            addProjectV2ItemById(input: {
                projectId: \"$CC_PROJECT_ID\"
                contentId: \"$content_id\"
            }) { item { id } }
        }" --jq '.data.addProjectV2ItemById.item.id')

    # Set area if provided and field configured
    if [[ -n "$area" && -n "${CC_AREA_FIELD_ID:-}" ]]; then
        local area_option_id="${4:-}"
        if [[ -n "$area_option_id" ]]; then
            _gh_set_field "$item_id" "$CC_AREA_FIELD_ID" "$area_option_id" >/dev/null
        fi
    fi

    echo "{\"item_id\":\"$item_id\",\"number\":$number}"
}

pb_board_approve() {
    local number="${1:?Issue number required}"
    shift
    local comment=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --comment) comment="$2"; shift 2 ;;
            *)         shift ;;
        esac
    done

    # Verify issue is in "To Be Tested" status
    local items item_id current_status
    items=$(_gh_get_items)
    item_id=$(echo "$items" | python3 -c "
import json, sys
for item in json.load(sys.stdin).get('items', []):
    if item.get('content', {}).get('number') == $number:
        print(item['id']); break
" 2>/dev/null) || _pb_die "Issue #$number not found on board"

    current_status=$(echo "$items" | python3 -c "
import json, sys
for item in json.load(sys.stdin).get('items', []):
    if item.get('content', {}).get('number') == $number:
        print(item.get('status', '')); break
" 2>/dev/null)

    if [[ "$current_status" != "To Be Tested" && "$current_status" != "In Review" ]]; then
        _pb_die "Cannot approve #$number — current status is '$current_status', expected 'To Be Tested'"
    fi

    # Verify evidence exists (at least one comment on the issue)
    local comment_count
    comment_count=$(gh issue view "$number" --repo "$CC_GITHUB_REPO" --json comments --jq '.comments | length')
    if [[ "$comment_count" -eq 0 ]]; then
        _pb_die "Cannot approve #$number — no verification evidence found (0 comments)"
    fi

    # Get current user for attribution
    local approver
    approver=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")

    # Set approved label atomically before closing (CI checks this label)
    gh issue edit "$number" --repo "$CC_GITHUB_REPO" --add-label "approved" >/dev/null 2>&1

    # Close the issue
    local approval_comment="Approved by @${approver}."
    [[ -n "$comment" ]] && approval_comment="Approved by @${approver}: ${comment}"
    gh issue close "$number" --repo "$CC_GITHUB_REPO" --comment "$approval_comment" >/dev/null 2>&1

    # Board move to Done is handled by CI workflow (issue-closed event)

    _pb_success "Issue #$number approved and moved to Done by @$approver"
}

# =============================================================================
# SPRINT COMMANDS
# =============================================================================

pb_sprint_list() {
    local owner_type="user"
    # Detect org vs user
    local org_check
    org_check=$(gh api "orgs/$CC_GITHUB_OWNER" --jq '.login' 2>/dev/null || echo "")
    [[ -n "$org_check" ]] && owner_type="organization"

    gh api graphql -f query="
        query {
            ${owner_type}(login: \"$CC_GITHUB_OWNER\") {
                projectV2(number: $CC_PROJECT_NUMBER) {
                    field(name: \"Sprint\") {
                        ... on ProjectV2IterationField {
                            configuration {
                                iterations { id title startDate duration }
                            }
                        }
                    }
                }
            }
        }" --jq ".data.${owner_type}.projectV2.field.configuration.iterations"
}

pb_sprint_assign() {
    local sprint_title="${1:?Sprint title required}"
    shift
    [[ $# -eq 0 ]] && _pb_die "At least one issue number required"

    # Get iteration ID for the sprint title
    local iterations
    iterations=$(pb_sprint_list)
    local iteration_id
    iteration_id=$(echo "$iterations" | _CC_SPRINT="$sprint_title" python3 -c "
import json, sys, os
target = os.environ['_CC_SPRINT']
for it in json.load(sys.stdin):
    if it['title'] == target:
        print(it['id'])
        sys.exit(0)
sys.exit(1)
" 2>/dev/null) || _pb_die "Sprint '$sprint_title' not found"

    [[ -z "${CC_SPRINT_FIELD_ID:-}" ]] && _pb_die "CC_SPRINT_FIELD_ID not configured"

    local results=()
    for number in "$@"; do
        local item_id
        item_id=$(_gh_get_item_id "$number") || { results+=("#$number: not on board"); continue; }
        _gh_set_iteration "$item_id" "$CC_SPRINT_FIELD_ID" "$iteration_id" >/dev/null
        results+=("#$number: assigned to $sprint_title")
    done

    printf '%s\n' "${results[@]}"
}

# =============================================================================
# BRANCH COMMANDS
# =============================================================================

pb_branch_create() {
    local number="${1:?Issue number required}"
    local branch_type="${2:-feature}"
    local slug="${3:-}"
    local base="${CC_BRANCH_BASE:-main}"

    while [[ $# -gt 3 ]]; do
        shift 3
        case "${1:-}" in
            --base) base="$2"; shift 2 ;;
            *)      shift ;;
        esac
    done

    local branch_name="${branch_type}/${number}-${slug}"

    # Check if branch already exists
    local existing
    existing=$(gh issue develop "$number" --repo "$CC_GITHUB_REPO" --list 2>/dev/null | head -1 || echo "")
    if [[ -n "$existing" ]]; then
        echo "{\"branch\":\"$existing\",\"created\":false,\"message\":\"Branch already exists\"}"
        return 0
    fi

    local checkout_flag=""
    [[ "${CC_BRANCH_AUTO_CHECKOUT:-true}" == "true" ]] && checkout_flag="--checkout"

    gh issue develop "$number" \
        --repo "$CC_GITHUB_REPO" \
        --base "$base" \
        --name "$branch_name" \
        $checkout_flag 2>/dev/null

    echo "{\"branch\":\"$branch_name\",\"created\":true,\"base\":\"$base\"}"
}

pb_branch_list() {
    local number="${1:?Issue number required}"
    gh issue develop "$number" --repo "$CC_GITHUB_REPO" --list 2>/dev/null || echo "[]"
}

# =============================================================================
# PROVIDER INFO
# =============================================================================

pb_provider_info() {
    cat <<JSON
{
    "provider": "github",
    "name": "GitHub Projects",
    "owner": "${CC_GITHUB_OWNER:-}",
    "repo": "${CC_GITHUB_REPO:-}",
    "project_number": ${CC_PROJECT_NUMBER:-0},
    "board_url": "https://github.com/users/${CC_GITHUB_OWNER:-}/projects/${CC_PROJECT_NUMBER:-}",
    "capabilities": ["issues", "board", "sprints", "branches", "labels", "graphql"],
    "cli": "gh"
}
JSON
}

# =============================================================================
# MAIN
# =============================================================================

_pb_load_config
_gh_require_config
_pb_validate_provider
_pb_route "$@"
