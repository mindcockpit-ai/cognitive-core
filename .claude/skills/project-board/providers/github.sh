#!/bin/bash
# =============================================================================
# github.sh - GitHub Projects provider for project-board skill
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

# ---- Helper: run gh; a failure exits 2 with gh's own message ----

_gh() {
    local err out rc=0
    err=$(mktemp)
    out=$(gh "$@" 2>"$err") || rc=$?
    if [[ $rc -ne 0 ]]; then
        local msg
        msg=$(grep -v '^[[:space:]]*$' "$err" | head -1)
        rm -f "$err"
        # _GH_NOT_FOUND: gh message that means "does not exist": exit 1, the caller reports it
        [[ -n "${_GH_NOT_FOUND:-}" && "$msg" == *"$_GH_NOT_FOUND"* ]] && exit 1
        _pb_fail "gh $1 $2 failed: ${msg:-exit $rc}"
    fi
    rm -f "$err"
    printf '%s\n' "$out"
}

# ---- Helper: this board's item for an issue or PR (one query, no paging) ----
# Prints {"id","status","option_id","sprint","assignees"}; exit 1 = not on this board

_gh_item() {
    local number="$1" data
    # -f: owner and repo stay strings even when they look like numbers; only n is typed
    data=$(_GH_NOT_FOUND="Could not resolve to an issue or pull request" _gh api graphql \
        -f owner="${CC_GITHUB_REPO%%/*}" -f repo="${CC_GITHUB_REPO#*/}" -F n="$number" \
        -f query='query($owner: String!, $repo: String!, $n: Int!) {
  repository(owner: $owner, name: $repo) {
    issueOrPullRequest(number: $n) {
      ... on Issue { assignees(first: 20) { nodes { login } } projectItems(first: 50) { nodes { ...item } } }
      ... on PullRequest { assignees(first: 20) { nodes { login } } projectItems(first: 50) { nodes { ...item } } }
    }
  }
}
fragment item on ProjectV2Item {
  id
  project { id }
  status: fieldValueByName(name: "Status") { ... on ProjectV2ItemFieldSingleSelectValue { name optionId } }
  sprint: fieldValueByName(name: "Sprint") { ... on ProjectV2ItemFieldIterationValue { title } }
}') || exit $?
    local rc=0
    _CC_PROJECT_ID="$CC_PROJECT_ID" python3 -c '
import json, os, sys
try:
    node = (json.load(sys.stdin).get("data") or {}).get("repository", {}).get("issueOrPullRequest") or {}
except (ValueError, AttributeError):
    sys.exit(3)
for item in node.get("projectItems", {}).get("nodes", []):
    if (item.get("project") or {}).get("id") == os.environ["_CC_PROJECT_ID"]:
        status = item.get("status") or {}
        json.dump({"id": item["id"], "status": status.get("name", ""), "option_id": status.get("optionId", ""),
                   "sprint": (item.get("sprint") or {}).get("title", ""),
                   "assignees": [a["login"] for a in node.get("assignees", {}).get("nodes", [])]}, sys.stdout)
        sys.exit(0)
sys.exit(1)
' <<< "$data" || rc=$?
    [[ $rc -eq 3 ]] && _pb_fail "gh api graphql returned an unexpected answer for #$number"
    return "$rc"
}

_gh_item_id() { python3 -c 'import json, sys; print(json.load(sys.stdin)["id"])' <<< "$1"; }

# ---- Helper: Get all items (summary, list, approve) ----

_gh_get_items() {
    _gh project item-list "$CC_PROJECT_NUMBER" \
        --owner "$CC_GITHUB_OWNER" \
        --format json --limit 500
}

# ---- Helper: status key -> option ID ----
# Order: explicit ID, CC_STATUS_<KEY>_ID, then the live Status field by column name

