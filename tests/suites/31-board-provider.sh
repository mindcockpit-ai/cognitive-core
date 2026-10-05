#!/bin/bash
# Test suite: project-board GitHub provider against a strict gh stub (#363)
# Every case asserts the exact gh calls; any call the stub does not know fails the case.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "31 - Board Provider"

PB="${ROOT_DIR}/core/skills/project-board"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
STUB="${WORK}/bin"
FIX="${WORK}/fix"
PROJ="${WORK}/proj"
mkdir -p "$STUB" "$FIX" "$PROJ"
: > "${WORK}/all.log"

cat > "${STUB}/gh" << 'STUBEOF'
#!/bin/bash
# Answers only the calls the provider is expected to make
line="$*"
printf '%s\n' "${line//$'\n'/\\n}" | tee -a "${STUB_ALL}" >> "${STUB_LOG}"
fail() { [ -n "${1:-}" ] && { echo "$1" >&2; exit 1; }; return 0; }
case "$line" in
    "api graphql -f owner=acme -f repo=app -F n="*" -f query=query("*)
        fail "${STUB_FAIL_GQL:-}"; [ -n "${STUB_GQL_GARBAGE:-}" ] && { echo "<html>busy</html>"; exit 0; }
        n="${8#n=}"; f="${STUB_FIX}/item-$n.json"
        if [ -f "$f" ]; then cat "$f"; else echo '{"data":{"repository":{"issueOrPullRequest":null}}}'; fi ;;
    "project field-list 9 --owner acme --format json --limit 100") fail "${STUB_FAIL_FIELDS:-}"; cat "${STUB_FIX}/${STUB_FIELDS:-fields.json}" ;;
    "project item-edit --id ITEM_"[0-9]" --project-id PROJ_1 --field-id FIELD_1 --single-select-option-id OPT_"[A-Z_]*) fail "${STUB_FAIL_EDIT:-}" ;;
    "project item-list 9 --owner acme --format json --limit 500") fail "${STUB_FAIL_ITEMS:-}"; cat "${STUB_FIX}/items.json" ;;
    "issue view "*" --repo acme/app --json number,title,body,state,labels,assignees,url")
        printf '{"number":%s,"body":"no criteria","url":"u"}\n' "$3" ;;
    "issue close "*" --repo acme/app --comment "*) fail "${STUB_FAIL_CLOSE:-}" ;;
    "issue comment "*" --repo acme/app --body "*) fail "${STUB_FAIL_COMMENT:-}" ;;
    "issue edit "[0-9]" --repo acme/app --add-label "*|"issue edit "[0-9]" --repo acme/app --remove-label "*) fail "${STUB_FAIL_LABEL:-}" ;;
    "issue list --repo acme/app --state "*) echo '[]' ;;
    "project view 9 --owner acme --format json") fail "${STUB_FAIL_VIEW:-}"; echo '{"id":"PROJ_1","number":9,"title":"Board"}' ;;
    "label list --repo acme/app --json name --limit 1000")
        fail "${STUB_FAIL_LABELS:-}"; cat "${STUB_FIX}/${STUB_LABELS:-labels.txt}" "${STUB_FIX}/labels.created" 2>/dev/null \
            | awk 'BEGIN { printf "[" } NF { printf "%s{\"name\":\"%s\"}", (n++ ? "," : ""), $0 } END { print "]" }' ;;
    "workflow list --repo acme/app --all --limit 500 --json name,path,state")
        fail "${STUB_FAIL_WF:-}"; cat "${STUB_FIX}/${STUB_WF:-wf.json}" ;;
    "label create "*" --repo acme/app --color "*" --description "*) fail "${STUB_FAIL_LABEL_CREATE:-}"; echo "$3" >> "${STUB_FIX}/labels.created" ;;
    "issue develop 7 --repo acme/app --list") printf 'fix/7-old\thttps://github.com/acme/app/tree/fix/7-old\n' ;;
    "issue edit "[0-9]" --repo acme/app --body "*) fail "${STUB_FAIL_LABEL:-}" ;;
    *) echo "UNEXPECTED: $line" | tee -a "${STUB_ALL}" >> "${STUB_LOG}"; exit 99 ;;
esac
STUBEOF
chmod +x "${STUB}/gh"

cat > "${FIX}/fields.json" << 'EOF'
{"fields":[{"id":"FIELD_0","name":"Title"},
 {"id":"FIELD_1","name":"Status","options":[
  {"id":"OPT_ROADMAP","name":"Roadmap"},{"id":"OPT_BACKLOG","name":"Backlog"},{"id":"OPT_TODO","name":"Todo"},
  {"id":"OPT_PROGRESS","name":"In Progress"},{"id":"OPT_TESTING","name":"To Be Tested"},
  {"id":"OPT_DONE","name":"Done"},{"id":"OPT_CANCELED","name":"Canceled"}]},
 {"id":"FIELD_X","name":"Other","options":[{"id":"OPT_WRONG","name":"To Be Tested"}]}]}
EOF
# Renamed column: QA (OPT_QA) instead of To Be Tested
sed 's/{"id":"OPT_TESTING","name":"To Be Tested"}/{"id":"OPT_QA","name":"QA"}/' "${FIX}/fields.json" > "${FIX}/fields-renamed.json"

