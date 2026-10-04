#!/bin/bash
# Test suite: project-board CI automation and approval gate (#362)
# A) ba_decide routing table and gate invariants (every combination)
# B) board-automation.sh end to end against a strict gh stub (exact calls)
# C) the shipped workflows (static checks)
# D) update.sh / install.sh delivery of the managed workflows
# SUITE30_PARTS=AB runs only those parts (mutation runs); default: all.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "30 - Board Automation"

BA="${ROOT_DIR}/core/skills/project-board/ci/board-automation.sh"
WORK="$(create_test_dir)"
trap 'rm -rf "$WORK"' EXIT

# ba_decide in-process (main is guarded by BASH_SOURCE == $0)
# shellcheck source=core/skills/project-board/ci/board-automation.sh
source "$BA"
decide() { ba_decide "$@" | tr '\n' ';'; }
part() { case "${SUITE30_PARTS:-ABCD}" in *"$1"*) return 0 ;; esac; return 1; }

# ---- A) Routing table --------------------------------------------------------
if part A; then
# event status gate approved reason bounces -> expected actions
while IFS='|' read -r label args expected; do
    [ -n "$label" ] || continue
    read -r a1 a2 a3 a4 a5 a6 <<< "$args"
    [ "$a5" = "-" ] && a5=""
    assert_eq "decide: ${label}" "$expected" "$(decide "$a1" "$a2" "$a3" "$a4" "$a5" "$a6")"
done << 'TABLE'
pr opened from Todo|pr-opened todo true 0 - 0|move progress;
pr opened elsewhere|pr-opened backlog true 0 - 0|noop backlog;
pr opened without status|pr-opened unset true 0 - 0|noop unset;
pr merged gate on|pr-merged progress true 0 - 0|move testing;
pr merged gate on, approved in testing|pr-merged testing true 1 - 0|move testing;
pr merged gate off|pr-merged progress false 0 - 0|move done;
pr merged already done|pr-merged done true 0 - 0|noop already done;
pr merged canceled|pr-merged canceled false 0 - 0|noop already canceled;
merged, not on board|pr-merged none true 0 - 0|noop not on the board;
assigned from backlog|issue-assigned backlog true 0 - 0|move todo;
assigned from roadmap|issue-assigned roadmap true 0 - 0|move todo;
assigned in progress|issue-assigned progress true 0 - 0|noop progress;
opened, not on board|issue-opened none true 0 - 0|add;move backlog;
opened, no status|issue-opened unset true 0 - 0|move backlog;
opened, has status|issue-opened todo true 0 - 0|noop todo;
reopened from done|issue-reopened done true 0 - 0|move progress;
reopened approved from done|issue-reopened done true 1 - 0|remove-label approved;move progress;
reopened approved in testing|issue-reopened testing true 1 - 0|remove-label approved;
reopened in testing|issue-reopened testing true 0 - 0|noop testing;
closed not planned|issue-closed progress true 0 not_planned 0|move canceled;
closed duplicate|issue-closed testing true 1 duplicate 0|move canceled;
closed gate off|issue-closed progress false 0 completed 0|move done;
closed approved from testing|issue-closed testing true 1 completed 0|move done;
closed approved already done|issue-closed done true 1 completed 0|move done;
closed unapproved from testing|issue-closed testing true 0 completed 0|move testing;reopen;comment-guard;
closed unapproved from progress|issue-closed progress true 0 completed 0|move testing;reopen;comment-guard;
closed approved from progress|issue-closed progress true 1 completed 0|move testing;remove-label approved;reopen;comment-guard;
closed below bounce cap|issue-closed progress true 0 completed 1|move testing;reopen;comment-guard;
closed at bounce cap|issue-closed progress true 0 completed 2|move testing;warn bounce cap reached, left closed in To Be Tested;
closed, not on board, gate on|issue-closed none true 0 completed 0|warn closed while not on the board, approval gate not applied;
closed, not on board, gate off|issue-closed none false 0 completed 0|noop not on the board;
reconcile approved in testing|reconcile testing true 1 completed 0|move done;
reconcile approved elsewhere|reconcile progress true 1 completed 0|noop closed without approval in To Be Tested, left in progress;
reconcile unapproved|reconcile testing true 0 completed 0|noop closed without approval in To Be Tested, left in testing;
reconcile not planned|reconcile progress true 0 not_planned 0|move canceled;
reconcile not planned, approved in testing|reconcile testing true 1 not_planned 0|move canceled;
reconcile gate off|reconcile progress false 0 completed 0|move done;
reconcile done|reconcile done true 0 completed 0|noop done;
unknown event|bogus todo true 1 completed 0|noop unknown event bogus;
TABLE

