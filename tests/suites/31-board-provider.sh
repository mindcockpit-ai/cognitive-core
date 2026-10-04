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
    "issue list --repo acme/app --state open "*) echo '[]' ;;
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
run_pb -- board blocked 7
assert_eq "${S}blocked" "0|issue edit 7 --repo acme/app --add-label blocked" "${RC}|${CALLS}"
run_pb -- board unblock 7
assert_eq "${S}unblock" "0|issue edit 7 --repo acme/app --remove-label blocked" "${RC}|${CALLS}"

# ---- List ----
run_pb -- issue list
assert_eq "${S}issue list without filters (bash 3.2 empty arrays)" \
    "0|issue list --repo acme/app --state open --json number,title,labels,assignees" "${RC}|${CALLS}"
run_pb -- board list --sprint "Sprint 4"
assert_eq "${S}board list --sprint: filtered" "0|[(7, 'In Progress', 'Sprint 4')]" \
    "${RC}|$(python3 -c 'import json,sys; print([(i["number"],i["status"],i["sprint"]) for i in json.loads(sys.argv[1])])' "$OUT" 2>&1)"
run_pb -- board list --sprint
assert_eq "${S}board list --sprint without title: exit 1, no gh call" "1|" "${RC}|${CALLS}"
run_pb -- board list
assert_eq "${S}board list: all items" "[7, 9]" \
    "$(python3 -c 'import json,sys; print([i["number"] for i in json.loads(sys.argv[1])])' "$OUT" 2>&1)"
}

SHELL_UNDER_TEST="$BASH"
run_cases ""
if [ -x /bin/bash ] && [ "$(/bin/bash -c 'echo ${BASH_VERSINFO[0]}')" = "3" ]; then
    SHELL_UNDER_TEST=/bin/bash
    run_cases "bash 3.2: "
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

assert_eq "no unexpected gh call in any case" "0" "$(grep -c '^UNEXPECTED' "${WORK}/all.log" || true)"

suite_end