_gh_option_id() {
    local key="$1" explicit="${2:-}" var
    [[ "$explicit" == -* ]] && _pb_die "Invalid option ID: $explicit"
    if [[ -n "$explicit" ]]; then echo "$explicit"; return 0; fi
    var="CC_STATUS_$(echo "$key" | tr '[:lower:]' '[:upper:]')_ID"
    if [[ -n "${!var:-}" ]]; then echo "${!var}"; return 0; fi
    local fields name
    fields=$(_gh project field-list "$CC_PROJECT_NUMBER" --owner "$CC_GITHUB_OWNER" --format json --limit 100) || exit $?
    name=$(_pb_status_name_for_key "$key" "${CC_GITHUB_STATUS_MAP:-}")
    _CC_FIELD="$CC_STATUS_FIELD_ID" _CC_NAME="$name" python3 -c '
import json, os, sys
for field in json.load(sys.stdin).get("fields", []):
    if field.get("id") == os.environ["_CC_FIELD"]:
        for option in field.get("options", []):
            if option.get("name") == os.environ["_CC_NAME"]:
                print(option["id"]); sys.exit(0)
sys.exit(1)
' <<< "$fields" || _pb_die "No column '$name' for status '$key' on the board (set $var or CC_GITHUB_STATUS_MAP; check with setup.sh --check)"
}

# ---- Helper: Get issue's content ID (GraphQL node ID) ----

_gh_get_content_id() {
    local number="$1"
    _gh issue view "$number" --repo "$CC_GITHUB_REPO" --json id --jq '.id'
}

# ---- Helper: Set project field value ----

_gh_set_field() {
    local item_id="$1" field_id="$2" option_id="$3"
    _gh api graphql -f query="
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
    _gh api graphql -f query="
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

    # ${a[@]+...}: an empty array is unbound under set -u on bash 3.2
    _gh issue list --repo "$CC_GITHUB_REPO" \
        --state "$state" \
        ${label_args[@]+"${label_args[@]}"} \
        ${limit_args[@]+"${limit_args[@]}"} \
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
    url=$(_gh issue create "${create_args[@]}") || exit $?
    local number
    number=$(basename "$url")

    # Auto-add to project board in Backlog
    local content_id item_id
    content_id=$(_gh issue view "$number" --repo "$CC_GITHUB_REPO" --json id --jq '.id') || exit $?
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
    local marker="Closed via /project-board - Approved by @system"
    if [[ -n "$comment" ]]; then
        # Cancel path already has "Canceled:" prefix - keep it as-is for hook exemption
        if [[ "$comment" != Canceled:* ]]; then
            comment="${comment} - ${marker}"
        fi
    else
        comment="$marker"
    fi

    local close_args=(--repo "$CC_GITHUB_REPO" --comment "$comment")
    # A cancel is "not planned": the board workflow moves it to Canceled, not To Be Tested
    [[ "$comment" == Canceled:* ]] && close_args+=(--reason "not planned")

    _gh issue close "$number" "${close_args[@]}" >/dev/null
    _pb_success "Issue #$number closed"
}

pb_issue_reopen() {
    local number="${1:?Issue number required}"
    _gh issue reopen "$number" --repo "$CC_GITHUB_REPO" >/dev/null
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

    _gh issue view "$number" --repo "$CC_GITHUB_REPO" --json "$json_fields"
}

pb_issue_comment() {
    local number="${1:?Issue number required}"
    local body="${2:?Comment body required}"
    _gh issue comment "$number" --repo "$CC_GITHUB_REPO" --body "$body" >/dev/null
    _pb_success "Comment added to #$number"
}

pb_issue_assign() {
    local number="${1:?Issue number required}"
    local user="${2:?Username required}"
    _gh issue edit "$number" --repo "$CC_GITHUB_REPO" --add-assignee "$user" >/dev/null
    _pb_success "Assigned $user to #$number"
}

# =============================================================================
# BOARD COMMANDS
# =============================================================================

pb_board_summary() {
    local items
    items=$(_gh_get_items) || exit $?
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
    _gh_validate_number "$number"
    local item rc=0
    item=$(_gh_item "$number") || rc=$?
    [[ $rc -eq 1 ]] && _pb_die "Issue #$number not found on board"
    [[ $rc -ne 0 ]] && exit "$rc"
    _CC_REPO="$CC_GITHUB_REPO" _CC_NUM="$number" python3 -c '
import json, os, sys
item = json.load(sys.stdin)
number = int(os.environ["_CC_NUM"])
json.dump({"number": number, "status": item["status"] or "Unknown", "item_id": item["id"],
           "sprint": item["sprint"], "assignees": item["assignees"],
           "url": "https://github.com/%s/issues/%d" % (os.environ["_CC_REPO"], number)}, sys.stdout, indent=2)
' <<< "$item"
}