# Invariants over every combination of both gate settings
violations=""
combos=0
for gate in true false; do
  for ev in pr-opened pr-merged issue-assigned issue-opened issue-reopened issue-closed reconcile; do
    for st in none unset roadmap backlog todo progress testing "done" canceled; do
      for ap in 0 1; do
        for rs in completed not_planned duplicate reopened ""; do
          for bo in 0 1 2 3; do
            combos=$((combos + 1))
            out="$(ba_decide "$ev" "$st" "$gate" "$ap" "$rs" "$bo")"
            id="${gate}/${ev}/${st}/${ap}/${rs:-none}/${bo}"
            # Pure bash matching: no process per check (5040 combinations)
            lines=$'\n'"${out}"$'\n'
            has() { [[ "$lines" == *$'\n'"$1"$'\n'* ]]; }
            [ -n "$out" ] || violations="${violations} empty:${id}"
            if has "move done"; then
                case "$ev" in pr-merged|issue-closed|reconcile) ;; *) violations="${violations} done-event:${id}" ;; esac
                if [ "$gate" = "true" ]; then
                    case "$ev" in issue-closed|reconcile) ;; *) violations="${violations} done-gate:${id}" ;; esac
                    [ "$ap" = "1" ] || violations="${violations} done-unapproved:${id}"
                    case "$st" in testing|"done") ;; *) violations="${violations} done-status:${id}" ;; esac
                fi
                case "$ev/$rs" in issue-closed/not_planned|issue-closed/duplicate|reconcile/not_planned|reconcile/duplicate)
                    violations="${violations} done-reason:${id}" ;; esac
            fi
            if has "reopen"; then
                { [ "$ev" = "issue-closed" ] && [ "$gate" = "true" ] && [ "$bo" -lt 2 ]; } || violations="${violations} reopen-when:${id}"
                [ "${out%%$'\n'*}" = "move testing" ] || violations="${violations} reopen-order:${id}"
                has "comment-guard" || violations="${violations} reopen-comment:${id}"
            fi
            if [ "$gate" = "false" ] && { has "move testing" || has "reopen" || has "comment-guard"; }; then
                violations="${violations} gate-off-gated:${id}"
            fi
            if [ "$st" = "none" ] && [ "$ev" != "issue-opened" ]; then
                case "$out" in
                    *$'\n'*) violations="${violations} off-board-acts:${id}" ;;
                    "noop "*|"warn "*) ;;
                    *) violations="${violations} off-board-acts:${id}" ;;
                esac
            fi
            if has "add" && [ "$ev" != "issue-opened" ]; then
                violations="${violations} add-event:${id}"
            fi
          done
        done
      done
    done
  done
done
assert_eq "invariant sweep covered all combinations" "5040" "$combos"
assert_eq "invariants hold (Done only approved from To Be Tested/Done, reopen after move with guard, gate off never gates, off-board inert)" "" "${violations# }"

fi

# ---- B) End to end against a strict gh stub ------------------------------------------
if part B; then
STUB="${WORK}/bin"
FIX="${WORK}/fix"
PROJ="${WORK}/proj"
mkdir -p "$STUB" "$FIX" "$PROJ"
: > "${WORK}/all.log"
NOW=1790000000   # fixed clock for the bounce window
iso() { python3 -c 'import sys,datetime;print(datetime.datetime.fromtimestamp(int(sys.argv[1]),datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))' "$1"; }

cat > "${STUB}/gh" << 'STUBEOF'
#!/bin/bash
# Answers only the calls board-automation.sh is expected to make
line="$*"
printf '%s\n' "${line//$'\n'/\\n}" | tee -a "${STUB_ALL}" >> "${STUB_LOG}"
fail() { [ -n "${1:-}" ] && exit 1; return 0; }
case "$line" in
    "project view 9 --owner acme --format json") fail "${STUB_FAIL_VIEW:-}"; cat "${STUB_FIX}/project.json" ;;
    "project field-list 9 --owner acme --format json") cat "${STUB_FIX}/${STUB_FIELDS:-fields.json}" ;;
    "issue view "*" --repo acme/app --json number,state,stateReason,labels,projectItems,comments,url")
        f="${STUB_FIX}/issue-$3.json"; [ -f "$f" ] && cat "$f" || exit 1 ;;
    "project item-add 9 --owner acme --url https://github.com/acme/app/issues/"*" --format json")
        fail "${STUB_FAIL_ADD:-}"; printf '{"id":"ITEM_%s"}\n' "${7##*/}" ;;
    "project item-edit --id ITEM_"*" --project-id PROJ_1 --field-id FIELD_1 --single-select-option-id "*) fail "${STUB_FAIL_EDIT:-}" ;;
    "issue reopen "*" --repo acme/app") fail "${STUB_FAIL_REOPEN:-}" ;;
    "issue comment "*" --repo acme/app --body "*) fail "${STUB_FAIL_COMMENT:-}" ;;
    "issue edit "*" --repo acme/app --remove-label approved") fail "${STUB_FAIL_LABEL:-}" ;;
    "pr view "*" --repo acme/app --json closingIssuesReferences") cat "${STUB_FIX}/pr-$3.json" ;;
    "project item-list 9 --owner acme --format json --limit 1000") cat "${STUB_FIX}/${STUB_ITEMS:-items.json}" ;;
    "issue list --repo acme/app --state closed --limit 1000 --json number") cat "${STUB_FIX}/closed.json" ;;
    *) echo "UNEXPECTED: $line" | tee -a "${STUB_ALL}" >> "${STUB_LOG}"; exit 99 ;;
esac
STUBEOF
chmod +x "${STUB}/gh"

