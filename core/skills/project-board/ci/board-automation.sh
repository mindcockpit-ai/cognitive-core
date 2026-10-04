#!/bin/bash
# =============================================================================
# board-automation.sh - project-board CI automation (GitHub provider) (#362)
#
# Routes GitHub events to board moves and enforces the human approval gate.
# Called by .github/workflows/project-board-automation.yml (events) and
# project-board-reconcile.yml (schedule). Reads the event from
# $GITHUB_EVENT_PATH, never from workflow interpolation.
#
# Usage: board-automation.sh event       # dispatch $GITHUB_EVENT_NAME
#        board-automation.sh reconcile   # closed issues with a stale status
#        board-automation.sh decide <event> <status> <gate> <approved> <reason> <bounces>
#
# Config (cognitive-core.conf): CC_GITHUB_OWNER, CC_PROJECT_NUMBER,
# CC_REQUIRE_HUMAN_APPROVAL (default true). Project, field and option IDs
# are resolved by name at runtime. Exit 0 on benign skips (no token, not on
# the board); exit 1 when the gate could not be enforced.
# =============================================================================
set -euo pipefail

BA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD_MARKER="<!-- cc-closure-guard -->"
BOUNCE_CAP=2           # guard reopens tolerated within BOUNCE_WINDOW
BOUNCE_WINDOW=3600     # seconds

ba_log()  { printf '%s\n' "$*"; }
ba_warn() { printf '::warning::%s\n' "$*"; }

# ---- Pure routing -----------------------------------------------------------
# ba_decide <event> <status> <gate> <approved> <reason> <bounces>
#   event:    pr-opened pr-merged issue-assigned issue-opened issue-reopened
#             issue-closed reconcile
#   status:   none (not on board) unset roadmap backlog todo progress testing
#             done canceled
#   gate:     true|false     approved: 1|0
#   reason:   completed not_planned duplicate reopened or empty (lower case)
#   bounces:  trusted guard comments within the bounce window
# Prints one action per line: move <key> | add | remove-label approved |
# reopen | comment-guard | warn <text> | noop <text>
ba_decide() {
    local event="$1" status="$2" gate="$3" approved="$4" reason="$5" bounces="$6"

    if [ "$status" = "none" ] && [ "$event" != "issue-opened" ]; then
        if [ "$event" = "issue-closed" ] && [ "$gate" = "true" ]; then
            echo "warn closed while not on the board, approval gate not applied"
        else
            echo "noop not on the board"
        fi
        return 0
    fi

    case "$event" in
        pr-opened)
            if [ "$status" = "todo" ]; then echo "move progress"; else echo "noop ${status}"; fi ;;
        pr-merged)
            case "$status" in
                done|canceled) echo "noop already ${status}" ;;
                *) if [ "$gate" = "true" ]; then echo "move testing"; else echo "move done"; fi ;;
            esac ;;
        issue-assigned)
            case "$status" in
                backlog|roadmap) echo "move todo" ;;
                *) echo "noop ${status}" ;;
            esac ;;
        issue-opened)
            case "$status" in
                none) echo "add"; echo "move backlog" ;;
                unset) echo "move backlog" ;;
                *) echo "noop ${status}" ;;
            esac ;;
        issue-reopened)
            [ "$approved" = "1" ] && echo "remove-label approved"
            case "$status" in
                done|canceled) echo "move progress" ;;
                *) [ "$approved" = "1" ] || echo "noop ${status}" ;;
            esac ;;
        issue-closed)
            case "$reason" in
                not_planned|duplicate) echo "move canceled"; return 0 ;;
            esac
            if [ "$gate" != "true" ]; then echo "move done"; return 0; fi
            if [ "$approved" = "1" ] && { [ "$status" = "testing" ] || [ "$status" = "done" ]; }; then
                echo "move done"; return 0
            fi
            echo "move testing"
            [ "$approved" = "1" ] && echo "remove-label approved"
            if [ "$bounces" -ge "$BOUNCE_CAP" ]; then
                echo "warn bounce cap reached, left closed in To Be Tested"
            else
                echo "reopen"
                echo "comment-guard"
            fi ;;
        reconcile)
            case "$status" in
                done|canceled) echo "noop ${status}"; return 0 ;;
            esac
            case "$reason" in
                not_planned|duplicate) echo "move canceled"; return 0 ;;
            esac
            if [ "$gate" != "true" ] || { [ "$approved" = "1" ] && [ "$status" = "testing" ]; }; then
                echo "move done"
            else
                echo "noop closed without approval in To Be Tested, left in ${status}"
            fi ;;
        *) echo "noop unknown event ${event}" ;;
    esac
}