printf 'approved\nblocked\nbug\n' > "${FIX}/labels.txt"
printf 'approved\nbug\n' > "${FIX}/labels-noblocked.txt"
wf() { # <automation state|none> <reconcile state>
    python3 -c '
import json, sys
out = []
for name, state in (("project-board-automation.yml", sys.argv[1]), ("project-board-reconcile.yml", sys.argv[2])):
    if state != "none":
        out.append({"name": name, "path": ".github/workflows/" + name, "state": state})
print(json.dumps(out))' "$1" "$2"
}
wf active active > "${FIX}/wf.json"
wf disabled_inactivity active > "${FIX}/wf-disabled.json"
wf active disabled_manually > "${FIX}/wf-reconcile-disabled.json"
printf 'Approved\nBLOCKED\n' > "${FIX}/labels-case.txt"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); d["fields"]=[f for f in d["fields"] if f["name"]!="Status"]; print(json.dumps(d))' "${FIX}/fields.json" > "${FIX}/fields-nostatus.json"
wf none active > "${FIX}/wf-missing.json"

# mk_item <n> <project id> <status> : GraphQL answer for issue n with one board item
mk_item() {
    cat > "${FIX}/item-$1.json" << EOF
{"data":{"repository":{"issueOrPullRequest":{"assignees":{"nodes":[{"login":"ann"}]},"projectItems":{"nodes":[
 {"id":"ITEM_OTHER","project":{"id":"PROJ_OTHER"},"status":{"name":"Done","optionId":"o"},"sprint":null},
 {"id":"ITEM_$1","project":{"id":"$2"},"status":{"name":"$3","optionId":"OPT_X"},"sprint":{"title":"Sprint 4"}}]}}}}}
EOF
}
mk_item 7 PROJ_1 "In Progress"
mk_item 8 PROJ_OTHER "Todo"          # only on another board
mk_item 9 PROJ_1 "To Be Tested"

cat > "${FIX}/items.json" << 'EOF'
{"items":[
 {"id":"ITEM_7","status":"In Progress","sprint":{"title":"Sprint 4"},"content":{"number":7,"title":"Seven"}},
 {"id":"ITEM_9","status":"To Be Tested","sprint":"","content":{"number":9,"title":"Nine"}}]}
EOF

BASE_CONF='CC_GITHUB_OWNER="acme"
CC_GITHUB_REPO="acme/app"
CC_PROJECT_NUMBER="9"
CC_PROJECT_ID="PROJ_1"
CC_STATUS_FIELD_ID="FIELD_1"'
conf() { printf '%s\n%s\n' "$BASE_CONF" "${1:-}" > "${PROJ}/cognitive-core.conf"; }

# run_pb [VAR=value ...] -- <provider args>
# Clean environment. Sets RC, OUT (stdout), ERR (stderr), CALLS (gh calls, query text shortened).
run_pb() {
    local -a envs=()
    while [ "$1" != "--" ]; do envs+=("$1"); shift; done
    shift
    : > "${WORK}/log"
    env -i PATH="${STUB}:${PATH}" HOME="$WORK" TMPDIR="${TMPDIR:-/tmp}" \
        STUB_LOG="${WORK}/log" STUB_ALL="${WORK}/all.log" STUB_FIX="$FIX" PROJECT_DIR="$PROJ" \
        ${envs[@]+"${envs[@]}"} "$SHELL_UNDER_TEST" "${PB}/providers/github.sh" "$@" \
        > "${WORK}/out" 2> "${WORK}/err" && RC=0 || RC=$?
    OUT=$(cat "${WORK}/out")
    ERR=$(cat "${WORK}/err")
    CALLS=$(sed -E 's/^api graphql -f owner=acme -f repo=app -F n=([0-9]+) -f query=query\(.*/graphql item \1/' "${WORK}/log")
}

# run_setup [VAR=value ...] -- <setup.sh args>: like run_pb, for setup.sh
run_setup() {
    local -a envs=()
    while [ "$1" != "--" ]; do envs+=("$1"); shift; done
    shift
    : > "${WORK}/log"
    (cd "$WORK" && env -i PATH="${STUB}:${PATH}" HOME="$WORK" TMPDIR="${TMPDIR:-/tmp}" \
        STUB_LOG="${WORK}/log" STUB_ALL="${WORK}/all.log" STUB_FIX="$FIX" PROJECT_DIR="$PROJ" \
        ${envs[@]+"${envs[@]}"} "$SHELL_UNDER_TEST" "${PB}/setup.sh" "$@") \
        > "${WORK}/out" 2> "${WORK}/err" && RC=0 || RC=$?
    OUT=$(cat "${WORK}/out")
    ERR=$(cat "${WORK}/err")
    CALLS=$(cat "${WORK}/log")
}

finding_keys() { python3 -c 'import json,sys; print(" ".join("%s:%s" % (f["level"], f["key"]) for f in json.loads(sys.argv[1])["findings"]))' "$1" 2>&1; }