echo '{"id":"PROJ_1","number":9,"title":"Board"}' > "${FIX}/project.json"
cat > "${FIX}/fields.json" << 'EOF'
{"fields":[{"id":"FIELD_0","name":"Title","type":"ProjectV2Field"},
 {"id":"FIELD_1","name":"Status","type":"ProjectV2SingleSelectField","options":[
  {"id":"OPT_ROADMAP","name":"Roadmap"},{"id":"OPT_BACKLOG","name":"Backlog"},{"id":"OPT_TODO","name":"Todo"},
  {"id":"OPT_PROGRESS","name":"In Progress"},{"id":"OPT_TESTING","name":"To Be Tested"},
  {"id":"OPT_DONE","name":"Done"},{"id":"OPT_CANCELED","name":"Canceled"}]}]}
EOF
# Renamed columns (QA instead of To Be Tested) and a board without Done
jq '.fields[1].options[4].name = "QA"' "${FIX}/fields.json" > "${FIX}/fields-renamed.json"
jq '.fields[1].options |= map(select(.name != "Done"))' "${FIX}/fields.json" > "${FIX}/fields-nodone.json"

# mk_issue <n> <state> <stateReason> <status name|-|none|twice> <labels csv> [comments json]
mk_issue() {
    local items labels
    case "$4" in
        none) items='[]' ;;
        -) items='[{"status":null,"title":"Board"}]' ;;
        twice) items='[{"status":{"name":"Todo"},"title":"Board"},{"status":{"name":"Done"},"title":"Board"}]' ;;
        *) items="[{\"status\":{\"name\":\"$4\",\"optionId\":\"x\"},\"title\":\"Board\"},{\"status\":{\"name\":\"Done\"},\"title\":\"Other board\"}]" ;;
    esac
    labels=$(jq -cn --arg s "$5" '$s | split(",") | map(select(. != "")) | map({name: .})')
    jq -n --argjson n "$1" --arg s "$2" --arg r "$3" --argjson i "$items" --argjson l "$labels" --argjson c "${6:-[]}" \
        '{number:$n, state:$s, stateReason:(if $r == "" then null else $r end), labels:$l, projectItems:$i, comments:$c,
          url:("https://github.com/acme/app/issues/" + ($n|tostring))}' > "${FIX}/issue-$1.json"
}

conf() { # <gate value or "unset"> [extra conf line]
    {
        printf 'CC_GITHUB_OWNER="acme"\nCC_PROJECT_NUMBER="9"\n'
        [ "$1" = "unset" ] || printf 'CC_REQUIRE_HUMAN_APPROVAL="%s"\n' "$1"
        [ -z "${2:-}" ] || printf '%s\n' "$2"
    } > "${PROJ}/cognitive-core.conf"
}

# run_ba <cmd> <event name> <event json> [VAR=value ...]
# Clean environment: no inherited CC_* or HOME. Sets RC, OUT, LOG (all calls),
# CALLS (writes only, normalised).
run_ba() {
    local cmd="$1" ev="$2" payload="$3"
    shift 3
    : > "${WORK}/log"
    printf '%s' "$payload" > "${WORK}/event.json"
    OUT=$(env -i PATH="${STUB}:${PATH}" HOME="$WORK" TMPDIR="${TMPDIR:-/tmp}" \
        STUB_LOG="${WORK}/log" STUB_ALL="${WORK}/all.log" STUB_FIX="$FIX" GH_TOKEN="test" BA_NOW="$NOW" \
        PROJECT_DIR="$PROJ" GITHUB_REPOSITORY="acme/app" GITHUB_EVENT_NAME="$ev" GITHUB_EVENT_PATH="${WORK}/event.json" \
        "$@" bash "$BA" "$cmd" 2>&1) && RC=0 || RC=$?
    LOG=$(cat "${WORK}/log")
    CALLS=$(grep -E '^(project item-edit|issue reopen|issue comment|issue edit|UNEXPECTED)' <<< "$LOG" \
        | sed -E 's/--body .*/--body .../; s/ --project-id PROJ_1 --field-id FIELD_1 --single-select-option-id/ ->/' || true)
}
# assert_run <label> <rc> <expected writes>
assert_run() { assert_eq "$1" "$2|$3" "${RC}|${CALLS}"; }
count() { grep -c "$1" <<< "$LOG" || true; }
issue_event() { printf '{"action":"%s","issue":{"number":%s}}' "$1" "$2"; }
nl() { printf '%s\n' "$@"; }

conf true

# Closed without approval from In Progress: To Be Tested first, then reopen + guard
mk_issue 11 CLOSED COMPLETED "In Progress" "bug"
run_ba event issues "$(issue_event closed 11)"
assert_run "closed unapproved: move, reopen, guard in this order" 0 \
    "$(nl 'project item-edit --id ITEM_11 -> OPT_TESTING' 'issue reopen 11 --repo acme/app' 'issue comment 11 --repo acme/app --body ...')"
assert_contains "guard comment carries the marker" "$LOG" "cc-closure-guard"
assert_eq "one board lookup per move" "$(count '^project item-edit')" "$(count '^project item-add')"
assert_eq "closed unapproved: full call sequence incl. reads" \
    "$(nl 'project view 9 --owner acme --format json' 'project field-list 9 --owner acme --format json' \
         'issue view 11 --repo acme/app --json number,state,stateReason,labels,projectItems,comments,url' \
         'project item-add 9 --owner acme --url https://github.com/acme/app/issues/11 --format json' \
         'project item-edit --id ITEM_11 --project-id PROJ_1 --field-id FIELD_1 --single-select-option-id OPT_TESTING' \
         'issue reopen 11 --repo acme/app')" "$(sed '/^issue comment /d' <<< "$LOG")"