# ---- GitHub access (single seam, replaced in tests) ------------------------
_ba_gh() { gh "$@"; }

# Board metadata, resolved once by name
BA_PROJECT_ID="" BA_PROJECT_TITLE="" BA_FIELD_ID="" BA_OPTIONS=""
ba_load_board() {
    local view fields
    view=$(_ba_gh project view "$CC_PROJECT_NUMBER" --owner "$CC_GITHUB_OWNER" --format json) || return 1
    BA_PROJECT_ID=$(jq -er '.id' <<< "$view") || return 1
    BA_PROJECT_TITLE=$(jq -er '.title' <<< "$view") || return 1
    fields=$(_ba_gh project field-list "$CC_PROJECT_NUMBER" --owner "$CC_GITHUB_OWNER" --format json) || return 1
    BA_FIELD_ID=$(jq -er '[.fields[] | select(.name == "Status")][0].id' <<< "$fields") || return 1
    BA_OPTIONS=$(jq -c '[.fields[] | select(.name == "Status")][0].options // []' <<< "$fields")
}

# Status key -> option id, by display name
ba_option_id() {
    local name
    # A renamed column is mapped in CC_GITHUB_STATUS_MAP (key=Name|...)
    name=$(_pb_status_name_for_key "$1" "${CC_GITHUB_STATUS_MAP:-}")
    jq -er --arg n "$name" '.[] | select(.name == $n) | .id' <<< "$BA_OPTIONS"
}

# Status name on this board -> key (none = not on the board)
ba_status_key() { # <issue json>
    local items n name
    items=$(jq -c --arg t "$BA_PROJECT_TITLE" '[.projectItems[]? | select(.title == $t)]' <<< "$1")
    n=$(jq 'length' <<< "$items")
    if [ "$n" -eq 0 ]; then echo none; return 0; fi
    if [ "$n" -gt 1 ]; then echo ambiguous; return 0; fi
    name=$(jq -r '.[0].status.name // ""' <<< "$items")
    if [ -z "$name" ]; then echo unset; return 0; fi
    _pb_canonical_status "$name"
}