json_get() { python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print(d[sys.argv[2]])' "$1" "$2" 2>/dev/null || echo "<not json>"; }

run_cases() {
local S="$1"
EDIT='project item-edit --id ITEM_7 --project-id PROJ_1 --field-id FIELD_1 --single-select-option-id'

# ---- Key -> option ID ----
conf 'CC_STATUS_TESTING_ID="OPT_FROM_CONF"'
run_pb -- board move 7 testing
assert_eq "${S}move by key, conf ID: exit 0" "0" "$RC"
assert_eq "${S}move by key, conf ID: exact calls" "graphql item 7
${EDIT} OPT_FROM_CONF" "$CALLS"
assert_eq "${S}move by key: message" "Issue #7 moved to To Be Tested" "$(json_get "$OUT" message)"

conf
run_pb -- board move 7 testing
assert_eq "${S}move by key, live: field-list, lookup, edit" "project field-list 9 --owner acme --format json --limit 100
graphql item 7
${EDIT} OPT_TESTING" "$CALLS"

conf
run_pb STUB_FIELDS=fields-renamed.json -- board move 7 testing
assert_eq "${S}renamed column without map: exit 1" "1" "$RC"
assert_contains "${S}renamed column without map: names the column" "$ERR" "No column 'To Be Tested'"
assert_not_contains "${S}renamed column without map: no edit" "$CALLS" "item-edit"

conf 'CC_GITHUB_STATUS_MAP="testing=QA"'
run_pb STUB_FIELDS=fields-renamed.json -- board move 7 testing
assert_eq "${S}renamed column with map: edit uses OPT_QA" "project field-list 9 --owner acme --format json --limit 100
graphql item 7
${EDIT} OPT_QA" "$CALLS"

conf
for k in done:OPT_DONE canceled:OPT_CANCELED roadmap:OPT_ROADMAP; do
    run_pb -- board move 7 "${k%%:*}"
    assert_eq "${S}move ${k%%:*}: option ${k#*:}" "0|${EDIT} ${k#*:}" "${RC}|$(grep item-edit <<< "$CALLS")"
done

conf 'CC_STATUS_TESTING_ID="OPT_FROM_CONF"'
run_pb -- board move 7 testing OPT_EXPLICIT
assert_eq "${S}3-argument move: explicit ID wins" "graphql item 7
${EDIT} OPT_EXPLICIT" "$CALLS"

run_pb -- board move 7 review
assert_eq "${S}unknown key: exit 1" "1" "$RC"
assert_contains "${S}unknown key: lists keys" "$ERR" "roadmap|backlog|todo|progress|testing|done|canceled"
assert_eq "${S}unknown key: no gh call" "" "$CALLS"

for bad in abc "7;x" "7 --x" "@/etc/passwd" ""; do
    run_pb -- board move "$bad" testing
    assert_eq "${S}invalid issue '${bad}': exit 1, no gh call" "1|" "${RC}|${CALLS}"
done
run_pb -- board move 7 testing --single
assert_eq "${S}option ID that looks like a flag: exit 1, no gh call" "1|" "${RC}|${CALLS}"

# ---- Lookup: not found vs backend failure ----
run_pb -- board move 8 testing
assert_eq "${S}item only on another board: exit 1" "1" "$RC"
assert_contains "${S}item only on another board: not found" "$ERR" "Issue #8 not found on project board"
assert_not_contains "${S}item only on another board: no edit" "$CALLS" "item-edit"

RL="GraphQL: API rate limit exceeded for user ID 1."
for cmd in "board move 7 testing" "board status 7"; do
    # shellcheck disable=SC2086
    run_pb STUB_FAIL_GQL="$RL" -- $cmd
    assert_eq "${S}${cmd}, rate limit: exit 2" "2" "$RC"
    assert_contains "${S}${cmd}, rate limit: gh message passed through" "$ERR" "$RL"
    assert_not_contains "${S}${cmd}, rate limit: not reported as not found" "$ERR" "not found"
    assert_eq "${S}${cmd}, rate limit: stderr is valid JSON" "ok" \
        "$(python3 -c 'import json,sys; json.loads(sys.argv[1]); print("ok")' "$ERR" 2>&1)"
done

NF="GraphQL: Could not resolve to an issue or pull request with the number of 99999. (repository.issueOrPullRequest)"
run_pb STUB_FAIL_GQL="$NF" -- board status 99999
assert_eq "${S}nonexistent issue: exit 1 (not a backend failure)" "1" "$RC"
assert_eq "${S}nonexistent issue: one error line" '{"error": "Issue #99999 not found on board"}' "$ERR"

run_pb STUB_GQL_GARBAGE=1 -- board status 7
assert_eq "${S}unparseable gh answer: exit 2" "2" "$RC"
assert_not_contains "${S}unparseable gh answer: not reported as not found" "$ERR" "not found"

conf
run_pb STUB_FAIL_FIELDS="HTTP 401: Bad credentials" -- board move 7 testing
assert_eq "${S}field-list failure: exit 2, no lookup" "2|project field-list 9 --owner acme --format json --limit 100" "${RC}|${CALLS}"

conf 'CC_STATUS_TESTING_ID="OPT_STALE"'
run_pb STUB_FAIL_EDIT='GraphQL: The single select option Id does not belong to the field' -- board move 7 testing
assert_eq "${S}edit failure: exit 2" "2" "$RC"
assert_contains "${S}edit failure: gh message" "$ERR" "does not belong to the field"

# ---- Status ----
run_pb -- board status 7
assert_eq "${S}status: exit 0, one call" "0|graphql item 7" "${RC}|${CALLS}"
assert_eq "${S}status: this board's item" \
    "In Progress|ITEM_7|Sprint 4|['ann']|https://github.com/acme/app/issues/7" \
    "$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print("|".join(str(d[k]) for k in ("status","item_id","sprint","assignees","url")))' "$OUT" 2>&1)"
run_pb -- board status 8
assert_eq "${S}status, other board only: exit 1" "1" "$RC"
assert_contains "${S}status, other board only: not found" "$ERR" "not found on board"

# ---- Close ----
run_pb -- issue close 7 --comment "Canceled: duplicate"
assert_eq "${S}cancel: exit 0" "0" "$RC"
assert_eq "${S}cancel: guard lookup, closed as not planned" "graphql item 7
issue close 7 --repo acme/app --comment Canceled: duplicate --reason not planned" "$CALLS"
run_pb -- issue close 7 --comment "Shipped"
assert_eq "${S}close: guard lookup and criteria check, no reason" "graphql item 7
issue view 7 --repo acme/app --json number,title,body,state,labels,assignees,url
issue close 7 --repo acme/app --comment Shipped - Closed via /project-board - Approved by @system" "$CALLS"
run_pb -- issue close 9 --comment "Shipped"
assert_eq "${S}close from To Be Tested: refused by the gate, no close" "1|graphql item 9" "${RC}|${CALLS}"
assert_contains "${S}close from To Be Tested: points to approve" "$ERR" "/project-board approve 9"
run_pb STUB_FAIL_GQL="$RL" -- issue close 9 --comment "Shipped"
assert_not_contains "${S}close, rate limit: no close call" "$CALLS" "issue close"
run_pb STUB_FAIL_CLOSE="HTTP 403" -- issue close 7 --comment "Canceled: x"
assert_eq "${S}close failure: exit 2, no success message" "2|" "${RC}|${OUT}"

# ---- Silent failures are gone ----
run_pb STUB_FAIL_COMMENT="HTTP 502" -- issue comment 7 "hello"
assert_eq "${S}comment failure: exit 2, no success message" "2|" "${RC}|${OUT}"

# ---- Labels, blocked ----
run_pb -- issue label 7 --add needs-info
assert_eq "${S}label add" "0|issue edit 7 --repo acme/app --add-label needs-info" "${RC}|${CALLS}"
run_pb -- issue label 7 --add 'say "hi"'
assert_eq "${S}success message with quotes is valid JSON" 'Label say "hi" added to #7' "$(json_get "$OUT" message)"
run_pb -- issue label 7 --add
assert_eq "${S}label add without label: exit 1, no gh call" "1|" "${RC}|${CALLS}"
run_pb -- issue label 7 --remove needs-info
assert_eq "${S}label remove" "0|issue edit 7 --repo acme/app --remove-label needs-info" "${RC}|${CALLS}"
run_pb -- issue label 7 needs-info
assert_eq "${S}label without --add/--remove: exit 1, no gh call" "1|" "${RC}|${CALLS}"
run_pb -- issue edit 7 --body "**Parent**: #100"
assert_eq "${S}edit body" "0|issue edit 7 --repo acme/app --body **Parent**: #100" "${RC}|${CALLS}"
run_pb STUB_FAIL_LABEL="HTTP 502" -- issue edit 7 --body "x"
assert_eq "${S}edit failure: exit 2, no success message" "2|" "${RC}|${OUT}"
run_pb -- issue edit 7 --title "new title"
assert_eq "${S}edit with another flag: exit 1, no gh call" "1|" "${RC}|${CALLS}"
run_pb -- board blocked 7
assert_eq "${S}blocked" "0|issue edit 7 --repo acme/app --add-label blocked" "${RC}|${CALLS}"
run_pb -- board unblock 7
assert_eq "${S}unblock" "0|issue edit 7 --repo acme/app --remove-label blocked" "${RC}|${CALLS}"

# ---- List ----
run_pb -- issue list
assert_eq "${S}issue list without filters (bash 3.2 empty arrays)" \
    "0|issue list --repo acme/app --state open --json number,title,labels,assignees" "${RC}|${CALLS}"
run_pb -- issue list --limit 200 --json number,labels
assert_eq "${S}issue list --limit" "0|issue list --repo acme/app --state open --limit 200 --json number,labels" "${RC}|${CALLS}"
run_pb -- issue list --state closed
assert_eq "${S}closed list keeps its default limit" "0|issue list --repo acme/app --state closed --limit 10 --json number,title,labels,assignees" "${RC}|${CALLS}"
run_pb -- issue list --limit 2x
assert_eq "${S}issue list --limit not a number: exit 1, no gh call" "1|" "${RC}|${CALLS}"
run_pb -- branch create 7 fix login-bug
assert_eq "${S}existing branch: name only, valid JSON" "fix/7-old|False|main" \
    "$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print("%s|%s|%s" % (d["branch"], d["created"], d["base"]))' "$OUT" 2>&1)"
run_pb -- board list --sprint "Sprint 4"
assert_eq "${S}board list --sprint: filtered" "0|[(7, 'In Progress', 'Sprint 4')]" \
    "${RC}|$(python3 -c 'import json,sys; print([(i["number"],i["status"],i["sprint"]) for i in json.loads(sys.argv[1])])' "$OUT" 2>&1)"
run_pb -- board list --sprint
assert_eq "${S}board list --sprint without title: exit 1, no gh call" "1|" "${RC}|${CALLS}"
run_pb -- board list
assert_eq "${S}board list: all items" "[7, 9]" \
    "$(python3 -c 'import json,sys; print([i["number"] for i in json.loads(sys.argv[1])])' "$OUT" 2>&1)"
}

run_check_cases() {
local S="$1"
CHECK_CALLS='project view 9 --owner acme --format json
project field-list 9 --owner acme --format json --limit 100
label list --repo acme/app --json name --limit 1000
workflow list --repo acme/app --all --limit 500 --json name,path,state'
IDS='CC_STATUS_ROADMAP_ID="OPT_ROADMAP"
CC_STATUS_BACKLOG_ID="OPT_BACKLOG"
CC_STATUS_TODO_ID="OPT_TODO"
CC_STATUS_PROGRESS_ID="OPT_PROGRESS"
CC_STATUS_TESTING_ID="OPT_TESTING"
CC_STATUS_DONE_ID="OPT_DONE"
CC_STATUS_CANCELED_ID="OPT_CANCELED"'
rm -f "${FIX}/labels.created"

# ---- provider check ----
conf "$IDS"
run_pb -- provider check
assert_eq "${S}check clean: exit 0, exact calls" "0|${CHECK_CALLS}" "${RC}|${CALLS}"
assert_eq "${S}check clean: no findings" "" "$(finding_keys "$OUT")"
assert_eq "${S}check clean: ok, live options" "True||7" \
    "$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print(d["ok"], "", len(d["live"]["options"]), sep="|")' "$OUT" 2>&1)"

for c in 'CC_STATUS_DONE_ID="OPT_GONE"|error:CC_STATUS_DONE_ID|option ID not on the board' \
         'CC_STATUS_DONE_ID="OPT_TODO"|error:CC_STATUS_DONE_ID|points to column '"'"'Todo'"'"', expected '"'"'Done'"'" \
         'CC_STATUS_FIELD_ID="FIELD_X"|error:CC_STATUS_FIELD_ID|Status field ID does not match' \
         'CC_PROJECT_ID="PROJ_OLD"|error:CC_PROJECT_ID|project ID does not match'; do
    IFS='|' read -r line key msg <<< "$c"
    conf "$IDS
$line"
    run_pb -- provider check
    assert_eq "${S}drift ${line}: exit 1, one finding" "1|${key}" "${RC}|$(finding_keys "$OUT")"
    assert_contains "${S}drift ${line}: message" "$OUT" "$msg"
done

conf "$IDS"
run_pb STUB_LABELS=labels-noblocked.txt -- provider check
assert_eq "${S}missing label: exit 1, finding" "1|error:label:blocked" "${RC}|$(finding_keys "$OUT")"
run_pb STUB_WF=wf-disabled.json -- provider check
assert_eq "${S}disabled workflow: exit 1, finding" "1|error:workflow:project-board-automation.yml" "${RC}|$(finding_keys "$OUT")"
assert_contains "${S}disabled workflow: enable hint" "$OUT" "gh workflow enable project-board-automation.yml"
run_pb STUB_WF=wf-reconcile-disabled.json -- provider check
assert_eq "${S}disabled reconcile workflow: exit 1, finding" "1|error:workflow:project-board-reconcile.yml" "${RC}|$(finding_keys "$OUT")"
run_pb STUB_LABELS=labels-case.txt -- provider check
assert_eq "${S}labels in other case: no finding" "0|" "${RC}|$(finding_keys "$OUT")"
run_pb STUB_FAIL_LABELS="HTTP 502" -- provider check
assert_eq "${S}label list fails: exit 2, stops there" "2|label list --repo acme/app --json name --limit 1000" "${RC}|$(tail -1 <<< "$CALLS")"
run_pb STUB_FIELDS=fields-nostatus.json -- provider check
assert_eq "${S}no Status field: error" "1" "$RC"
assert_contains "${S}no Status field: message" "$OUT" "the board has no Status field"
run_pb STUB_WF=wf-missing.json -- provider check
assert_eq "${S}workflow not installed: info only, exit 0" "0|info:workflow:project-board-automation.yml" "${RC}|$(finding_keys "$OUT")"
run_pb STUB_FAIL_WF="HTTP 403: Resource not accessible" -- provider check
assert_eq "${S}workflow list fails: warning, exit 0" "0|warn:workflows" "${RC}|$(finding_keys "$OUT")"
conf
run_pb STUB_FIELDS=fields-renamed.json -- provider check
assert_eq "${S}renamed column, no map, no IDs: warning only" "0|warn:CC_STATUS_TESTING_ID" "${RC}|$(finding_keys "$OUT")"
conf 'CC_GITHUB_STATUS_MAP="testing=QA"'
run_pb STUB_FIELDS=fields-renamed.json -- provider check
assert_eq "${S}renamed column with map: live option" "0|OPT_QA" \
    "${RC}|$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["live"]["options"]["testing"])' "$OUT" 2>&1)"
conf 'CC_BOARD_PROVIDER="github"'
run_pb -- provider check
assert_eq "${S}old provider key: info finding" "0|info:CC_BOARD_PROVIDER" "${RC}|$(finding_keys "$OUT")"
run_pb STUB_FAIL_VIEW="GraphQL: API rate limit exceeded" -- provider check
assert_eq "${S}check, gh failure: exit 2, stops" "2|project view 9 --owner acme --format json" "${RC}|${CALLS}"
printf 'CC_GITHUB_OWNER="acme"\nCC_GITHUB_REPO="acme/app"\nCC_PROJECT_NUMBER="9"\n' > "${PROJ}/cognitive-core.conf"
run_pb -- provider check
assert_eq "${S}check without project and field IDs: runs, reports both" "1|error:CC_PROJECT_ID error:CC_STATUS_FIELD_ID" "${RC}|$(finding_keys "$OUT")"

printf 'CC_PROJECT_BOARD_PROVIDER="jira"\nCC_JIRA_URL="https://x"\nCC_JIRA_PROJECT="X"\nCC_JIRA_TOKEN="t"\n' > "${PROJ}/cognitive-core.conf"
RC=0; env -i PATH="${STUB}:${PATH}" HOME="$WORK" PROJECT_DIR="$PROJ" "$SHELL_UNDER_TEST" "${PB}/providers/jira.sh" provider check >/dev/null 2>&1 || RC=$?
assert_eq "${S}jira provider check: not supported (exit 3)" "3" "$RC"

# ---- setup.sh usage ----
run_setup -- -h
assert_eq "${S}setup -h: exit 0, usage" "0|3" "${RC}|$(grep -c 'setup.sh' <<< "$OUT")"
for a in "" "--chek x" "acme"; do
    # shellcheck disable=SC2086
    run_setup -- $a
    assert_eq "${S}setup '${a}': exit 1, no gh call" "1|" "${RC}|${CALLS}"
done
run_setup -- --sync acme app
assert_eq "${S}setup --sync with 2 args: exit 1, no gh call" "1|" "${RC}|${CALLS}"

# ---- setup.sh --check ----
conf "$IDS"
run_setup -- --check
assert_eq "${S}setup --check clean" "0|Board check: OK" "${RC}|${OUT}"
conf "$IDS
CC_STATUS_DONE_ID=\"OPT_GONE\""
run_setup -- --check
assert_eq "${S}setup --check drift: exit 1" "1" "$RC"
assert_contains "${S}setup --check drift: readable line" "$OUT" "[error] CC_STATUS_DONE_ID: option ID not on the board (conf: OPT_GONE, board: OPT_DONE)"
run_setup STUB_FAIL_VIEW="HTTP 401" -- --check
assert_eq "${S}setup --check gh failure: exit 2, no report" "2|" "${RC}|${OUT}"
printf 'CC_GITHUB_OWNER="acme"\nCC_GITHUB_REPO="acme/app"\n' > "${PROJ}/cognitive-core.conf"
run_setup -- --check
assert_eq "${S}setup --check config error: exit 1, no report" "1|" "${RC}|${OUT}"
assert_contains "${S}setup --check config error: provider message" "$ERR" "Missing GitHub config: CC_PROJECT_NUMBER"
assert_not_contains "${S}setup --check config error: no traceback" "$ERR" "Traceback"
printf 'CC_PROJECT_BOARD_PROVIDER="jira"\nCC_JIRA_URL="https://x"\nCC_JIRA_PROJECT="X"\nCC_JIRA_TOKEN="t"\n' > "${PROJ}/cognitive-core.conf"
run_setup -- --check
assert_eq "${S}setup --check, jira: not supported (exit 3)" "3|" "${RC}|${OUT}"
rm -f "${PROJ}/cognitive-core.conf"
run_setup -- --check
assert_eq "${S}setup --check without conf: exit 1, no gh call" "1|" "${RC}|${CALLS}"
assert_contains "${S}setup --check without conf: message" "$ERR" "cognitive-core.conf not found"
mkdir -p "${PROJ}/.claude"
printf '%s\n%s\n' "$BASE_CONF" "$IDS" > "${PROJ}/.claude/cognitive-core.conf"
run_setup -- --check
assert_eq "${S}setup --check, conf in .claude/" "0|Board check: OK" "${RC}|${OUT}"
rm -f "${PROJ}/.claude/cognitive-core.conf"

# ---- setup.sh --sync ----
printf '# my project\n%s\nCC_PROJECT_ID_OLD="x"\nCC_STATUS_DONE_ID="OPT_GONE"   \nCC_OTHER="keep me"\n  export CC_STATUS_DONE_ID="OPT_OLD"\n' "$BASE_CONF" > "${PROJ}/cognitive-core.conf"
cat > "${WORK}/expected.conf" << 'EOF'
# my project
CC_GITHUB_OWNER="acme"
CC_GITHUB_REPO="acme/app"
CC_PROJECT_NUMBER="9"
CC_PROJECT_ID="PROJ_1"
CC_STATUS_FIELD_ID="FIELD_1"
CC_PROJECT_ID_OLD="x"
CC_STATUS_DONE_ID="OPT_DONE"
CC_OTHER="keep me"

# project-board (setup.sh --sync)
CC_STATUS_ROADMAP_ID="OPT_ROADMAP"
CC_STATUS_BACKLOG_ID="OPT_BACKLOG"
CC_STATUS_TODO_ID="OPT_TODO"
CC_STATUS_PROGRESS_ID="OPT_PROGRESS"
CC_STATUS_TESTING_ID="OPT_TESTING"
CC_STATUS_CANCELED_ID="OPT_CANCELED"
EOF
chmod 664 "${PROJ}/cognitive-core.conf"   # 664: a plain cp under umask 022 would give 644
cp -p "${PROJ}/cognitive-core.conf" "${WORK}/before.conf"
rm -f "${PROJ}/cognitive-core.conf.bak" "${FIX}/labels.created"
run_setup STUB_LABELS=labels-noblocked.txt -- --sync
assert_eq "${S}sync: exit 0 after repair" "0" "$RC"
assert_eq "${S}sync: creates only the missing label" \
    "label create blocked --repo acme/app --color B60205 --description Blocked by impediment" "$(grep '^label create' <<< "$CALLS")"
assert_eq "${S}sync: conf is exactly the expected one (in place, duplicates and export line replaced, prefix key kept)" "same" \
    "$(cmp -s "${WORK}/expected.conf" "${PROJ}/cognitive-core.conf" && echo same || diff "${WORK}/expected.conf" "${PROJ}/cognitive-core.conf")"
assert_eq "${S}sync: backup is the old conf" "same" "$(cmp -s "${WORK}/before.conf" "${PROJ}/cognitive-core.conf.bak" && echo same || echo differs)"
assert_eq "${S}sync: permissions kept (conf, backup)" "-rw-rw-r--|-rw-rw-r--" \
    "$(ls -l "${PROJ}/cognitive-core.conf" | cut -c1-10)|$(ls -l "${PROJ}/cognitive-core.conf.bak" | cut -c1-10)"
assert_contains "${S}sync: final check report" "$OUT" "Board check: OK"
assert_eq "${S}sync: no temp file left" "" "$(find "$PROJ" -name '*.sync.*')"

cp "${PROJ}/cognitive-core.conf.bak" "${WORK}/bak1"
run_setup STUB_LABELS=labels-noblocked.txt -- --sync
assert_eq "${S}sync again: exit 0, no label create, no write" "0||" \
    "${RC}|$(grep '^label create' <<< "$CALLS" || true)|$(grep 'Updated' <<< "$OUT" || true)"
assert_eq "${S}sync again: conf and backup untouched" "same|same" \
    "$(cmp -s "${WORK}/expected.conf" "${PROJ}/cognitive-core.conf" && echo same)|$(cmp -s "${WORK}/bak1" "${PROJ}/cognitive-core.conf.bak" && echo same)"

printf '%s\n%s' "$BASE_CONF" "$IDS" > "${PROJ}/cognitive-core.conf"
rm -f "${PROJ}/cognitive-core.conf.bak"
run_setup -- --sync
assert_eq "${S}sync, conf without final newline: no write, no backup" "0||no" \
    "${RC}|$(grep 'Updated' <<< "$OUT" || true)|$([ -e "${PROJ}/cognitive-core.conf.bak" ] && echo yes || echo no)"

conf
cp "${PROJ}/cognitive-core.conf" "${WORK}/before.conf"
rm -f "${WORK}/marker"
sed "s|\"OPT_DONE\"|\"OPT\$(touch ${WORK}/marker)\"|" "${FIX}/fields.json" > "${FIX}/fields-unsafe.json"
run_setup STUB_FIELDS=fields-unsafe.json -- --sync
assert_eq "${S}sync, unsafe live ID: refused, exit 1" "1" "$RC"
assert_contains "${S}sync, unsafe live ID: message" "$ERR" "Refusing to write CC_STATUS_DONE_ID"
assert_eq "${S}sync, unsafe live ID: conf unchanged, nothing executed" "same|no" \
    "$(cmp -s "${WORK}/before.conf" "${PROJ}/cognitive-core.conf" && echo same)|$([ -e "${WORK}/marker" ] && echo yes || echo no)"

conf
cp "${PROJ}/cognitive-core.conf" "${WORK}/before.conf"
rm -f "${FIX}/labels.created"
run_setup STUB_LABELS=labels-noblocked.txt STUB_FAIL_LABEL_CREATE="HTTP 403" -- --sync
assert_eq "${S}sync, label create fails: exit 2, conf unchanged" "2|same" \
    "${RC}|$(cmp -s "${WORK}/before.conf" "${PROJ}/cognitive-core.conf" && echo same)"

printf 'CC_PROJECT_BOARD_PROVIDER="github"\nCC_GITHUB_OWNER="other"\nCC_GITHUB_REPO="other/web"\nCC_PROJECT_NUMBER="3"\n' > "${PROJ}/cognitive-core.conf"
run_setup -- --sync acme app 9
assert_eq "${S}sync owner repo number over another board: exit 0, reads the new board" "0" "$RC"
assert_eq "${S}sync owner repo number: address and its IDs written" 'CC_GITHUB_OWNER="acme"|CC_GITHUB_REPO="acme/app"|CC_PROJECT_NUMBER="9"|CC_PROJECT_ID="PROJ_1"' \
    "$(grep -E '^CC_(GITHUB_OWNER|GITHUB_REPO|PROJECT_NUMBER|PROJECT_ID)=' "${PROJ}/cognitive-core.conf" | tr '\n' '|' | sed 's/|$//')"

mkdir -p "${PROJ}/real"
printf '%s\n' "$BASE_CONF" > "${PROJ}/real/cc.conf"
rm -f "${PROJ}/cognitive-core.conf"
ln -s real/cc.conf "${PROJ}/cognitive-core.conf"
run_setup -- --sync
assert_eq "${S}sync, symlinked conf: link kept, target updated, backup next to target" "0|link|7|yes" \
    "${RC}|$([ -L "${PROJ}/cognitive-core.conf" ] && echo link)|$(grep -cE '^CC_STATUS_[A-Z]+_ID="OPT_' "${PROJ}/real/cc.conf")|$([ -e "${PROJ}/real/cc.conf.bak" ] && echo yes)"
rm -f "${PROJ}/cognitive-core.conf"

if [ "$(id -u)" != "0" ]; then
    conf
    cp "${PROJ}/cognitive-core.conf" "${WORK}/before.conf"
    chmod 555 "$PROJ"
    run_setup -- --sync
    chmod 755 "$PROJ"
    assert_eq "${S}sync, conf directory read-only: exit 1, conf unchanged" "1|same" \
        "${RC}|$(cmp -s "${WORK}/before.conf" "${PROJ}/cognitive-core.conf" && echo same)"
fi

conf
run_setup STUB_FAIL_VIEW="HTTP 502" -- --sync
assert_eq "${S}sync, gh failure: exit 2, no label create" "2|" "${RC}|$(grep '^label create' <<< "$CALLS" || true)"
rm -f "${FIX}/labels.created"
}

SHELL_UNDER_TEST="$BASH"
run_cases ""
run_check_cases ""
if [ -x /bin/bash ] && [ "$(/bin/bash -c 'echo ${BASH_VERSINFO[0]}')" = "3" ]; then
    SHELL_UNDER_TEST=/bin/bash
    run_cases "bash 3.2: "
    run_check_cases "bash 3.2: "
else
    _skip "bash 3.2 not available (/bin/bash is not 3.x)"
fi

# ---- Library: config alias, JSON escaping ----
alias_of() { # <conf lines>
    printf '%s\n' "$1" > "${PROJ}/cognitive-core.conf"
    env -i PATH="$PATH" HOME="$WORK" PROJECT_DIR="$PROJ" "$BASH" -c \
        'set -euo pipefail; source "$1/_provider-lib.sh"; _pb_load_config; echo "$CC_PROJECT_BOARD_PROVIDER"' -- "$PB"
}
assert_eq "alias: CC_BOARD_PROVIDER alone" "jira" "$(alias_of 'CC_BOARD_PROVIDER="jira"')"
assert_eq "alias: canonical key wins" "youtrack" "$(alias_of 'CC_BOARD_PROVIDER="jira"
CC_PROJECT_BOARD_PROVIDER="youtrack"')"
assert_eq "alias: neither set" "" "$(alias_of 'CC_GITHUB_OWNER="acme"')"

escaped=$(env -i PATH="$PATH" "$BASH" -c 'source "$1/_provider-lib.sh"; _pb_error "say \"hi\" \\ now
next	tab"$'"'"'\r'"'"'end' -- "$PB" 2>&1)
assert_eq "error JSON: quotes, backslash, newline, tab, CR escaped" 'say "hi" \ now next tab end' \
    "$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["error"])' "$escaped" 2>&1)"

# ---- SKILL.md: every board operation is a provider call (#363 part b) ----
SKILL="${PB}/SKILL.md"
assert_eq "SKILL.md: no gh api command" "" "$(grep -nE 'gh +api' "$SKILL" || true)"
assert_eq "SKILL.md: no gh project command" "" "$(grep -nE 'gh +project +[a-z]' "$SKILL" || true)"
assert_eq "SKILL.md: no curl, gh pr or gh issue develop command" "" \
    "$(grep -nE '(^|[$( ])curl +-|gh +pr +[a-z]|gh +issue +develop' "$SKILL" || true)"
assert_eq "SKILL.md: no raw gh issue board operation" "" \
    "$(grep -nE 'gh +issue +(edit|close|comment|create|list|view|reopen)' "$SKILL" || true)"
assert_eq "SKILL.md: no inline GraphQL or ID placeholders" "" \
    "$(grep -nE 'updateProjectV2ItemFieldValue|addProjectV2ItemById|\{\{STATUS_|\{\{AREA_' "$SKILL" || true)"
assert_eq "SKILL.md: metrics no longer offered" "" "$(grep -niE 'board metrics|^argument-hint:.*metrics' "$SKILL" || true)"

# Every $PB_SCRIPT <group> <command> names a command the router accepts (help text = router table)
routes=$("$BASH" -c 'source "$1/_provider-lib.sh"; _pb_route help' -- "$PB" \
    | awk '$1 ~ /^(issue|board|sprint|branch|provider)$/ { n = split($2, c, "|"); for (i = 1; i <= n; i++) print $1 " " c[i] }')
used=$(grep -oE '("?\$\{?PB_SCRIPT\}?"?) +[a-z]+ +[a-z]+' "$SKILL" | awk '{print $2 " " $3}' | sort -u)
n_used=$(grep -c . <<< "$used" || true)
if [ "$n_used" -ge 15 ]; then _pass "SKILL.md: uses ${n_used} distinct provider commands"; else _fail "SKILL.md: only ${n_used} provider commands found"; fi
unknown=$(comm -23 <(printf '%s\n' "$used") <(printf '%s\n' "$routes" | sort -u))
assert_eq "SKILL.md: every provider call is a routed command" "" "$unknown"

# The discovery block runs: missing provider -> error with hint; present -> no error
block=$(awk '/^```bash$/ { inb = 1; buf = ""; next }
    inb && /^```$/ { if (buf ~ /^source \.\/cognitive-core\.conf/) { printf "%s", buf; exit } inb = 0; next }
    inb { buf = buf $0 "\n" }' "$SKILL")
assert_contains "SKILL.md: discovery block found" "$block" 'PB_SCRIPT='
disc() { # <conf line> <provider: yes|no|plain (not executable)> [provider name] [conf path]
    local d f
    d=$(mktemp -d "${WORK}/disc.XXXX")
    mkdir -p "${d}/.claude"
    printf '%s\n' "$1" > "${d}/${4:-cognitive-core.conf}"
    if [ "$2" != no ]; then
        mkdir -p "${d}/.claude/skills/project-board/providers"
        f="${d}/.claude/skills/project-board/providers/${3:-github}.sh"
        : > "$f"
        [ "$2" = plain ] || chmod +x "$f"
    fi
    DISC_RC=0
    (cd "$d" && env -i PATH="$PATH" HOME="$WORK" "$BASH" -c "${block}"$'\n''echo "PB_SCRIPT=$PB_SCRIPT"' 2>&1) || DISC_RC=$?
}
disc 'CC_PROJECT_BOARD_PROVIDER="github"' no > "${WORK}/disc.out"; out=$(cat "${WORK}/disc.out")
assert_eq "discovery, provider missing: stops with exit 1, nothing after it runs" "1|" "${DISC_RC}|$(grep -o 'PB_SCRIPT=.*' <<< "$out" | grep -v ERROR || true)"
assert_contains "discovery, provider missing: error" "$out" "ERROR: project-board provider missing"
assert_contains "discovery, provider missing: hint" "$out" "update.sh"
out=$(disc 'CC_PROJECT_BOARD_PROVIDER="github"' yes)
assert_eq "discovery, provider present: no error, path" "PB_SCRIPT=.claude/skills/project-board/providers/github.sh" "$out"
out=$(disc 'CC_BOARD_PROVIDER="jira"' yes jira)
assert_eq "discovery, old key: jira provider" "PB_SCRIPT=.claude/skills/project-board/providers/jira.sh" "$out"
out=$(disc 'CC_BOARD_PROVIDER="jira"
CC_PROJECT_BOARD_PROVIDER="youtrack"' yes youtrack)
assert_eq "discovery, both keys: canonical wins" "PB_SCRIPT=.claude/skills/project-board/providers/youtrack.sh" "$out"
out=$(disc 'CC_PROJECT_BOARD_PROVIDER="jira"' yes jira .claude/cognitive-core.conf)
assert_eq "discovery, conf in .claude/" "PB_SCRIPT=.claude/skills/project-board/providers/jira.sh" "$out"
disc 'CC_PROJECT_BOARD_PROVIDER="github"' plain > "${WORK}/disc.out"; out=$(cat "${WORK}/disc.out")
assert_eq "discovery, provider not executable: exit 1" "1" "$DISC_RC"
assert_contains "discovery, provider not executable: error" "$out" "ERROR: project-board provider missing"

assert_eq "no unexpected gh call in any case" "0" "$(grep -c '^UNEXPECTED' "${WORK}/all.log" || true)"

suite_end