# Approved from To Be Tested: Done only
mk_issue 12 CLOSED COMPLETED "To Be Tested" "approved"
run_ba event issues "$(issue_event closed 12)"
assert_run "closed approved: Done" 0 "project item-edit --id ITEM_12 -> OPT_DONE"

# Look-alike labels are not approval
mk_issue 26 CLOSED COMPLETED "To Be Tested" "not-approved,approved-by-x"
run_ba event issues "$(issue_event closed 26)"
assert_run "look-alike labels: bounced" 0 \
    "$(nl 'project item-edit --id ITEM_26 -> OPT_TESTING' 'issue reopen 26 --repo acme/app' 'issue comment 26 --repo acme/app --body ...')"

# Not planned (upper case from gh): Canceled, no reopen
mk_issue 13 CLOSED NOT_PLANNED "Todo" ""
run_ba event issues "$(issue_event closed 13)"
assert_run "closed not planned: Canceled" 0 "project item-edit --id ITEM_13 -> OPT_CANCELED"

# Open again when the close is handled: reads only
mk_issue 14 OPEN REOPENED "In Progress" ""
run_ba event issues "$(issue_event closed 14)"
assert_run "close handled after reopen: no writes" 0 ""
assert_eq "close handled after reopen: no board lookup" "0" "$(count '^project item-add')"

# Not on this board, gate on: warning, no writes, no item-add
mk_issue 15 CLOSED COMPLETED none ""
run_ba event issues "$(issue_event closed 15)"
assert_run "not on board: no writes" 0 ""
assert_eq "not on board: only metadata and issue reads" \
    "$(nl 'project view 9 --owner acme --format json' 'project field-list 9 --owner acme --format json' \
         'issue view 15 --repo acme/app --json number,state,stateReason,labels,projectItems,comments,url')" "$LOG"
assert_contains "not on board: warning" "$OUT" "approval gate not applied"

# Bounce cap: trusted guard comments count, forged and expired ones do not
guard() { # <association> <login> <age seconds>
    jq -n --arg a "$1" --arg l "$2" --arg t "$(iso $((NOW - $3)))" \
        '{author:{login:$l}, authorAssociation:$a, createdAt:$t, body:"<!-- cc-closure-guard -->\nguard"}'
}
mk_issue 16 CLOSED COMPLETED "In Progress" "" "$(jq -s '.' <(guard MEMBER maint 10) <(guard NONE "board-app[bot]" 3600))"
run_ba event issues "$(issue_event closed 16)"
assert_run "bounce cap: member + [bot] at the window edge" 0 "project item-edit --id ITEM_16 -> OPT_TESTING"
assert_contains "bounce cap: warning" "$OUT" "bounce cap reached"
mk_issue 27 CLOSED COMPLETED "In Progress" "" "$(jq -s '.' <(guard COLLABORATOR collab 10) <(guard NONE "app/board" 20))"
run_ba event issues "$(issue_event closed 27)"
assert_run "bounce cap: collaborator + app/ login" 0 "project item-edit --id ITEM_27 -> OPT_TESTING"
mk_issue 17 CLOSED COMPLETED "In Progress" "" "$(jq -s '.' <(guard NONE outsider 10) <(guard NONE outsider 20) <(guard MEMBER maint 3601))"
run_ba event issues "$(issue_event closed 17)"
assert_contains "bounce cap: forged and expired markers ignored" "$CALLS" "issue reopen 17 --repo acme/app"
mk_issue 20 CLOSED COMPLETED "In Progress" "" "$(jq -s '.' <(guard MEMBER maint 3601) <(guard OWNER owner 7200))"
run_ba event issues "$(issue_event closed 20)"
assert_contains "bounce cap: trusted markers outside the window ignored" "$CALLS" "issue reopen 20 --repo acme/app"

# Failures that leave the gate unenforced fail the job
mk_issue 18 CLOSED COMPLETED "In Progress" ""
run_ba event issues "$(issue_event closed 18)" STUB_FAIL_REOPEN=1
assert_eq "reopen failure: exit 1" "1" "$RC"
run_ba event issues "$(issue_event closed 18)" STUB_FAIL_COMMENT=1
assert_eq "guard comment failure: exit 1" "1" "$RC"
run_ba event issues "$(issue_event closed 18)" STUB_FAIL_EDIT=1
assert_eq "move failure: exit 1" "1" "$RC"
assert_contains "move failure: still reopened" "$CALLS" "issue reopen 18 --repo acme/app"
run_ba event issues "$(issue_event closed 18)" STUB_FAIL_ADD=1
assert_eq "board item lookup failure: exit 1" "1" "$RC"
mk_issue 28 OPEN REOPENED "Done" "approved"
run_ba event issues "$(issue_event reopened 28)" STUB_FAIL_LABEL=1
assert_eq "label removal failure: exit 1" "1" "$RC"
mk_issue 29 CLOSED COMPLETED "To Be Tested" "approved"
run_ba event issues "$(issue_event closed 29)" STUB_FIELDS=fields-nodone.json
assert_eq "missing Status option: exit 1" "1" "$RC"
mk_issue 30 CLOSED COMPLETED twice ""
run_ba event issues "$(issue_event closed 30)"
assert_run "on the board twice: no writes, exit 1" 1 ""
echo 'null' > "${FIX}/issue-31.json"
run_ba event issues "$(issue_event closed 31)"
assert_run "malformed issue JSON: no writes, exit 1" 1 ""
run_ba event issues "$(issue_event closed 11)" STUB_FAIL_VIEW=1
assert_run "board metadata unreadable: exit 1" 1 ""