pb_board_move() {
    local number="${1:?Issue number required}"
    local status_key="${2:?Status key required ($(_pb_status_keys))}"
    _gh_validate_number "$number"
    _pb_valid_status_key "$status_key" || _pb_die "Unknown status key: $status_key. Use: $(_pb_status_keys)"

    local option_id item rc=0
    option_id=$(_gh_option_id "$status_key" "${3:-}") || exit $?
    item=$(_gh_item "$number") || rc=$?
    [[ $rc -eq 1 ]] && _pb_die "Issue #$number not found on project board"
    [[ $rc -ne 0 ]] && exit "$rc"

    _gh project item-edit --id "$(_gh_item_id "$item")" \
        --project-id "$CC_PROJECT_ID" --field-id "$CC_STATUS_FIELD_ID" \
        --single-select-option-id "$option_id" >/dev/null
    _pb_success "Issue #$number moved to $(_pb_status_display_name "$status_key")"
}

pb_board_list() {
    local sprint=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --sprint) sprint="${2:?Sprint title required}"; shift 2 ;;
            *)        shift ;;
        esac
    done
    local items
    items=$(_gh_get_items) || exit $?
    _CC_SPRINT="$sprint" python3 -c '
import json, os, sys
sprint = os.environ["_CC_SPRINT"]
out = []
for item in json.load(sys.stdin).get("items", []):
    content = item.get("content") or {}
    s = item.get("sprint") or ""
    title = s.get("title", "") if isinstance(s, dict) else s
    if sprint and title != sprint:
        continue
    out.append({"number": content.get("number"), "title": content.get("title", item.get("title", "")),
                "status": item.get("status", ""), "sprint": title})
json.dump(out, sys.stdout, indent=2)
' <<< "$items"
}

pb_board_label_add() {
    local number="${1:?Issue number required}" label="${2:?Label required}"
    _gh issue edit "$number" --repo "$CC_GITHUB_REPO" --add-label "$label" >/dev/null
    _pb_success "Label $label added to #$number"
}

pb_board_label_remove() {
    local number="${1:?Issue number required}" label="${2:?Label required}"
    _gh issue edit "$number" --repo "$CC_GITHUB_REPO" --remove-label "$label" >/dev/null
    _pb_success "Label $label removed from #$number"
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
    content_id=$(_gh_get_content_id "$number") || exit $?

    # Add to project
    local item_id
    item_id=$(_gh api graphql -f query="
        mutation {
            addProjectV2ItemById(input: {
                projectId: \"$CC_PROJECT_ID\"
                contentId: \"$content_id\"
            }) { item { id } }
        }" --jq '.data.addProjectV2ItemById.item.id') || exit $?

    # Set area if provided and field configured
    if [[ -n "$area" && -n "${CC_AREA_FIELD_ID:-}" ]]; then
        local area_option_id="${4:-}"
        if [[ -n "$area_option_id" ]]; then
            _gh_set_field "$item_id" "$CC_AREA_FIELD_ID" "$area_option_id" >/dev/null || exit $?
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
    items=$(_gh_get_items) || exit $?
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
        _pb_die "Cannot approve #$number - current status is '$current_status', expected 'To Be Tested'"
    fi

    # Verify evidence exists (at least one comment on the issue)
    local comment_count
    comment_count=$(gh issue view "$number" --repo "$CC_GITHUB_REPO" --json comments --jq '.comments | length')
    if [[ "$comment_count" -eq 0 ]]; then
        _pb_die "Cannot approve #$number - no verification evidence found (0 comments)"
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

    _gh api graphql -f query="
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
    iterations=$(pb_sprint_list) || exit $?
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
        _gh_validate_number "$number"
        local item_id
        local item rc=0
        item=$(_gh_item "$number") || rc=$?
        [[ $rc -eq 1 ]] && { results+=("#$number: not on board"); continue; }
        [[ $rc -ne 0 ]] && exit "$rc"
        item_id=$(_gh_item_id "$item")
        _gh_set_iteration "$item_id" "$CC_SPRINT_FIELD_ID" "$iteration_id" >/dev/null || exit $?
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

    _gh issue develop "$number" \
        --repo "$CC_GITHUB_REPO" \
        --base "$base" \
        --name "$branch_name" \
        $checkout_flag >/dev/null

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