# Trusted guard comments within the bounce window
ba_bounces() { # <issue json>
    jq --arg m "$GUARD_MARKER" --argjson now "${BA_NOW:-$(date +%s)}" --argjson w "$BOUNCE_WINDOW" '
        [.comments[]?
         | select(.body | contains($m))
         | select((.authorAssociation as $a | ["OWNER","MEMBER","COLLABORATOR"] | index($a))
                  or ((.author.login // "") | test("\\[bot\\]$|^app/")))
         | select(($now - (.createdAt | fromdateiso8601)) <= $w)
        ] | length' <<< "$1"
}

ba_issue() { # <number>
    _ba_gh issue view "$1" --repo "$BA_REPO" --json number,state,stateReason,labels,projectItems,comments,url
}

# ---- Executor -----------------------------------------------------------------
BA_FAILED=0
ba_apply() { # <number> <issue url> <actions...>
    local number="$1" url="$2" action item option
    shift 2
    for action in "$@"; do
        case "$action" in
            noop*) ba_log "#${number}: ${action#noop }" ;;
            warn*) ba_warn "#${number}: ${action#warn }" ;;
            add)
                _ba_gh project item-add "$CC_PROJECT_NUMBER" --owner "$CC_GITHUB_OWNER" --url "$url" --format json >/dev/null \
                    || { ba_warn "#${number}: could not add to the board"; BA_FAILED=1; return 0; } ;;
            "move "*)
                option=$(ba_option_id "${action#move }") \
                    || { ba_warn "#${number}: no Status option for ${action#move }"; BA_FAILED=1; continue; }
                item=$(_ba_gh project item-add "$CC_PROJECT_NUMBER" --owner "$CC_GITHUB_OWNER" --url "$url" --format json | jq -er '.id') \
                    || { ba_warn "#${number}: board item not found"; BA_FAILED=1; continue; }
                if _ba_gh project item-edit --id "$item" --project-id "$BA_PROJECT_ID" \
                        --field-id "$BA_FIELD_ID" --single-select-option-id "$option" >/dev/null; then
                    ba_log "#${number}: moved to $(_pb_status_display_name "${action#move }")"
                else
                    ba_warn "#${number}: move to ${action#move } failed"; BA_FAILED=1
                fi ;;
            "remove-label approved")
                _ba_gh issue edit "$number" --repo "$BA_REPO" --remove-label approved >/dev/null \
                    || { ba_warn "#${number}: could not remove the approved label"; BA_FAILED=1; } ;;
            reopen)
                _ba_gh issue reopen "$number" --repo "$BA_REPO" >/dev/null \
                    || { ba_warn "#${number}: reopen failed, approval gate not enforced"; BA_FAILED=1; } ;;
            comment-guard)
                _ba_gh issue comment "$number" --repo "$BA_REPO" --body "${GUARD_MARKER}