# Reopened approved issue in Done: label removed, back to In Progress
mk_issue 19 OPEN REOPENED "Done" "approved"
run_ba event issues "$(issue_event reopened 19)"
assert_run "reopened: label removed, In Progress" 0 \
    "$(nl 'issue edit 19 --repo acme/app --remove-label approved' 'project item-edit --id ITEM_19 -> OPT_PROGRESS')"

# PRs: linked issues from closingIssuesReferences, other repos ignored
cat > "${FIX}/pr-5.json" << 'EOF'
{"closingIssuesReferences":[
 {"number":21,"repository":{"name":"app","owner":{"login":"acme"}}},
 {"number":22,"repository":{"name":"other","owner":{"login":"acme"}}}]}
EOF
mk_issue 21 CLOSED COMPLETED "In Progress" ""
run_ba event pull_request '{"action":"closed","pull_request":{"number":5,"merged":true,"body":"Closes [#21](x)\nPREOF\nrm -rf /"}}'
assert_run "pr merged: same-repo issue to To Be Tested" 0 "project item-edit --id ITEM_21 -> OPT_TESTING"
assert_eq "pr merged: other repo's issue never read" "0" "$(count 'issue view 22')"
assert_eq "pr merged: full call sequence incl. reads" \
    "$(nl 'project view 9 --owner acme --format json' 'project field-list 9 --owner acme --format json' \
         'pr view 5 --repo acme/app --json closingIssuesReferences' \
         'issue view 21 --repo acme/app --json number,state,stateReason,labels,projectItems,comments,url' \
         'project item-add 9 --owner acme --url https://github.com/acme/app/issues/21 --format json' \
         'project item-edit --id ITEM_21 --project-id PROJ_1 --field-id FIELD_1 --single-select-option-id OPT_TESTING')" "$LOG"
run_ba event pull_request '{"action":"closed","pull_request":{"number":5,"merged":false,"body":null}}'
assert_run "pr closed unmerged: nothing" 0 ""
assert_eq "pr closed unmerged: no PR lookup" "0" "$(count '^pr view')"
echo '{"closingIssuesReferences":[{"number":42,"repository":{"name":"app","owner":{"login":"acme"}}}]}' > "${FIX}/pr-6.json"
mk_issue 42 OPEN "" "Todo" ""
run_ba event pull_request '{"action":"ready_for_review","pull_request":{"number":6}}'
assert_run "pr ready for review: Todo to In Progress" 0 "project item-edit --id ITEM_42 -> OPT_PROGRESS"
run_ba event pull_request '{"action":"opened","pull_request":{"number":6}}'
assert_run "pr opened: Todo to In Progress" 0 "project item-edit --id ITEM_42 -> OPT_PROGRESS"

# Assigned, opened (with and without status)
mk_issue 41 OPEN "" "Backlog" ""
run_ba event issues "$(issue_event assigned 41)"
assert_run "assigned: Backlog to Todo" 0 "project item-edit --id ITEM_41 -> OPT_TODO"
mk_issue 24 OPEN "" none ""
run_ba event issues "$(issue_event opened 24)"
assert_run "opened, not on board: Backlog" 0 "project item-edit --id ITEM_24 -> OPT_BACKLOG"
assert_eq "opened, not on board: added once, looked up once" "2" "$(count '^project item-add')"
mk_issue 40 OPEN "" "-" ""
run_ba event issues "$(issue_event opened 40)"
assert_run "opened, no status: Backlog" 0 "project item-edit --id ITEM_40 -> OPT_BACKLOG"
run_ba event issues "$(issue_event opened 24)" STUB_FAIL_ADD=1
assert_run "add failure: exit 1, no move" 1 ""

