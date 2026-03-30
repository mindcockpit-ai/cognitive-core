#!/bin/bash
# Test suite: Project board provider interface and implementations
# Validates all three providers (github, jira, youtrack) implement the
# required interface contract, pass syntax checks, and handle config errors.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "14 — Project Board Providers"

PB_DIR="${ROOT_DIR}/core/skills/project-board"
PROVIDERS_DIR="${PB_DIR}/providers"

# Create a mock _provider-lib.sh that neutralizes config/route for sourcing tests.
# This lets us source providers to test their internal functions without hitting
# the network or needing real config.
MOCK_DIR=$(create_test_dir)
MOCK_PB_DIR="${MOCK_DIR}/project-board"
MOCK_PROVIDERS_DIR="${MOCK_PB_DIR}/providers"
mkdir -p "$MOCK_PROVIDERS_DIR"

cat > "${MOCK_PB_DIR}/_provider-lib.sh" << 'MOCKEOF'
# Mock _provider-lib.sh — provides stubs for testing provider functions
PB_STATUS_DISPLAY_NAMES=(
    "roadmap:Roadmap" "backlog:Backlog" "todo:Todo"
    "progress:In Progress" "testing:To Be Tested"
    "done:Done" "canceled:Canceled"
)
_pb_status_display_name() {
    local key="$1" entry
    for entry in "${PB_STATUS_DISPLAY_NAMES[@]}"; do
        [[ "${entry%%:*}" == "$key" ]] && { echo "${entry#*:}"; return 0; }
    done
    echo "$key"
}
_pb_load_config() { :; }
_pb_json_kv() { local out="{" first=true; while [[ $# -ge 2 ]]; do $first || out+=","; first=false; out+="\"$1\":\"$2\""; shift 2; done; echo "$out}"; }
_pb_error() { echo "{\"error\": \"$1\"}" >&2; }
_pb_die() { _pb_error "$1"; exit 1; }
_pb_success() { echo "{\"ok\":true,\"message\":\"$1\"}"; }
_pb_validate_provider() { :; }
_pb_route() { :; }
pb_board_label_add() { :; }
pb_board_label_remove() { :; }
pb_board_metrics() { :; }
pb_issue_timeline() { :; }
pb_sprint_list() { :; }
pb_sprint_assign() { :; }
pb_branch_create() { :; }
pb_branch_list() { :; }
MOCKEOF

# Append the real _pb_closure_guard from _provider-lib.sh into the mock
# Extract the function (from definition to closing brace) so tests can exercise it
sed -n '/^_pb_closure_guard()/,/^}/p' "${PB_DIR}/_provider-lib.sh" >> "${MOCK_PB_DIR}/_provider-lib.sh"

# Create provider symlinks that point to mock _provider-lib.sh
for p in github jira youtrack; do
    # Copy provider but patch SCRIPT_DIR to use mock dir
    sed "s|SCRIPT_DIR=.*|SCRIPT_DIR='${MOCK_PROVIDERS_DIR}'|" \
        "${PROVIDERS_DIR}/${p}.sh" > "${MOCK_PROVIDERS_DIR}/${p}.sh"
done

# =============================================================================
# Section 1: File existence
# =============================================================================

assert_file_exists "provider-lib: _provider-lib.sh exists" "${PB_DIR}/_provider-lib.sh"
assert_file_exists "provider: github.sh exists" "${PROVIDERS_DIR}/github.sh"
assert_file_exists "provider: jira.sh exists" "${PROVIDERS_DIR}/jira.sh"
assert_file_exists "provider: youtrack.sh exists" "${PROVIDERS_DIR}/youtrack.sh"

# =============================================================================
# Section 2: Syntax validation (bash -n)
# =============================================================================

for provider in github jira youtrack; do
    syntax_output=$(bash -n "${PROVIDERS_DIR}/${provider}.sh" 2>&1) || true
    if [ -z "$syntax_output" ]; then
        _pass "syntax: ${provider}.sh passes bash -n"
    else
        _fail "syntax: ${provider}.sh has syntax errors" "$syntax_output"
    fi
done

syntax_lib=$(bash -n "${PB_DIR}/_provider-lib.sh" 2>&1) || true
if [ -z "$syntax_lib" ]; then
    _pass "syntax: _provider-lib.sh passes bash -n"
else
    _fail "syntax: _provider-lib.sh has syntax errors" "$syntax_lib"
fi

# =============================================================================
# Section 3: Provider-lib contract (sourcing and shared functions)
# =============================================================================

lib_fns=$(bash -c "
    source '${PB_DIR}/_provider-lib.sh'
    for fn in _pb_load_config _pb_json_kv _pb_error _pb_die _pb_success \
              _pb_status_display_name _pb_validate_provider _pb_route \
              pb_board_label_add pb_board_label_remove pb_board_metrics \
              pb_issue_timeline pb_sprint_list pb_sprint_assign \
              pb_branch_create pb_branch_list; do
        if declare -F \"\$fn\" >/dev/null 2>&1; then
            echo \"\$fn:ok\"
        else
            echo \"\$fn:missing\"
        fi
    done
" 2>&1)

for fn in _pb_load_config _pb_json_kv _pb_error _pb_die _pb_success \
          _pb_status_display_name _pb_validate_provider _pb_route; do
    if echo "$lib_fns" | grep -qF "${fn}:ok"; then
        _pass "provider-lib: defines ${fn}"
    else
        _fail "provider-lib: missing ${fn}"
    fi
done

# Test default stubs for optional functions exist in provider-lib
for fn in pb_board_label_add pb_board_label_remove pb_board_metrics \
          pb_issue_timeline pb_sprint_list pb_sprint_assign \
          pb_branch_create pb_branch_list; do
    if echo "$lib_fns" | grep -qF "${fn}:ok"; then
        _pass "provider-lib: default stub for ${fn}"
    else
        _fail "provider-lib: missing default stub for ${fn}"
    fi
done

# =============================================================================
# Section 4: Status display name mapping
# =============================================================================

for pair in "roadmap:Roadmap" "backlog:Backlog" "todo:Todo" \
            "progress:In Progress" "testing:To Be Tested" \
            "done:Done" "canceled:Canceled"; do
    key="${pair%%:*}"
    expected="${pair#*:}"
    actual=$(bash -c "
        source '${PB_DIR}/_provider-lib.sh'
        _pb_status_display_name '$key'
    " 2>&1)
    assert_eq "status-display: ${key} → ${expected}" "$expected" "$actual"
done

# =============================================================================
# Section 5: Provider validation function
# =============================================================================

validate_missing=$(bash -c "
    source '${PB_DIR}/_provider-lib.sh'
    _pb_validate_provider 2>&1
" 2>&1) || true
assert_contains "validate: detects missing required functions" "$validate_missing" "missing required functions"

validate_ok=$(bash -c "
    source '${PB_DIR}/_provider-lib.sh'
    pb_issue_list() { :; }
    pb_issue_create() { :; }
    pb_issue_close() { :; }
    pb_issue_reopen() { :; }
    pb_issue_view() { :; }
    pb_issue_comment() { :; }
    pb_issue_assign() { :; }
    pb_board_summary() { :; }
    pb_board_status() { :; }
    pb_board_move() { :; }
    pb_board_add() { :; }
    pb_provider_info() { :; }
    _pb_validate_provider && echo 'VALID'
" 2>&1)
assert_contains "validate: passes with all required functions" "$validate_ok" "VALID"

# =============================================================================
# Section 6: Each provider declares all required interface functions
# Uses grep on source files to avoid sourcing/execution issues.
# =============================================================================

REQUIRED_FNS="pb_issue_list pb_issue_create pb_issue_close pb_issue_reopen
pb_issue_view pb_issue_comment pb_issue_assign
pb_board_summary pb_board_status pb_board_move pb_board_add pb_board_approve
pb_provider_info"

for provider in github jira youtrack; do
    provider_file="${PROVIDERS_DIR}/${provider}.sh"
    for fn in $REQUIRED_FNS; do
        if grep -qE "^${fn}[[:space:]]*\\(\\)" "$provider_file"; then
            _pass "${provider}: declares ${fn}"
        else
            _fail "${provider}: missing declaration of ${fn}"
        fi
    done
done

# =============================================================================
# Section 7: Provider info output validation (via mock sourcing)
# =============================================================================

# GitHub provider info
gh_info=$(bash -c "
    set -euo pipefail
    export CC_GITHUB_OWNER='test-owner'
    export CC_GITHUB_REPO='test-owner/test-repo'
    export CC_PROJECT_NUMBER='1'
    export CC_PROJECT_ID='PVT_test'
    export CC_STATUS_FIELD_ID='PVTSSF_test'
    source '${MOCK_PROVIDERS_DIR}/github.sh'
    pb_provider_info
" 2>&1) || true

assert_contains "github info: has provider field" "$gh_info" '"provider": "github"'
assert_contains "github info: has capabilities" "$gh_info" '"capabilities"'
assert_contains "github info: has cli=gh" "$gh_info" '"cli": "gh"'

# Jira provider info
jira_info=$(bash -c "
    set -euo pipefail
    export CC_JIRA_URL='https://test.atlassian.net'
    export CC_JIRA_PROJECT='TEST'
    export CC_JIRA_TOKEN='test-token'
    export CC_JIRA_EMAIL='test@test.com'
    source '${MOCK_PROVIDERS_DIR}/jira.sh'
    pb_provider_info
" 2>&1) || true

assert_contains "jira info: has provider field" "$jira_info" '"provider": "jira"'
assert_contains "jira info: has capabilities" "$jira_info" '"capabilities"'
assert_contains "jira info: has cli=curl" "$jira_info" '"cli": "curl"'

# YouTrack provider info
yt_info=$(bash -c "
    set -euo pipefail
    export CC_YOUTRACK_URL='https://test.youtrack.cloud'
    export CC_YOUTRACK_PROJECT='TEST'
    export CC_YOUTRACK_TOKEN='perm:test-token'
    source '${MOCK_PROVIDERS_DIR}/youtrack.sh'
    pb_provider_info
" 2>&1) || true

assert_contains "youtrack info: has provider field" "$yt_info" '"provider": "youtrack"'
assert_contains "youtrack info: has capabilities" "$yt_info" '"capabilities"'
assert_contains "youtrack info: has cli=curl" "$yt_info" '"cli": "curl"'

# =============================================================================
# Section 8: Config validation (missing config produces clean error)
# =============================================================================

gh_noconfig=$(bash -c "
    export PROJECT_DIR='$(create_test_dir)'
    mkdir -p \"\${PROJECT_DIR}\"
    cat > \"\${PROJECT_DIR}/cognitive-core.conf\" <<'CONF'
#!/bin/false
CC_GITHUB_OWNER=''
CC_GITHUB_REPO=''
CC_PROJECT_NUMBER=''
CC_PROJECT_ID=''
CC_STATUS_FIELD_ID=''
CONF
    bash '${PROVIDERS_DIR}/github.sh' provider info 2>&1
" 2>&1) || true
assert_contains "github: missing config error" "$gh_noconfig" "Missing GitHub config"

jira_noconfig=$(bash -c "
    export PROJECT_DIR='$(create_test_dir)'
    mkdir -p \"\${PROJECT_DIR}\"
    cat > \"\${PROJECT_DIR}/cognitive-core.conf\" <<'CONF'
#!/bin/false
CC_JIRA_URL=''
CC_JIRA_PROJECT=''
CC_JIRA_TOKEN=''
CONF
    bash '${PROVIDERS_DIR}/jira.sh' provider info 2>&1
" 2>&1) || true
assert_contains "jira: missing config error" "$jira_noconfig" "Missing Jira config"

yt_noconfig=$(bash -c "
    export PROJECT_DIR='$(create_test_dir)'
    mkdir -p \"\${PROJECT_DIR}\"
    cat > \"\${PROJECT_DIR}/cognitive-core.conf\" <<'CONF'
#!/bin/false
CC_YOUTRACK_URL=''
CC_YOUTRACK_PROJECT=''
CC_YOUTRACK_TOKEN=''
CONF
    bash '${PROVIDERS_DIR}/youtrack.sh' provider info 2>&1
" 2>&1) || true
assert_contains "youtrack: missing config error" "$yt_noconfig" "Missing YouTrack config"

# =============================================================================
# Section 9: Jira status mapping (via mock sourcing)
# =============================================================================

for pair in "roadmap:To Do" "backlog:Backlog" "todo:To Do" \
            "progress:In Progress" "testing:In Review" \
            "done:Done" "canceled:Canceled"; do
    key="${pair%%:*}"
    expected="${pair#*:}"
    actual=$(bash -c "
        set -euo pipefail
        export CC_JIRA_URL='https://test.atlassian.net'
        export CC_JIRA_PROJECT='TEST'
        export CC_JIRA_TOKEN='test-token'
        source '${MOCK_PROVIDERS_DIR}/jira.sh'
        _jira_status_name '$key'
    " 2>&1) || true
    assert_eq "jira status-map: ${key} → ${expected}" "$expected" "$actual"
done

# =============================================================================
# Section 10: YouTrack status mapping (via mock sourcing)
# =============================================================================

for pair in "roadmap:No State" "backlog:Open" "todo:To Do" \
            "progress:In Progress" "testing:To Verify" \
            "done:Done" "canceled:Canceled"; do
    key="${pair%%:*}"
    expected="${pair#*:}"
    actual=$(bash -c "
        set -euo pipefail
        export CC_YOUTRACK_URL='https://test.youtrack.cloud'
        export CC_YOUTRACK_PROJECT='TEST'
        export CC_YOUTRACK_TOKEN='perm:test-token'
        source '${MOCK_PROVIDERS_DIR}/youtrack.sh'
        _yt_status_name '$key'
    " 2>&1) || true
    assert_eq "youtrack status-map: ${key} → ${expected}" "$expected" "$actual"
done

# =============================================================================
# Section 11: Jira priority mapping
# =============================================================================

for pair in "p0-critical:Highest" "p1-high:High" "p2-medium:Medium" "p3-low:Low"; do
    key="${pair%%:*}"
    expected="${pair#*:}"
    actual=$(bash -c "
        set -euo pipefail
        export CC_JIRA_URL='https://test.atlassian.net'
        export CC_JIRA_PROJECT='TEST'
        export CC_JIRA_TOKEN='test-token'
        source '${MOCK_PROVIDERS_DIR}/jira.sh'
        _jira_priority_name '$key'
    " 2>&1) || true
    assert_eq "jira priority-map: ${key} → ${expected}" "$expected" "$actual"
done

# =============================================================================
# Section 12: Custom status map override
# =============================================================================

custom_jira=$(bash -c "
    set -euo pipefail
    export CC_JIRA_URL='https://test.atlassian.net'
    export CC_JIRA_PROJECT='TEST'
    export CC_JIRA_TOKEN='test-token'
    export CC_JIRA_STATUS_MAP='progress=Doing|done=Completed|backlog=Waiting'
    source '${MOCK_PROVIDERS_DIR}/jira.sh'
    _jira_status_name 'progress'
" 2>&1) || true
assert_eq "jira custom status-map: progress → Doing" "Doing" "$custom_jira"

custom_yt=$(bash -c "
    set -euo pipefail
    export CC_YOUTRACK_URL='https://test.youtrack.cloud'
    export CC_YOUTRACK_PROJECT='TEST'
    export CC_YOUTRACK_TOKEN='perm:test-token'
    export CC_YOUTRACK_STATUS_MAP='progress=Working|done=Closed|todo=Ready'
    source '${MOCK_PROVIDERS_DIR}/youtrack.sh'
    _yt_status_name 'progress'
" 2>&1) || true
assert_eq "youtrack custom status-map: progress → Working" "Working" "$custom_yt"

# =============================================================================
# Section 13: SKILL.md documents all three providers
# =============================================================================

skill_md=$(cat "${PB_DIR}/SKILL.md")
assert_contains "SKILL.md: documents github provider" "$skill_md" "github"
assert_contains "SKILL.md: documents jira provider" "$skill_md" "jira"
assert_contains "SKILL.md: documents youtrack provider" "$skill_md" "youtrack"
assert_contains "SKILL.md: documents provider selection" "$skill_md" "CC_PROJECT_BOARD_PROVIDER"
assert_contains "SKILL.md: documents CC_JIRA_URL" "$skill_md" "CC_JIRA_URL"
assert_contains "SKILL.md: documents CC_YOUTRACK_URL" "$skill_md" "CC_YOUTRACK_URL"

# =============================================================================
# Section 14: Config example documents all providers
# =============================================================================

conf_example=$(cat "${ROOT_DIR}/cognitive-core.conf.example")
assert_contains "conf.example: has provider selection" "$conf_example" 'CC_PROJECT_BOARD_PROVIDER'
assert_contains "conf.example: has Jira section" "$conf_example" "CC_JIRA_URL"
assert_contains "conf.example: has Jira project key" "$conf_example" "CC_JIRA_PROJECT"
assert_contains "conf.example: has Jira token" "$conf_example" "CC_JIRA_TOKEN"
assert_contains "conf.example: has Jira auth type" "$conf_example" "CC_JIRA_AUTH_TYPE"
assert_contains "conf.example: has Jira status map" "$conf_example" "CC_JIRA_STATUS_MAP"
assert_contains "conf.example: has YouTrack section" "$conf_example" "CC_YOUTRACK_URL"
assert_contains "conf.example: has YouTrack project" "$conf_example" "CC_YOUTRACK_PROJECT"
assert_contains "conf.example: has YouTrack token" "$conf_example" "CC_YOUTRACK_TOKEN"
assert_contains "conf.example: has YouTrack status map" "$conf_example" "CC_YOUTRACK_STATUS_MAP"

# =============================================================================
# Section 15: Jira auth types (via mock sourcing)
# =============================================================================

basic_auth=$(bash -c "
    set -euo pipefail
    export CC_JIRA_URL='https://test.atlassian.net'
    export CC_JIRA_PROJECT='TEST'
    export CC_JIRA_TOKEN='test-token'
    export CC_JIRA_EMAIL='user@test.com'
    export CC_JIRA_AUTH_TYPE='basic'
    source '${MOCK_PROVIDERS_DIR}/jira.sh'
    _jira_auth_header
" 2>&1) || true
assert_contains "jira auth: basic type produces Basic header" "$basic_auth" "Authorization: Basic"

bearer_auth=$(bash -c "
    set -euo pipefail
    export CC_JIRA_URL='https://jira.company.com'
    export CC_JIRA_PROJECT='TEST'
    export CC_JIRA_TOKEN='pat-token-here'
    export CC_JIRA_AUTH_TYPE='bearer'
    source '${MOCK_PROVIDERS_DIR}/jira.sh'
    _jira_auth_header
" 2>&1) || true
assert_contains "jira auth: bearer type produces Bearer header" "$bearer_auth" "Authorization: Bearer"

# =============================================================================
# Section 16: set -euo pipefail present in provider scripts
# (provider-lib is a sourced library, not required to have it)
# =============================================================================

for provider in github jira youtrack; do
    if grep -q 'set -euo pipefail' "${PROVIDERS_DIR}/${provider}.sh"; then
        _pass "strict mode: ${provider}.sh has set -euo pipefail"
    else
        _fail "strict mode: ${provider}.sh missing set -euo pipefail"
    fi
done

# =============================================================================
# Section 17: Provider scripts source _provider-lib.sh
# =============================================================================

for provider in github jira youtrack; do
    if grep -q '_provider-lib.sh' "${PROVIDERS_DIR}/${provider}.sh"; then
        _pass "sourcing: ${provider}.sh sources _provider-lib.sh"
    else
        _fail "sourcing: ${provider}.sh does not source _provider-lib.sh"
    fi
done

# =============================================================================
# Section 18: Provider scripts call _pb_validate_provider
# =============================================================================

for provider in github jira youtrack; do
    if grep -q '_pb_validate_provider' "${PROVIDERS_DIR}/${provider}.sh"; then
        _pass "validation: ${provider}.sh calls _pb_validate_provider"
    else
        _fail "validation: ${provider}.sh does not call _pb_validate_provider"
    fi
done

# =============================================================================
# Section 19: All providers use _pb_route for CLI dispatch
# =============================================================================

for provider in github jira youtrack; do
    if grep -q '_pb_route' "${PROVIDERS_DIR}/${provider}.sh"; then
        _pass "routing: ${provider}.sh uses _pb_route for CLI dispatch"
    else
        _fail "routing: ${provider}.sh does not use _pb_route"
    fi
done

# =============================================================================
# Section 20: JSON output helpers
# =============================================================================

json_kv=$(bash -c "
    source '${PB_DIR}/_provider-lib.sh'
    _pb_json_kv 'key1' 'val1' 'key2' 'val2'
" 2>&1)
assert_contains "json helper: _pb_json_kv produces key1" "$json_kv" '"key1":"val1"'
assert_contains "json helper: _pb_json_kv produces key2" "$json_kv" '"key2":"val2"'

success_out=$(bash -c "
    source '${PB_DIR}/_provider-lib.sh'
    _pb_success 'test message'
" 2>&1)
assert_contains "json helper: _pb_success has ok:true" "$success_out" '"ok":true'
assert_contains "json helper: _pb_success has message" "$success_out" '"message":"test message"'

# =============================================================================
# Section 21: Jira supports --assignee in issue create
# =============================================================================

if grep -qE 'assignee' "${PROVIDERS_DIR}/jira.sh"; then
    _pass "jira: pb_issue_create handles --assignee"
else
    _fail "jira: pb_issue_create missing --assignee support"
fi

# =============================================================================
# Section 22: YouTrack supports --assignee in issue create
# =============================================================================

if grep -qE 'assignee' "${PROVIDERS_DIR}/youtrack.sh"; then
    _pass "youtrack: pb_issue_create handles --assignee"
else
    _fail "youtrack: pb_issue_create missing --assignee support"
fi

# =============================================================================
# Section 23: URL helper functions exist
# =============================================================================

if grep -qE '^_jira_issue_url\(\)' "${PROVIDERS_DIR}/jira.sh"; then
    _pass "jira: _jira_issue_url function exists"
else
    _fail "jira: _jira_issue_url function missing"
fi

if grep -qE '^_yt_issue_url\(\)' "${PROVIDERS_DIR}/youtrack.sh"; then
    _pass "youtrack: _yt_issue_url function exists"
else
    _fail "youtrack: _yt_issue_url function missing"
fi

# =============================================================================
# Section 24: url field present in pb_board_status output construction
# =============================================================================

# GitHub pb_board_status includes url
if grep -A 20 '^pb_board_status()' "${PROVIDERS_DIR}/github.sh" | grep -q "'url'"; then
    _pass "github: pb_board_status includes url in output"
else
    _fail "github: pb_board_status missing url in output"
fi

# Jira pb_board_status includes url
if grep -A 20 '^pb_board_status()' "${PROVIDERS_DIR}/jira.sh" | grep -q "'url'"; then
    _pass "jira: pb_board_status includes url in output"
else
    _fail "jira: pb_board_status missing url in output"
fi

# YouTrack pb_board_status includes url
if grep -A 25 '^pb_board_status()' "${PROVIDERS_DIR}/youtrack.sh" | grep -q "'url'"; then
    _pass "youtrack: pb_board_status includes url in output"
else
    _fail "youtrack: pb_board_status missing url in output"
fi

# =============================================================================
# Section 25: URL format validation (via mock sourcing)
# =============================================================================

jira_url_test=$(bash -c "
    set -euo pipefail
    export CC_JIRA_URL='https://test.atlassian.net'
    export CC_JIRA_PROJECT='TEST'
    export CC_JIRA_TOKEN='test-token'
    source '${MOCK_PROVIDERS_DIR}/jira.sh'
    _jira_issue_url 'TEST-42'
" 2>&1) || true

if echo "$jira_url_test" | grep -qE 'https://.*browse/[A-Za-z]+-[0-9]+'; then
    _pass "jira: URL matches pattern https://.*browse/KEY-123"
else
    _fail "jira: URL format mismatch — got: $jira_url_test"
fi

yt_url_test=$(bash -c "
    set -euo pipefail
    export CC_YOUTRACK_URL='https://test.youtrack.cloud'
    export CC_YOUTRACK_PROJECT='TEST'
    export CC_YOUTRACK_TOKEN='perm:test-token'
    source '${MOCK_PROVIDERS_DIR}/youtrack.sh'
    _yt_issue_url 'TEST-42'
" 2>&1) || true

if echo "$yt_url_test" | grep -qE 'https://.*issue/[A-Za-z]+-[0-9]+'; then
    _pass "youtrack: URL matches pattern https://.*issue/KEY-123"
else
    _fail "youtrack: URL format mismatch — got: $yt_url_test"
fi

# Also fix jira regex to support lowercase keys
# (already tested above with uppercase — test lowercase explicitly)
jira_lc_url_test=$(bash -c "
    set -euo pipefail
    export CC_JIRA_URL='https://test.atlassian.net'
    export CC_JIRA_PROJECT='test'
    export CC_JIRA_TOKEN='test-token'
    source '${MOCK_PROVIDERS_DIR}/jira.sh'
    _jira_issue_url 'myproject-42'
" 2>&1) || true

if echo "$jira_lc_url_test" | grep -qE 'https://.*browse/[A-Za-z]+-[0-9]+'; then
    _pass "jira: URL supports lowercase project keys"
else
    _fail "jira: URL rejects lowercase project keys — got: $jira_lc_url_test"
fi

yt_lc_url_test=$(bash -c "
    set -euo pipefail
    export CC_YOUTRACK_URL='https://test.youtrack.cloud'
    export CC_YOUTRACK_PROJECT='test'
    export CC_YOUTRACK_TOKEN='perm:test-token'
    source '${MOCK_PROVIDERS_DIR}/youtrack.sh'
    _yt_issue_url 'myproject-42'
" 2>&1) || true

if echo "$yt_lc_url_test" | grep -qE 'https://.*issue/[A-Za-z]+-[0-9]+'; then
    _pass "youtrack: URL supports lowercase project keys"
else
    _fail "youtrack: URL rejects lowercase project keys — got: $yt_lc_url_test"
fi

# =============================================================================
# Section 26: Runtime url field in pb_issue_view (Jira + YouTrack)
# =============================================================================

# Jira pb_issue_view url via mock _jira_api
jira_view_test=$(bash -c "
    set -euo pipefail
    export CC_JIRA_URL='https://test.atlassian.net'
    export CC_JIRA_PROJECT='TEST'
    export CC_JIRA_TOKEN='test-token'
    source '${MOCK_PROVIDERS_DIR}/jira.sh'
    # Mock _jira_api to return minimal JSON
    _jira_api() { echo '{\"key\":\"TEST-42\",\"fields\":{\"summary\":\"test\"}}'; }
    pb_issue_view 'TEST-42'
" 2>&1) || true

if echo "$jira_view_test" | grep -q '"url"'; then
    _pass "jira: pb_issue_view output contains url field"
else
    _fail "jira: pb_issue_view output missing url field — got: $jira_view_test"
fi

if echo "$jira_view_test" | grep -qE 'https://test.atlassian.net/browse/TEST-42'; then
    _pass "jira: pb_issue_view url has correct value"
else
    _fail "jira: pb_issue_view url value mismatch — got: $jira_view_test"
fi

# YouTrack pb_issue_view url via mock _yt_api
yt_view_test=$(bash -c "
    set -euo pipefail
    export CC_YOUTRACK_URL='https://test.youtrack.cloud'
    export CC_YOUTRACK_PROJECT='TEST'
    export CC_YOUTRACK_TOKEN='perm:test-token'
    source '${MOCK_PROVIDERS_DIR}/youtrack.sh'
    # Mock _yt_api to return minimal JSON
    _yt_api() { echo '{\"idReadable\":\"TEST-42\",\"summary\":\"test\"}'; }
    pb_issue_view 'TEST-42'
" 2>&1) || true

if echo "$yt_view_test" | grep -q '"url"'; then
    _pass "youtrack: pb_issue_view output contains url field"
else
    _fail "youtrack: pb_issue_view output missing url field — got: $yt_view_test"
fi

if echo "$yt_view_test" | grep -qE 'https://test.youtrack.cloud/issue/TEST-42'; then
    _pass "youtrack: pb_issue_view url has correct value"
else
    _fail "youtrack: pb_issue_view url value mismatch — got: $yt_view_test"
fi

# =============================================================================
# Section 27: Runtime url field in pb_issue_create (Jira + YouTrack)
# =============================================================================

# Jira pb_issue_create url via mock
jira_create_test=$(bash -c "
    set -euo pipefail
    export CC_JIRA_URL='https://test.atlassian.net'
    export CC_JIRA_PROJECT='TEST'
    export CC_JIRA_TOKEN='test-token'
    source '${MOCK_PROVIDERS_DIR}/jira.sh'
    # Mock _jira_api to return created issue
    _jira_api() { echo '{\"key\":\"TEST-99\",\"id\":\"12345\"}'; }
    pb_issue_create 'Test issue'
" 2>&1) || true

if echo "$jira_create_test" | grep -q '"url"'; then
    _pass "jira: pb_issue_create output contains url field"
else
    _fail "jira: pb_issue_create output missing url field — got: $jira_create_test"
fi

if echo "$jira_create_test" | grep -qE 'https://test.atlassian.net/browse/TEST-99'; then
    _pass "jira: pb_issue_create url has correct value"
else
    _fail "jira: pb_issue_create url value mismatch — got: $jira_create_test"
fi

# YouTrack pb_issue_create url via mock
yt_create_test=$(bash -c "
    set -euo pipefail
    export CC_YOUTRACK_URL='https://test.youtrack.cloud'
    export CC_YOUTRACK_PROJECT='TEST'
    export CC_YOUTRACK_TOKEN='perm:test-token'
    source '${MOCK_PROVIDERS_DIR}/youtrack.sh'
    # Mock _yt_api to return created issue
    _yt_api() { echo '{\"idReadable\":\"TEST-99\",\"id\":\"12345\"}'; }
    pb_issue_create 'Test issue'
" 2>&1) || true

if echo "$yt_create_test" | grep -q '"url"'; then
    _pass "youtrack: pb_issue_create output contains url field"
else
    _fail "youtrack: pb_issue_create output missing url field — got: $yt_create_test"
fi

if echo "$yt_create_test" | grep -qE 'https://test.youtrack.cloud/issue/TEST-99'; then
    _pass "youtrack: pb_issue_create url has correct value"
else
    _fail "youtrack: pb_issue_create url value mismatch — got: $yt_create_test"
fi

# =============================================================================
# Section 28: Runtime GitHub pb_board_status url
# =============================================================================

gh_status_test=$(bash -c "
    set -euo pipefail
    export CC_GITHUB_OWNER='test-owner'
    export CC_GITHUB_REPO='test-owner/test-repo'
    export CC_PROJECT_ID='PVT_test'
    export CC_PROJECT_NUMBER='1'
    export CC_STATUS_FIELD_ID='PVTSSF_test'
    source '${MOCK_PROVIDERS_DIR}/github.sh'
    # Mock _gh_get_items to return a board item
    _gh_get_items() { echo '{\"items\":[{\"id\":\"item1\",\"status\":\"Todo\",\"sprint\":\"\",\"content\":{\"number\":42,\"assignees\":[]}}]}'; }
    pb_board_status 42
" 2>&1) || true

if echo "$gh_status_test" | grep -q '"url"'; then
    _pass "github: pb_board_status runtime output contains url field"
else
    _fail "github: pb_board_status runtime output missing url field — got: $gh_status_test"
fi

if echo "$gh_status_test" | grep -qE 'https://github.com/test-owner/test-repo/issues/42'; then
    _pass "github: pb_board_status url has correct value"
else
    _fail "github: pb_board_status url value mismatch — got: $gh_status_test"
fi

# =============================================================================
# Section 29: Empty-config edge case for URL helpers
# =============================================================================

# Empty-config: providers should reject missing URL at validation time
jira_empty_url=$(bash -c "
    set -euo pipefail
    export CC_JIRA_URL=''
    export CC_JIRA_PROJECT='TEST'
    export CC_JIRA_TOKEN='test-token'
    source '${MOCK_PROVIDERS_DIR}/jira.sh' 2>&1
    echo 'sourced-ok'
" 2>&1) || true

if echo "$jira_empty_url" | grep -qE 'Missing|error'; then
    _pass "jira: empty CC_JIRA_URL rejected at config validation"
else
    _fail "jira: empty CC_JIRA_URL was not rejected — got: $jira_empty_url"
fi

yt_empty_url=$(bash -c "
    set -euo pipefail
    export CC_YOUTRACK_URL=''
    export CC_YOUTRACK_PROJECT='TEST'
    export CC_YOUTRACK_TOKEN='perm:test-token'
    source '${MOCK_PROVIDERS_DIR}/youtrack.sh' 2>&1
    echo 'sourced-ok'
" 2>&1) || true

if echo "$yt_empty_url" | grep -qE 'Missing|error'; then
    _pass "youtrack: empty CC_YOUTRACK_URL rejected at config validation"
else
    _fail "youtrack: empty CC_YOUTRACK_URL was not rejected — got: $yt_empty_url"
fi

# =============================================================================
# Section 30: Input validation functions exist
# =============================================================================

if grep -qE '^_jira_validate_key\(\)' "${PROVIDERS_DIR}/jira.sh"; then
    _pass "jira: _jira_validate_key function exists"
else
    _fail "jira: _jira_validate_key function missing"
fi

if grep -qE '^_yt_validate_id\(\)' "${PROVIDERS_DIR}/youtrack.sh"; then
    _pass "youtrack: _yt_validate_id function exists"
else
    _fail "youtrack: _yt_validate_id function missing"
fi

if grep -qE '^_gh_validate_number\(\)' "${PROVIDERS_DIR}/github.sh"; then
    _pass "github: _gh_validate_number function exists"
else
    _fail "github: _gh_validate_number function missing"
fi

# =============================================================================
# Section 31: Security — no direct shell-to-Python interpolation
# =============================================================================

# Check that providers use os.environ instead of '$variable' in Python
# Look for the anti-pattern: single-quoted shell var in Python source
for provider in jira youtrack github; do
    # Count remaining unsafe patterns: = '$varname' (shell var in Python string)
    # Use single-quoted pattern to avoid shell expansion of $
    if grep -qE '= '"'"'[$][A-Za-z_]' "${PROVIDERS_DIR}/${provider}.sh" 2>/dev/null; then
        unsafe_count=$(grep -cE '= '"'"'[$][A-Za-z_]' "${PROVIDERS_DIR}/${provider}.sh")
        _fail "${provider}: ${unsafe_count} direct shell-to-Python interpolation(s) found"
    else
        _pass "${provider}: no direct shell-to-Python interpolation (uses os.environ)"
    fi
done

# =============================================================================
# Section 32: Closure guard — _pb_closure_guard exists and router invokes it
# =============================================================================

if grep -qE '^_pb_closure_guard\(\)' "${PB_DIR}/_provider-lib.sh"; then
    _pass "closure guard: _pb_closure_guard function exists in _provider-lib.sh"
else
    _fail "closure guard: _pb_closure_guard function missing from _provider-lib.sh"
fi

if grep -q '_pb_closure_guard.*&&.*pb_issue_close' "${PB_DIR}/_provider-lib.sh"; then
    _pass "closure guard: router calls guard before pb_issue_close"
else
    _fail "closure guard: router does not call guard before pb_issue_close"
fi

# Verify no guard logic in providers (separation of concerns)
# Check that providers do not reference guard symbols in executable code (comments OK)
for provider in jira youtrack github; do
    # Check for guard symbols in non-comment, non-marker lines
    if grep -E '_pb_closure_guard|CC_REQUIRE_HUMAN_APPROVAL' "${PROVIDERS_DIR}/${provider}.sh" 2>/dev/null | grep -v '^\s*#' | grep -qv 'marker'; then
        _fail "${provider}: contains guard logic (should be in _provider-lib.sh only)"
    else
        _pass "${provider}: no closure guard logic in provider (correct — lives in _provider-lib.sh)"
    fi
done

# =============================================================================
# Section 33: Closure guard — status precondition (runtime mock)
# =============================================================================

# Mock: close from Done → blocked
guard_done_test=$(bash -c "
    set -euo pipefail
    export CC_GITHUB_OWNER='test-owner'
    export CC_GITHUB_REPO='test-owner/test-repo'
    export CC_PROJECT_ID='PVT_test'
    export CC_PROJECT_NUMBER='1'
    export CC_STATUS_FIELD_ID='PVTSSF_test'
    export CC_REQUIRE_HUMAN_APPROVAL='false'
    source '${MOCK_PROVIDERS_DIR}/github.sh'
    _gh_get_items() { echo '{\"items\":[{\"id\":\"i1\",\"status\":\"Done\",\"content\":{\"number\":42}}]}'; }
    pb_issue_view() { echo '{\"body\":\"\"}'; }
    _pb_closure_guard 42 2>&1
" 2>&1) || true

if echo "$guard_done_test" | grep -qi 'already Done'; then
    _pass "closure guard: blocks close from Done status"
else
    _fail "closure guard: did not block close from Done — got: $guard_done_test"
fi

# Mock: close from To Be Tested with approval=true → blocked
guard_testing_test=$(bash -c "
    set -euo pipefail
    export CC_GITHUB_OWNER='test-owner'
    export CC_GITHUB_REPO='test-owner/test-repo'
    export CC_PROJECT_ID='PVT_test'
    export CC_PROJECT_NUMBER='1'
    export CC_STATUS_FIELD_ID='PVTSSF_test'
    export CC_REQUIRE_HUMAN_APPROVAL='true'
    source '${MOCK_PROVIDERS_DIR}/github.sh'
    _gh_get_items() { echo '{\"items\":[{\"id\":\"i1\",\"status\":\"To Be Tested\",\"content\":{\"number\":42}}]}'; }
    pb_issue_view() { echo '{\"body\":\"\"}'; }
    _pb_closure_guard 42 2>&1
" 2>&1) || true

if echo "$guard_testing_test" | grep -qi 'approve'; then
    _pass "closure guard: blocks close from To Be Tested when approval required"
else
    _fail "closure guard: did not block To Be Tested close — got: $guard_testing_test"
fi

# Mock: close from In Progress with approval=false → allowed
guard_progress_test=$(bash -c "
    set -euo pipefail
    export CC_GITHUB_OWNER='test-owner'
    export CC_GITHUB_REPO='test-owner/test-repo'
    export CC_PROJECT_ID='PVT_test'
    export CC_PROJECT_NUMBER='1'
    export CC_STATUS_FIELD_ID='PVTSSF_test'
    export CC_REQUIRE_HUMAN_APPROVAL='false'
    source '${MOCK_PROVIDERS_DIR}/github.sh'
    _gh_get_items() { echo '{\"items\":[{\"id\":\"i1\",\"status\":\"In Progress\",\"content\":{\"number\":42}}]}'; }
    pb_issue_view() { echo '{\"body\":\"\"}'; }
    _pb_closure_guard 42 2>&1
" 2>&1)
guard_progress_exit=$?

if [[ $guard_progress_exit -eq 0 ]]; then
    _pass "closure guard: allows close from In Progress when approval not required"
else
    _fail "closure guard: blocked close from In Progress — got: $guard_progress_test"
fi

# =============================================================================
# Section 34: Closure guard — cancel exemption
# =============================================================================

# Cancel with "Canceled:" prefix → allowed even from To Be Tested
guard_cancel_test=$(bash -c "
    set -euo pipefail
    export CC_GITHUB_OWNER='test-owner'
    export CC_GITHUB_REPO='test-owner/test-repo'
    export CC_PROJECT_ID='PVT_test'
    export CC_PROJECT_NUMBER='1'
    export CC_STATUS_FIELD_ID='PVTSSF_test'
    export CC_REQUIRE_HUMAN_APPROVAL='true'
    source '${MOCK_PROVIDERS_DIR}/github.sh'
    _gh_get_items() { echo '{\"items\":[{\"id\":\"i1\",\"status\":\"To Be Tested\",\"content\":{\"number\":42}}]}'; }
    pb_issue_view() { echo '{\"body\":\"\"}'; }
    _pb_closure_guard 42 --comment 'Canceled: duplicate' 2>&1
" 2>&1)
guard_cancel_exit=$?

if [[ $guard_cancel_exit -eq 0 ]]; then
    _pass "closure guard: cancel path bypasses approval gate"
else
    _fail "closure guard: cancel path was blocked — got: $guard_cancel_test"
fi

# "Was canceled" (no prefix) → blocked
guard_nocancelprefix_test=$(bash -c "
    set -euo pipefail
    export CC_GITHUB_OWNER='test-owner'
    export CC_GITHUB_REPO='test-owner/test-repo'
    export CC_PROJECT_ID='PVT_test'
    export CC_PROJECT_NUMBER='1'
    export CC_STATUS_FIELD_ID='PVTSSF_test'
    export CC_REQUIRE_HUMAN_APPROVAL='true'
    source '${MOCK_PROVIDERS_DIR}/github.sh'
    _gh_get_items() { echo '{\"items\":[{\"id\":\"i1\",\"status\":\"To Be Tested\",\"content\":{\"number\":42}}]}'; }
    pb_issue_view() { echo '{\"body\":\"\"}'; }
    _pb_closure_guard 42 --comment 'Was canceled last week' 2>&1
" 2>&1) || true

if echo "$guard_nocancelprefix_test" | grep -qi 'approve'; then
    _pass "closure guard: 'Was canceled' without prefix is blocked"
else
    _fail "closure guard: 'Was canceled' was not blocked — got: $guard_nocancelprefix_test"
fi

# Cancel from Done → still blocked (terminal)
guard_cancel_done_test=$(bash -c "
    set -euo pipefail
    export CC_GITHUB_OWNER='test-owner'
    export CC_GITHUB_REPO='test-owner/test-repo'
    export CC_PROJECT_ID='PVT_test'
    export CC_PROJECT_NUMBER='1'
    export CC_STATUS_FIELD_ID='PVTSSF_test'
    export CC_REQUIRE_HUMAN_APPROVAL='true'
    source '${MOCK_PROVIDERS_DIR}/github.sh'
    _gh_get_items() { echo '{\"items\":[{\"id\":\"i1\",\"status\":\"Done\",\"content\":{\"number\":42}}]}'; }
    pb_issue_view() { echo '{\"body\":\"\"}'; }
    _pb_closure_guard 42 --comment 'Canceled: duplicate' 2>&1
" 2>&1) || true

if echo "$guard_cancel_done_test" | grep -qi 'already Done'; then
    _pass "closure guard: cancel from Done is still blocked"
else
    _fail "closure guard: cancel from Done was not blocked — got: $guard_cancel_done_test"
fi

# --force flag → bypass
guard_force_test=$(bash -c "
    set -euo pipefail
    export CC_GITHUB_OWNER='test-owner'
    export CC_GITHUB_REPO='test-owner/test-repo'
    export CC_PROJECT_ID='PVT_test'
    export CC_PROJECT_NUMBER='1'
    export CC_STATUS_FIELD_ID='PVTSSF_test'
    export CC_REQUIRE_HUMAN_APPROVAL='true'
    source '${MOCK_PROVIDERS_DIR}/github.sh'
    _gh_get_items() { echo '{\"items\":[{\"id\":\"i1\",\"status\":\"To Be Tested\",\"content\":{\"number\":42}}]}'; }
    pb_issue_view() { echo '{\"body\":\"\"}'; }
    _pb_closure_guard 42 --force 2>&1
" 2>&1)
guard_force_exit=$?

if [[ $guard_force_exit -eq 0 ]]; then
    _pass "closure guard: --force bypasses all guards"
else
    _fail "closure guard: --force did not bypass — got: $guard_force_test"
fi

# =============================================================================
# Section 35: Closure guard — acceptance criteria check
# =============================================================================

# Issue with unchecked criteria → blocked
guard_unchecked_test=$(bash -c "
    set -euo pipefail
    export CC_GITHUB_OWNER='test-owner'
    export CC_GITHUB_REPO='test-owner/test-repo'
    export CC_PROJECT_ID='PVT_test'
    export CC_PROJECT_NUMBER='1'
    export CC_STATUS_FIELD_ID='PVTSSF_test'
    export CC_REQUIRE_HUMAN_APPROVAL='false'
    source '${MOCK_PROVIDERS_DIR}/github.sh'
    _gh_get_items() { echo '{\"items\":[{\"id\":\"i1\",\"status\":\"In Progress\",\"content\":{\"number\":42}}]}'; }
    pb_issue_view() { echo '{\"body\":\"## Criteria\n- [x] Done\n- [ ] Not done\n- [ ] Also not done\"}'; }
    _pb_closure_guard 42 2>&1
" 2>&1) || true

if echo "$guard_unchecked_test" | grep -qi '2 of 3'; then
    _pass "closure guard: blocks close with unchecked acceptance criteria"
else
    _fail "closure guard: did not block unchecked criteria — got: $guard_unchecked_test"
fi

# Issue with all checked → allowed
guard_allchecked_test=$(bash -c "
    set -euo pipefail
    export CC_GITHUB_OWNER='test-owner'
    export CC_GITHUB_REPO='test-owner/test-repo'
    export CC_PROJECT_ID='PVT_test'
    export CC_PROJECT_NUMBER='1'
    export CC_STATUS_FIELD_ID='PVTSSF_test'
    export CC_REQUIRE_HUMAN_APPROVAL='false'
    source '${MOCK_PROVIDERS_DIR}/github.sh'
    _gh_get_items() { echo '{\"items\":[{\"id\":\"i1\",\"status\":\"In Progress\",\"content\":{\"number\":42}}]}'; }
    pb_issue_view() { echo '{\"body\":\"## Criteria\n- [x] Done\n- [x] Also done\"}'; }
    _pb_closure_guard 42 2>&1
" 2>&1)
guard_allchecked_exit=$?

if [[ $guard_allchecked_exit -eq 0 ]]; then
    _pass "closure guard: allows close with all criteria checked"
else
    _fail "closure guard: blocked close with all checked — got: $guard_allchecked_test"
fi

# Issue with no checkboxes → allowed
guard_noboxes_test=$(bash -c "
    set -euo pipefail
    export CC_GITHUB_OWNER='test-owner'
    export CC_GITHUB_REPO='test-owner/test-repo'
    export CC_PROJECT_ID='PVT_test'
    export CC_PROJECT_NUMBER='1'
    export CC_STATUS_FIELD_ID='PVTSSF_test'
    export CC_REQUIRE_HUMAN_APPROVAL='false'
    source '${MOCK_PROVIDERS_DIR}/github.sh'
    _gh_get_items() { echo '{\"items\":[{\"id\":\"i1\",\"status\":\"In Progress\",\"content\":{\"number\":42}}]}'; }
    pb_issue_view() { echo '{\"body\":\"Just a description, no checkboxes\"}'; }
    _pb_closure_guard 42 2>&1
" 2>&1)
guard_noboxes_exit=$?

if [[ $guard_noboxes_exit -eq 0 ]]; then
    _pass "closure guard: allows close with no acceptance criteria"
else
    _fail "closure guard: blocked close with no criteria — got: $guard_noboxes_test"
fi

# =============================================================================
# Section 36: Additional guard coverage — gaps from peer review
# =============================================================================

# T1: Board status Canceled → blocked
guard_canceled_status_test=$(bash -c "
    set -euo pipefail
    export CC_GITHUB_OWNER='test-owner'
    export CC_GITHUB_REPO='test-owner/test-repo'
    export CC_PROJECT_ID='PVT_test'
    export CC_PROJECT_NUMBER='1'
    export CC_STATUS_FIELD_ID='PVTSSF_test'
    export CC_REQUIRE_HUMAN_APPROVAL='false'
    source '${MOCK_PROVIDERS_DIR}/github.sh'
    _gh_get_items() { echo '{\"items\":[{\"id\":\"i1\",\"status\":\"Canceled\",\"content\":{\"number\":42}}]}'; }
    pb_issue_view() { echo '{\"body\":\"\"}'; }
    _pb_closure_guard 42 2>&1
" 2>&1) || true

if echo "$guard_canceled_status_test" | grep -qi 'already Canceled'; then
    _pass "closure guard: blocks close from Canceled status"
else
    _fail "closure guard: did not block Canceled status — got: $guard_canceled_status_test"
fi

# T2: Jira ADF dict body — isinstance(body, dict) branch
guard_adf_test=$(bash -c "
    set -euo pipefail
    export CC_JIRA_URL='https://test.atlassian.net'
    export CC_JIRA_PROJECT='TEST'
    export CC_JIRA_TOKEN='test-token'
    export CC_REQUIRE_HUMAN_APPROVAL='false'
    source '${MOCK_PROVIDERS_DIR}/jira.sh'
    pb_board_status() { echo '{\"status\":\"In Progress\"}'; }
    pb_issue_view() { echo '{\"fields\":{\"description\":{\"type\":\"doc\",\"content\":[{\"type\":\"taskList\",\"content\":[{\"type\":\"taskItem\",\"attrs\":{\"state\":\"TODO\"}}]}]}},\"body\":null,\"description\":{\"type\":\"doc\"}}'; }
    _pb_closure_guard TEST-42 2>&1
" 2>&1)
guard_adf_exit=$?

# ADF body becomes a dict → json.dumps → no checkbox regex match → allowed (no criteria found)
if [[ $guard_adf_exit -eq 0 ]]; then
    _pass "closure guard: Jira ADF dict body handled (isinstance branch)"
else
    _fail "closure guard: Jira ADF body crashed (exit $guard_adf_exit) — got: $guard_adf_test"
fi

# T3: YouTrack description field fallback
guard_yt_desc_test=$(bash -c "
    set -euo pipefail
    export CC_YOUTRACK_URL='https://test.youtrack.cloud'
    export CC_YOUTRACK_PROJECT='TEST'
    export CC_YOUTRACK_TOKEN='perm:test-token'
    export CC_REQUIRE_HUMAN_APPROVAL='false'
    source '${MOCK_PROVIDERS_DIR}/youtrack.sh'
    pb_board_status() { echo '{\"status\":\"In Progress\"}'; }
    pb_issue_view() { echo '{\"description\":\"## Criteria\n- [x] Done\n- [ ] Not done\"}'; }
    _pb_closure_guard TEST-42 2>&1
" 2>&1) || true

if echo "$guard_yt_desc_test" | grep -qi '1 of 2'; then
    _pass "closure guard: YouTrack description field fallback works"
else
    _fail "closure guard: YouTrack description not parsed — got: $guard_yt_desc_test"
fi

# T4: To Be Tested + approval=false → allowed
guard_testing_noapproval_test=$(bash -c "
    set -euo pipefail
    export CC_GITHUB_OWNER='test-owner'
    export CC_GITHUB_REPO='test-owner/test-repo'
    export CC_PROJECT_ID='PVT_test'
    export CC_PROJECT_NUMBER='1'
    export CC_STATUS_FIELD_ID='PVTSSF_test'
    export CC_REQUIRE_HUMAN_APPROVAL='false'
    source '${MOCK_PROVIDERS_DIR}/github.sh'
    _gh_get_items() { echo '{\"items\":[{\"id\":\"i1\",\"status\":\"To Be Tested\",\"content\":{\"number\":42}}]}'; }
    pb_issue_view() { echo '{\"body\":\"\"}'; }
    _pb_closure_guard 42 2>&1
" 2>&1)
guard_testing_noapproval_exit=$?

if [[ $guard_testing_noapproval_exit -eq 0 ]]; then
    _pass "closure guard: allows close from To Be Tested when approval not required"
else
    _fail "closure guard: blocked To Be Tested with approval=false — got: $guard_testing_noapproval_test"
fi

# D1 fix verification: uppercase [X] counted as checked
guard_uppercaseX_test=$(bash -c "
    set -euo pipefail
    export CC_GITHUB_OWNER='test-owner'
    export CC_GITHUB_REPO='test-owner/test-repo'
    export CC_PROJECT_ID='PVT_test'
    export CC_PROJECT_NUMBER='1'
    export CC_STATUS_FIELD_ID='PVTSSF_test'
    export CC_REQUIRE_HUMAN_APPROVAL='false'
    source '${MOCK_PROVIDERS_DIR}/github.sh'
    _gh_get_items() { echo '{\"items\":[{\"id\":\"i1\",\"status\":\"In Progress\",\"content\":{\"number\":42}}]}'; }
    pb_issue_view() { echo '{\"body\":\"- [X] Done uppercase\n- [x] Done lowercase\n- [ ] Not done\"}'; }
    _pb_closure_guard 42 2>&1
" 2>&1) || true

if echo "$guard_uppercaseX_test" | grep -qi '1 of 3'; then
    _pass "closure guard: uppercase [X] counted as checked (1 of 3 unchecked)"
else
    _fail "closure guard: uppercase [X] miscount — got: $guard_uppercaseX_test"
fi

# =============================================================================
# Section 37: validate-bash hook — exemption markers
# =============================================================================

# "Closed via /project-board" alone should NOT be exempt anymore
if grep -qF '"Closed via /project-board"' "${ROOT_DIR}/core/hooks/validate-bash.sh" 2>/dev/null; then
    _fail "validate-bash: still has standalone 'Closed via /project-board' exemption"
else
    _pass "validate-bash: 'Closed via /project-board' standalone exemption removed"
fi

# "Approved by @" should still be exempt
if grep -qF '"Approved by @"' "${ROOT_DIR}/core/hooks/validate-bash.sh" 2>/dev/null; then
    _pass "validate-bash: 'Approved by @' exemption present"
else
    _fail "validate-bash: 'Approved by @' exemption missing"
fi

# "Canceled:" should still be exempt
if grep -qF '"Canceled:"' "${ROOT_DIR}/core/hooks/validate-bash.sh" 2>/dev/null; then
    _pass "validate-bash: 'Canceled:' exemption present"
else
    _fail "validate-bash: 'Canceled:' exemption missing"
fi

# GitHub pb_issue_close uses "Approved by @system" marker
if grep -q 'Approved by @system' "${PROVIDERS_DIR}/github.sh" 2>/dev/null; then
    _pass "github: pb_issue_close uses 'Approved by @system' marker"
else
    _fail "github: pb_issue_close missing 'Approved by @system' marker"
fi

# =============================================================================
# Section 38: Jira ADF converter — wiki markup support (#198)
# =============================================================================

# Helper: extract _jira_md_to_adf function and run it in isolation
_test_adf() {
    local input="$1"
    bash -c "
        set -euo pipefail
        export CC_JIRA_URL='https://test.atlassian.net'
        export CC_JIRA_PROJECT='TEST'
        export CC_JIRA_TOKEN='test-token'
        source '${MOCK_PROVIDERS_DIR}/jira.sh'
        _jira_md_to_adf \"\$1\"
    " -- "$input"
}

# T1: Wiki heading h2. produces ADF heading level 2
adf_out=$(_test_adf "h2. My Heading")
if echo "$adf_out" | python3 -c "import json,sys; d=json.load(sys.stdin); c=d['content'][0]; assert c['type']=='heading' and c['attrs']['level']==2, f'got {c}'"; then
    _pass "ADF: wiki heading h2. produces level 2 heading"
else
    _fail "ADF: wiki heading h2. failed — got: $adf_out"
fi

# T2: Wiki heading h5. produces level 5
adf_out=$(_test_adf "h5. Deep Heading")
if echo "$adf_out" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['content'][0]['attrs']['level']==5"; then
    _pass "ADF: wiki heading h5. produces level 5"
else
    _fail "ADF: wiki heading h5. failed — got: $adf_out"
fi

# T3: Wiki bold *text* produces strong mark
adf_out=$(_test_adf "*bold text*")
if echo "$adf_out" | python3 -c "import json,sys; d=json.load(sys.stdin); marks=[m['type'] for n in d['content'][0]['content'] for m in n.get('marks',[])]; assert 'strong' in marks, f'got {marks}'"; then
    _pass "ADF: wiki bold *text* produces strong mark"
else
    _fail "ADF: wiki bold failed — got: $adf_out"
fi

# T4: Wiki italic _text_ produces em mark
adf_out=$(_test_adf "_italic text_")
if echo "$adf_out" | python3 -c "import json,sys; d=json.load(sys.stdin); marks=[m['type'] for n in d['content'][0]['content'] for m in n.get('marks',[])]; assert 'em' in marks, f'got {marks}'"; then
    _pass "ADF: wiki italic _text_ produces em mark"
else
    _fail "ADF: wiki italic failed — got: $adf_out"
fi

# T5: Wiki monospace {{text}} produces code mark
adf_out=$(_test_adf "{{monospace}}")
if echo "$adf_out" | python3 -c "import json,sys; d=json.load(sys.stdin); marks=[m['type'] for n in d['content'][0]['content'] for m in n.get('marks',[])]; assert 'code' in marks, f'got {marks}'"; then
    _pass "ADF: wiki monospace {{text}} produces code mark"
else
    _fail "ADF: wiki monospace failed — got: $adf_out"
fi

# T6: Hyphenated words NOT mangled (spring-cloud-starter-config)
adf_out=$(_test_adf "spring-cloud-starter-config is a dependency")
if echo "$adf_out" | python3 -c "import json,sys; d=json.load(sys.stdin); txt=json.dumps(d); assert 'spring-cloud-starter-config' in txt, f'mangled'; assert 'strong' not in txt and 'em' not in txt, f'got marks'"; then
    _pass "ADF: hyphenated words pass through unmangled"
else
    _fail "ADF: hyphenated words mangled — got: $adf_out"
fi

# T7: Date with hyphens NOT mangled (2026-03-28)
adf_out=$(_test_adf "Released on 2026-03-28 successfully")
if echo "$adf_out" | python3 -c "import json,sys; d=json.load(sys.stdin); txt=json.dumps(d); assert '2026-03-28' in txt and 'strong' not in txt and 'em' not in txt"; then
    _pass "ADF: date hyphens pass through unmangled"
else
    _fail "ADF: date hyphens mangled — got: $adf_out"
fi

# T8: Horizontal rule (----) produces rule node
adf_out=$(_test_adf "----")
if echo "$adf_out" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['content'][0]['type']=='rule'"; then
    _pass "ADF: horizontal rule (----) produces rule node"
else
    _fail "ADF: horizontal rule failed — got: $adf_out"
fi

# T9: Wiki link [text|url] with query params
adf_out=$(_test_adf "[Click Here|https://example.com?a=1&b=2]")
if echo "$adf_out" | python3 -c "import json,sys; d=json.load(sys.stdin); n=d['content'][0]['content'][0]; assert n['marks'][0]['type']=='link' and 'a=1&b=2' in n['marks'][0]['attrs']['href'] and n['text']=='Click Here'"; then
    _pass "ADF: wiki link [text|url] with query params preserved"
else
    _fail "ADF: wiki link failed — got: $adf_out"
fi

# T10: Wiki link [url] bare
adf_out=$(_test_adf "[https://example.com]")
if echo "$adf_out" | python3 -c "import json,sys; d=json.load(sys.stdin); n=d['content'][0]['content'][0]; assert n['marks'][0]['type']=='link' and n['text']=='https://example.com'"; then
    _pass "ADF: wiki link [url] bare produces link"
else
    _fail "ADF: wiki link bare failed — got: $adf_out"
fi

# T11: Code block {code:xml}...{code} produces codeBlock with language
adf_out=$(_test_adf '{code:xml}
<root>
  <child/>
</root>
{code}')
if echo "$adf_out" | python3 -c "import json,sys; d=json.load(sys.stdin); cb=d['content'][0]; assert cb['type']=='codeBlock' and cb['attrs']['language']=='xml' and '<root>' in cb['content'][0]['text']"; then
    _pass "ADF: code block {code:xml} produces codeBlock with language"
else
    _fail "ADF: code block failed — got: $adf_out"
fi

# T12: Code block content NOT processed for inline marks
adf_out=$(_test_adf '{code:java}
String *name* = _value_;
{code}')
if echo "$adf_out" | python3 -c "import json,sys; d=json.load(sys.stdin); cb=d['content'][0]; assert 'strong' not in json.dumps(cb) and '*name*' in cb['content'][0]['text']"; then
    _pass "ADF: code block content protected from inline processing"
else
    _fail "ADF: code block content was processed — got: $adf_out"
fi

# T13: Wiki table ||Header||/|Cell| produces table nodes
adf_out=$(_test_adf '||Name||Age||
|Alice|30|
|Bob|25|')
if echo "$adf_out" | python3 -c "import json,sys; d=json.load(sys.stdin); t=d['content'][0]; assert t['type']=='table' and len(t['content'])==3 and t['content'][0]['content'][0]['type']=='tableHeader' and t['content'][1]['content'][0]['type']=='tableCell'"; then
    _pass "ADF: wiki table produces table/tableHeader/tableCell nodes"
else
    _fail "ADF: wiki table failed — got: $adf_out"
fi

# T14: Empty input produces valid ADF document
adf_out=$(_test_adf "")
if echo "$adf_out" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['type']=='doc' and d['version']==1 and len(d['content'])>=1"; then
    _pass "ADF: empty input produces valid ADF document"
else
    _fail "ADF: empty input failed — got: $adf_out"
fi

# T15: Existing markdown conversion backward compatible
adf_out=$(_test_adf '## MD Heading
- [ ] task item
- bullet item
**bold** text')
if echo "$adf_out" | python3 -c "import json,sys; d=json.load(sys.stdin); types=[c['type'] for c in d['content']]; assert 'heading' in types and 'taskList' in types and 'bulletList' in types and 'paragraph' in types, f'got {types}'"; then
    _pass "ADF: markdown backward compatibility (headings, tasks, bullets, bold)"
else
    _fail "ADF: markdown backward compat failed — got: $adf_out"
fi

# T16: Mixed wiki + markdown renders correctly
adf_out=$(_test_adf '## MD Heading
h3. Wiki Heading
**md bold** and *wiki bold*
----')
if echo "$adf_out" | python3 -c "
import json,sys; d=json.load(sys.stdin)
types=[c['type'] for c in d['content']]
assert types.count('heading')==2, f'expected 2 headings, got {types}'
assert 'rule' in types, f'missing rule in {types}'
assert 'strong' in json.dumps(d), 'missing strong'
"; then
    _pass "ADF: mixed wiki + markdown renders correctly"
else
    _fail "ADF: mixed input failed — got: $adf_out"
fi

# T17: ReDoS safety — 10KB input without timeout
big_input=$(python3 -c "print('spring-cloud-starter-config ' * 500)")
adf_out=$(timeout 5 bash -c "
    set -euo pipefail
    export CC_JIRA_URL='https://test.atlassian.net'
    export CC_JIRA_PROJECT='TEST'
    export CC_JIRA_TOKEN='test-token'
    source '${MOCK_PROVIDERS_DIR}/jira.sh'
    _jira_md_to_adf \"\$1\"
" -- "$big_input" 2>&1) && redos_exit=0 || redos_exit=$?
if [[ $redos_exit -eq 0 ]]; then
    _pass "ADF: ReDoS safety — 10KB input processed without timeout"
else
    _fail "ADF: ReDoS — 10KB input timed out or failed (exit $redos_exit)"
fi

# T18: Strikethrough NOT implemented — no -text- pattern matching
adf_out=$(_test_adf "Use spring-cloud-starter for -testing- and check-in")
if echo "$adf_out" | python3 -c "import json,sys; d=json.load(sys.stdin); txt=json.dumps(d); assert 'strike' not in txt, f'strikethrough found'"; then
    _pass "ADF: strikethrough not implemented (no strike marks)"
else
    _fail "ADF: strikethrough detected — got: $adf_out"
fi

# Cleanup
rm -rf "$MOCK_DIR"

suite_end