**Closure guard**: closed without the \`approved\` label, so it was moved to **To Be Tested** and reopened. Verify the acceptance criteria, then close through \`/project-board approve\`." >/dev/null \
                    || { ba_warn "#${number}: guard comment failed"; BA_FAILED=1; } ;;
            *) ba_warn "#${number}: unknown action ${action}"; BA_FAILED=1 ;;
        esac
    done
}

# Decide and apply for one issue
ba_route() { # <event> <number> [event reason]
    local event="$1" number="$2" json status approved reason bounces url
    local -a actions
    json=$(ba_issue "$number") || { ba_warn "#${number}: cannot read the issue"; BA_FAILED=1; return 0; }
    jq -e 'type == "object" and has("state")' >/dev/null 2>&1 <<< "$json" \
        || { ba_warn "#${number}: unexpected issue JSON"; BA_FAILED=1; return 0; }

    # State-based: a close handled after a reopen does nothing
    if [ "$event" = "issue-closed" ] && [ "$(jq -r '.state' <<< "$json")" != "CLOSED" ]; then
        ba_log "#${number}: open again, nothing to do"; return 0
    fi
    status=$(ba_status_key "$json")
    if [ "$status" = "ambiguous" ]; then ba_warn "#${number}: on the board more than once"; BA_FAILED=1; return 0; fi
    approved=$(jq -r '[.labels[]?.name] | index("approved") | if . == null then 0 else 1 end' <<< "$json")
    reason=$(jq -r '.stateReason // "" | ascii_downcase' <<< "$json")
    bounces=$(ba_bounces "$json")
    url=$(jq -r '.url' <<< "$json")

    local line
    actions=()
    while IFS= read -r line; do actions+=("$line"); done \
        < <(ba_decide "$event" "$status" "$BA_GATE" "$approved" "$reason" "$bounces")
    ba_apply "$number" "$url" "${actions[@]}"
}

# ---- Entry points ---------------------------------------------------------------
ba_event() {
    local name="${GITHUB_EVENT_NAME:-}" path="${GITHUB_EVENT_PATH:-}" action number refs n
    [ -f "$path" ] || { ba_warn "no event payload"; return 1; }
    action=$(jq -r '.action // ""' "$path")
    case "$name" in
        pull_request)
            number=$(jq -er '.pull_request.number' "$path")
            local event=""
            case "$action" in
                opened|ready_for_review) event="pr-opened" ;;
                closed) [ "$(jq -r '.pull_request.merged' "$path")" = "true" ] && event="pr-merged" ;;
            esac
            [ -n "$event" ] || { ba_log "PR #${number} ${action}: nothing to do"; return 0; }
            refs=$(_ba_gh pr view "$number" --repo "$BA_REPO" --json closingIssuesReferences \
                | jq -r --arg r "$BA_REPO" '.closingIssuesReferences[]
                    | select((.repository.owner.login + "/" + .repository.name) == $r) | .number') \
                || { ba_warn "PR #${number}: cannot read linked issues"; return 0; }
            [ -n "$refs" ] || { ba_log "PR #${number}: no linked issues"; return 0; }
            for n in $refs; do ba_route "$event" "$n"; done ;;
        issues)
            number=$(jq -er '.issue.number' "$path")
            case "$action" in
                opened|assigned|reopened|closed) ba_route "issue-${action}" "$number" ;;
                *) ba_log "issue #${number} ${action}: nothing to do" ;;
            esac ;;
        *) ba_log "event ${name}: nothing to do" ;;
    esac
}

ba_reconcile() {
    local items closed n status
    items=$(_ba_gh project item-list "$CC_PROJECT_NUMBER" --owner "$CC_GITHUB_OWNER" --format json --limit 1000) \
        || { ba_warn "cannot list board items"; return 1; }
    closed=$(_ba_gh issue list --repo "$BA_REPO" --state closed --limit 1000 --json number) \
        || { ba_warn "cannot list closed issues"; return 1; }
    [ "$(jq '.items | length' <<< "$items")" -lt 1000 ] || ba_warn "board has 1000+ items, reconcile may miss some"
    [ "$(jq 'length' <<< "$closed")" -lt 1000 ] || ba_warn "1000+ closed issues, reconcile may miss older ones"
    for n in $(jq -r --arg r "$BA_REPO" --argjson c "$closed" '
            ($c | map(.number)) as $closed
            | .items[]
            | select(.content.type == "Issue" and .content.repository == $r)
            | select((.status // "") != "Done" and (.status // "") != "Canceled")
            | select(.content.number as $x | $closed | index($x))
            | .content.number' <<< "$items" | sort -n -u); do
        ba_route reconcile "$n"
    done
}

main() {
    local cmd="${1:-event}"
    if [ "$cmd" = "decide" ]; then
        shift; ba_decide "$@"; return 0
    fi
    if [ -z "${GH_TOKEN:-}" ]; then
        ba_log "::notice::No board token (PROJECT_PAT or GitHub App) - board automation skipped"
        return 0
    fi
    PROJECT_DIR="${PROJECT_DIR:-${GITHUB_WORKSPACE:-.}}"
    _pb_load_config
    if [ "${CC_PROJECT_BOARD_PROVIDER:-github}" != "github" ]; then
        ba_log "Board provider is ${CC_PROJECT_BOARD_PROVIDER}, nothing to do"; return 0
    fi
    : "${CC_GITHUB_OWNER:?CC_GITHUB_OWNER missing in cognitive-core.conf}"
    : "${CC_PROJECT_NUMBER:?CC_PROJECT_NUMBER missing in cognitive-core.conf}"
    BA_REPO="${GITHUB_REPOSITORY:-${CC_GITHUB_REPO:-}}"
    case "${CC_REQUIRE_HUMAN_APPROVAL:-true}" in
        false) BA_GATE=false ;;
        true) BA_GATE=true ;;
        *) ba_warn "CC_REQUIRE_HUMAN_APPROVAL='${CC_REQUIRE_HUMAN_APPROVAL}' is not true/false, approval gate stays on"
           BA_GATE=true ;;
    esac
    ba_load_board || { ba_warn "cannot read project ${CC_PROJECT_NUMBER} of ${CC_GITHUB_OWNER}"; return 1; }
    case "$cmd" in
        event) ba_event ;;
        reconcile) ba_reconcile ;;
        *) ba_warn "unknown command ${cmd}"; return 1 ;;
    esac
    [ "$BA_FAILED" -eq 0 ]
}

# shellcheck source=core/skills/project-board/_provider-lib.sh
source "${BA_DIR}/../_provider-lib.sh"
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