# Gate settings from the conf
conf false
mk_issue 23 CLOSED COMPLETED "In Progress" ""
run_ba event issues "$(issue_event closed 23)"
assert_run "gate off: Done" 0 "project item-edit --id ITEM_23 -> OPT_DONE"
conf unset
mk_issue 25 CLOSED COMPLETED "In Progress" ""
run_ba event issues "$(issue_event closed 25)"
assert_run "gate unset: on" 0 "$(nl 'project item-edit --id ITEM_25 -> OPT_TESTING' 'issue reopen 25 --repo acme/app' 'issue comment 25 --repo acme/app --body ...')"
conf True
run_ba event issues "$(issue_event closed 25)"
assert_run "gate typo: stays on" 0 "$(nl 'project item-edit --id ITEM_25 -> OPT_TESTING' 'issue reopen 25 --repo acme/app' 'issue comment 25 --repo acme/app --body ...')"
assert_contains "gate typo: warning" "$OUT" "approval gate stays on"
conf true 'CC_GITHUB_STATUS_MAP="testing=QA"'
run_ba event issues "$(issue_event closed 25)" STUB_FIELDS=fields-renamed.json
assert_run "renamed column via status map" 0 "$(nl 'project item-edit --id ITEM_25 -> OPT_TESTING' 'issue reopen 25 --repo acme/app' 'issue comment 25 --repo acme/app --body ...')"
conf true 'CC_PROJECT_BOARD_PROVIDER="jira"'
run_ba event issues "$(issue_event closed 25)"
assert_run "other provider: nothing" 0 ""
assert_eq "other provider: no gh calls" "" "$LOG"
printf 'CC_GITHUB_OWNER="acme"\n' > "${PROJ}/cognitive-core.conf"
run_ba event issues "$(issue_event closed 25)"
assert_eq "missing CC_PROJECT_NUMBER: exit non-zero" "1" "$(( RC != 0 ))"
assert_eq "missing CC_PROJECT_NUMBER: no gh calls" "" "$LOG"
conf true

# Event and command handling
run_ba event workflow_dispatch '{}'
assert_run "unknown event: nothing" 0 ""
run_ba event issues "$(issue_event labeled 11)"
assert_run "unhandled issue action: nothing" 0 ""
rm -f "${WORK}/event.json"
OUT=$(env -i PATH="${STUB}:${PATH}" HOME="$WORK" STUB_LOG="${WORK}/log" STUB_ALL="${WORK}/all.log" STUB_FIX="$FIX" \
    GH_TOKEN=test PROJECT_DIR="$PROJ" GITHUB_REPOSITORY=acme/app GITHUB_EVENT_NAME=issues GITHUB_EVENT_PATH="${WORK}/missing.json" \
    bash "$BA" event 2>&1) && RC=0 || RC=$?
assert_eq "missing event payload: exit 1" "1" "$RC"
run_ba bogus issues '{}'
assert_eq "unknown command: exit 1" "1" "$RC"

# Reconcile: approved To Be Tested -> Done, not planned -> Canceled, others untouched
cat > "${FIX}/items.json" << 'EOF'
{"items":[
 {"id":"I31","status":"In Progress","content":{"type":"Issue","number":51,"repository":"acme/app"}},
 {"id":"I32","status":"To Be Tested","content":{"type":"Issue","number":52,"repository":"acme/app"}},
 {"id":"I33","status":"Todo","content":{"type":"Issue","number":53,"repository":"acme/app"}},
 {"id":"I34","status":"Done","content":{"type":"Issue","number":54,"repository":"acme/app"}},
 {"id":"I35","status":"In Progress","content":{"type":"Issue","number":55,"repository":"acme/app"}},
 {"id":"I36","status":"In Progress","content":{"type":"Issue","number":56,"repository":"acme/other"}},
 {"id":"I37","status":"Todo","content":{"type":"PullRequest","number":57,"repository":"acme/app"}}]}
EOF
echo '[{"number":51},{"number":52},{"number":53},{"number":54},{"number":56},{"number":57}]' > "${FIX}/closed.json"
mk_issue 51 CLOSED COMPLETED "In Progress" "approved"
mk_issue 52 CLOSED COMPLETED "To Be Tested" "approved"
mk_issue 53 CLOSED NOT_PLANNED "Todo" ""
run_ba reconcile schedule '{}'
assert_run "reconcile: approved To Be Tested Done, not planned Canceled, rest untouched" 0 \
    "$(nl 'project item-edit --id ITEM_52 -> OPT_DONE' 'project item-edit --id ITEM_53 -> OPT_CANCELED')"
assert_eq "reconcile: only closed same-repo issues read" "51 52 53" \
    "$(grep -oE '^issue view [0-9]+' <<< "$LOG" | awk '{print $3}' | tr '\n' ' ' | sed 's/ $//')"
assert_eq "reconcile: never reopens" "0" "$(count '^issue reopen')"
jq -n '{items: [range(1000) | {id: "X\(.)", status: "Done", content: {type: "Issue", number: (. + 1000), repository: "acme/app"}}]}' > "${FIX}/items-full.json"
run_ba reconcile schedule '{}' STUB_ITEMS=items-full.json
assert_contains "reconcile: warns at the listing limit" "$OUT" "1000+ items"

# No token: nothing runs
run_ba event issues "$(issue_event closed 11)" GH_TOKEN=
assert_run "no token: nothing" 0 ""
assert_eq "no token: no gh calls" "" "$LOG"

assert_eq "no unexpected gh call in any scenario" "0" "$(grep -c '^UNEXPECTED' "${WORK}/all.log" || true)"

fi

# ---- C) Shipped workflows ------------------------------------------------------------
if part C; then
for wf in project-board-automation.yml project-board-reconcile.yml; do
    t="${ROOT_DIR}/cicd/workflows/${wf}"
    if cmp -s "$t" "${ROOT_DIR}/.github/workflows/${wf}"; then _pass "${wf}: repo copy identical to template"; else _fail "${wf}: repo copy identical to template" "differs"; fi
    assert_contains "${wf}: managed marker" "$(head -1 "$t")" "# cc-managed: "
    assert_eq "${wf}: event data never interpolated into run" "" "$(grep -n 'github\.event\.' "$t" | grep -vE 'group: |ref: ' || true)"
    assert_eq "${wf}: secrets not used in if" "" "$(grep -nE '^[[:space:]]*if:.*secrets\.' "$t" || true)"
    assert_eq "${wf}: least privilege" "contents: read" "$(sed -n '/^permissions:/,/^[a-z]/p' "$t" | grep -E '^[[:space:]]+[a-z-]+:' | sed 's/^ *//')"
    # shellcheck disable=SC2016 # literal workflow expression
    assert_contains "${wf}: script from the default branch" "$(cat "$t")" 'ref: ${{ github.event.repository.default_branch }}'
    assert_contains "${wf}: credentials not persisted" "$(cat "$t")" "persist-credentials: false"
done
assert_eq "no schedule in the event workflow" "" "$(grep -n 'schedule' "${ROOT_DIR}/cicd/workflows/project-board-automation.yml" || true)"

fi

# ---- D) update.sh / install.sh delivery ------------------------------------------------
if part D && command -v python3 &>/dev/null; then
    FW="${WORK}/framework"
    mkdir -p "$FW"
    (cd "$ROOT_DIR" && git ls-files -z -co --exclude-standard | xargs -0 tar -cf - 2>/dev/null) | tar -xf - -C "$FW"
    proj="${WORK}/install"
    mkdir -p "$proj/.github/workflows" && git -C "$proj" init --quiet
    cat > "${proj}/cognitive-core.conf" << 'EOF'
#!/bin/false
CC_PROJECT_NAME="wf-test"
CC_PROJECT_DESCRIPTION="board workflow delivery test"
CC_ORG="acme"
CC_LANGUAGE="python"
CC_LINT_EXTENSIONS=".py"
CC_LINT_COMMAND="ruff check \$1"
CC_FORMAT_COMMAND=""
CC_TEST_COMMAND="pytest"
CC_TEST_PATTERN="tests/**/*.py"
CC_DATABASE="none"
CC_ARCHITECTURE="ddd"
CC_SRC_ROOT="src"
CC_TEST_ROOT="tests"
CC_AGENTS="reviewer"
CC_COORDINATOR_MODEL="opus"
CC_SPECIALIST_MODEL="sonnet"
CC_SKILLS="project-board"
CC_HOOKS="setup-env"
CC_MAIN_BRANCH="main"
CC_COMMIT_FORMAT="conventional"
CC_COMMIT_SCOPES="api"
CC_ENABLE_CICD="true"
CC_RUNNER_TYPE="github-hosted"
CC_MONITORING="true"
CC_COMPACT_RULES="1. Follow standards"
CC_GITHUB_OWNER="acme"
CC_PROJECT_NUMBER="9"
EOF
    wf_auto="${proj}/.github/workflows/project-board-automation.yml"
    wf_rec="${proj}/.github/workflows/project-board-reconcile.yml"
    tpl_auto="${FW}/cicd/workflows/project-board-automation.yml"
    tpl_rec="${FW}/cicd/workflows/project-board-reconcile.yml"
    manifest="${proj}/.claude/cognitive-core/version.json"
    # Never aborts the suite: the exit code is part of the output and asserted
    upd() { env -i PATH="$PATH" HOME="$WORK" bash "${FW}/update.sh" "$proj" < /dev/null 2>&1; echo "UPDATE_RC=$?"; }
    n_upd=0
    upd_ok() { n_upd=$((n_upd + 1)); assert_contains "update run ${n_upd} exits 0" "$1" "UPDATE_RC=0"; }
    sha() { python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"; }
    recorded() { python3 -c 'import json,sys;print(" ".join(sorted(e["path"] for e in json.load(open(sys.argv[1]))["files"] if e["path"].startswith(".github/"))))' "$manifest"; }
    # Unmarked workflows present before install are not recorded, even with a board-like name
    printf 'name: other\n' > "${proj}/.github/workflows/other.yml"
    printf 'name: custom board job\n' > "${proj}/.github/workflows/project-board-custom.yml"
    if env -i PATH="$PATH" HOME="$WORK" bash "${FW}/install.sh" "$proj" >/dev/null 2>&1; then
        _pass "install with CI/CD"
        assert_eq "install records only the managed workflows" \
            ".github/workflows/project-board-automation.yml .github/workflows/project-board-reconcile.yml" "$(recorded)"
        out=$(upd)
        upd_ok "$out"
        assert_eq "unchanged update: no workflow action" "0" "$(grep -cE '(UPDATED|NEW|MODIFIED|REPLACED|LEGACY).*workflow' <<< "$out" || true)"
        assert_eq "unchanged update: workflows not touched by the manifest loop" "0" "$(grep -c '\.github/workflows' <<< "$out" || true)"
        # Template change reaches an unmodified copy
        printf '# template change\n' >> "$tpl_auto"
        out=$(upd)
        upd_ok "$out"
        assert_contains "unmodified workflow updated" "$out" "UPDATED (workflow): .github/workflows/project-board-automation.yml"
        if cmp -s "$tpl_auto" "$wf_auto"; then _pass "updated copy equals the template"; else _fail "updated copy equals the template" "differs"; fi
        assert_contains "commit hint stages the workflows" "$out" "git add .claude/ .github/workflows/"
        printf '# template change 2\n' >> "$tpl_auto"
        out=$(upd)
        upd_ok "$out"
        assert_contains "the update re-recorded the baseline" "$out" "UPDATED (workflow): .github/workflows/project-board-automation.yml"
        # Local edit survives later template changes
        printf '# local\n' >> "$wf_auto"
        local_sha=$(sha "$wf_auto")
        printf '# template change 3\n' >> "$tpl_auto"
        out=$(upd)
        upd_ok "$out"
        assert_contains "edited workflow reported" "$out" "MODIFIED (preserved): .github/workflows/project-board-automation.yml"
        out=$(upd)
        upd_ok "$out"
        assert_eq "edited workflow kept across updates" "$local_sha" "$(sha "$wf_auto")"
        # Marked file without a recorded baseline counts as edited
        cp "$tpl_rec" "$wf_rec" && printf '# local\n' >> "$wf_rec"
        python3 - "$manifest" << 'PY'
import json, sys
m = json.load(open(sys.argv[1])); m["files"] = [e for e in m["files"] if not e["path"].endswith("project-board-reconcile.yml")]
json.dump(m, open(sys.argv[1], "w"), indent=4)
PY
        printf '# template change\n' >> "$tpl_rec"
        out=$(upd)
        upd_ok "$out"
        assert_contains "no baseline: preserved" "$out" "MODIFIED (preserved): .github/workflows/project-board-reconcile.yml"
        assert_contains "no baseline: remedy shown" "$out" "To take the framework copy"
        assert_contains "no baseline: file untouched" "$(tail -1 "$wf_rec")" "# local"
        # Override: an unmodified copy is not updated, a deleted one not recreated
        cp "$tpl_rec" "$wf_rec"
        out=$(upd); upd_ok "$out"
        rec_before=$(cat "$wf_rec")
        chmod u+w "${proj}/cognitive-core.conf"
        printf 'CC_LOCAL_OVERRIDES=".github/workflows/project-board-reconcile.yml"\n' >> "${proj}/cognitive-core.conf"
        printf '# template change 2\n' >> "$tpl_rec"
        out=$(upd)
        upd_ok "$out"
        assert_eq "override: not updated" "$rec_before" "$(cat "$wf_rec")"
        assert_eq "override: counted once" "1" "$(grep -c 'OVERRIDE (project owned): .github/workflows/project-board-reconcile.yml' <<< "$out" || true)"
        rm -f "$wf_rec"
        out=$(upd); upd_ok "$out"
        if [ -e "$wf_rec" ]; then _fail "override: deleted workflow not recreated" "recreated"; else _pass "override: deleted workflow not recreated"; fi
        sed -i.bak '/^CC_LOCAL_OVERRIDES=/d' "${proj}/cognitive-core.conf" && rm -f "${proj}/cognitive-core.conf.bak"
        # Symlinked workflow: skipped, target untouched
        printf 'name: target\n' > "${WORK}/target.yml"
        ln -sf "${WORK}/target.yml" "$wf_rec"
        out=$(upd)
        upd_ok "$out"
        assert_contains "symlinked workflow skipped" "$out" "SKIP (symlink): .github/workflows/project-board-reconcile.yml"
        assert_eq "symlink target untouched" "name: target" "$(cat "${WORK}/target.yml")"
        rm -f "$wf_rec"
        # Configured legacy workflow (even with a leftover placeholder): warned, untouched
        printf 'name: Project Board Automation\nenv:\n  PROJECT_ID: "PVT_real"\n  ROADMAP_ID: "replace_me"\n' > "$wf_auto"
        out=$(upd)
        upd_ok "$out"
        assert_contains "configured legacy warned" "$out" "LEGACY: .github/workflows/project-board-automation.yml"
        assert_contains "legacy warning names the forgeable approval" "$out" "forgeable 'Approved by @' comment"
        assert_eq "configured legacy untouched" '  ROADMAP_ID: "replace_me"' "$(tail -1 "$wf_auto")"
        if [ -e "$wf_rec" ]; then _fail "no reconcile next to a legacy workflow" "added"; else _pass "no reconcile next to a legacy workflow"; fi
        # Unconfigured legacy template: replaced, reconcile added and recorded
        printf 'name: Project Board Automation\nenv:\n  PROJECT_ID: "PVT_xxx"\n' > "$wf_auto"
        out=$(upd)
        upd_ok "$out"
        assert_contains "unconfigured legacy replaced" "$out" "REPLACED (unconfigured legacy workflow): .github/workflows/project-board-automation.yml"
        if cmp -s "$tpl_rec" "$wf_rec"; then _pass "reconcile workflow added"; else _fail "reconcile workflow added" "missing or different"; fi
        printf '# template change 3\n' >> "$tpl_rec"
        out=$(upd)
        upd_ok "$out"
        assert_contains "added reconcile workflow was recorded" "$out" "UPDATED (workflow): .github/workflows/project-board-reconcile.yml"
    else
        _fail "install with CI/CD" "install.sh failed"
    fi
elif part D; then
    _skip "python3 not available (needed for update.sh)"
fi

suite_end
