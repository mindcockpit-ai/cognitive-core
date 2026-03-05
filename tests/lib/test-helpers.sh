#!/bin/bash
# cognitive-core test helpers
# Provides assertion functions and test scaffolding for all test suites
set -euo pipefail

# ---- State ----
_TEST_PASS=0
_TEST_FAIL=0
_TEST_SKIP=0
_TEST_SUITE=""
_JUNIT_CASES=""
_JUNIT_DIR="${JUNIT_REPORT_DIR:-}"

# ---- Colors ----
_GREEN='\033[0;32m'
_RED='\033[0;31m'
_YELLOW='\033[0;33m'
_BOLD='\033[1m'
_RESET='\033[0m'

# ---- Suite lifecycle ----
suite_start() {
    _TEST_SUITE="$1"
    _TEST_PASS=0
    _TEST_FAIL=0
    _TEST_SKIP=0
    printf "\n${_BOLD}=== %s ===${_RESET}\n" "$_TEST_SUITE"
}

suite_end() {
    local total=$((_TEST_PASS + _TEST_FAIL + _TEST_SKIP))
    printf "\n${_BOLD}Results:${_RESET} %d passed, %d failed, %d skipped (of %d)\n" \
        "$_TEST_PASS" "$_TEST_FAIL" "$_TEST_SKIP" "$total"

    # Write JUnit XML if JUNIT_REPORT_DIR is set
    if [ -n "$_JUNIT_DIR" ]; then
        mkdir -p "$_JUNIT_DIR"
        local safe_name
        safe_name=$(echo "$_TEST_SUITE" | sed 's/[^a-zA-Z0-9_-]/_/g')
        local xml_file="${_JUNIT_DIR}/${safe_name}.xml"
        cat > "$xml_file" <<XMLEOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="${_TEST_SUITE}" tests="${total}" failures="${_TEST_FAIL}" skipped="${_TEST_SKIP}">
${_JUNIT_CASES}
</testsuite>
XMLEOF
    fi

    if [ "$_TEST_FAIL" -gt 0 ]; then
        return 1
    fi
    return 0
}

# ---- JUnit XML helper ----
_xml_escape() {
    printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'
}

_junit_case() {
    local name="$1" result="$2" message="$3"
    local esc_name
    esc_name=$(_xml_escape "$name")
    case "$result" in
        pass)
            _JUNIT_CASES="${_JUNIT_CASES}  <testcase name=\"${esc_name}\" classname=\"${_TEST_SUITE}\"/>"$'\n'
            ;;
        fail)
            local esc_msg
            esc_msg=$(_xml_escape "$message")
            _JUNIT_CASES="${_JUNIT_CASES}  <testcase name=\"${esc_name}\" classname=\"${_TEST_SUITE}\"><failure message=\"${esc_msg}\"/></testcase>"$'\n'
            ;;
        skip)
            _JUNIT_CASES="${_JUNIT_CASES}  <testcase name=\"${esc_name}\" classname=\"${_TEST_SUITE}\"><skipped/></testcase>"$'\n'
            ;;
    esac
}

# ---- Assertions ----
_pass() {
    _TEST_PASS=$((_TEST_PASS + 1))
    printf "  ${_GREEN}PASS${_RESET} %s\n" "$1"
    _junit_case "$1" "pass" ""
}

_fail() {
    _TEST_FAIL=$((_TEST_FAIL + 1))
    printf "  ${_RED}FAIL${_RESET} %s\n" "$1"
    if [ -n "${2:-}" ]; then
        printf "       %s\n" "$2"
    fi
    _junit_case "$1" "fail" "${2:-}"
}

_skip() {
    _TEST_SKIP=$((_TEST_SKIP + 1))
    printf "  ${_YELLOW}SKIP${_RESET} %s\n" "$1"
    _junit_case "$1" "skip" ""
}

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        _pass "$label"
    else
        _fail "$label" "expected='${expected}' actual='${actual}'"
    fi
}

assert_ne() {
    local label="$1" not_expected="$2" actual="$3"
    if [ "$not_expected" != "$actual" ]; then
        _pass "$label"
    else
        _fail "$label" "should not equal '${not_expected}'"
    fi
}

assert_contains() {
    local label="$1" haystack="$2" needle="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        _pass "$label"
    else
        _fail "$label" "output does not contain '${needle}'"
    fi
}

assert_not_contains() {
    local label="$1" haystack="$2" needle="$3"
    if ! echo "$haystack" | grep -qF "$needle"; then
        _pass "$label"
    else
        _fail "$label" "output should not contain '${needle}'"
    fi
}

assert_matches() {
    local label="$1" haystack="$2" pattern="$3"
    if echo "$haystack" | grep -qE "$pattern"; then
        _pass "$label"
    else
        _fail "$label" "output does not match regex '${pattern}'"
    fi
}

assert_file_exists() {
    local label="$1" filepath="$2"
    if [ -f "$filepath" ]; then
        _pass "$label"
    else
        _fail "$label" "file not found: ${filepath}"
    fi
}

assert_dir_exists() {
    local label="$1" dirpath="$2"
    if [ -d "$dirpath" ]; then
        _pass "$label"
    else
        _fail "$label" "directory not found: ${dirpath}"
    fi
}

assert_file_executable() {
    local label="$1" filepath="$2"
    if [ -x "$filepath" ]; then
        _pass "$label"
    else
        _fail "$label" "file not executable: ${filepath}"
    fi
}

assert_json_field() {
    local label="$1" json="$2" field="$3" expected="$4"
    local actual
    if command -v jq &>/dev/null; then
        actual=$(echo "$json" | jq -r "$field // \"\"" 2>/dev/null)
    else
        _skip "${label} (jq not available)"
        return
    fi
    if [ "$actual" = "$expected" ]; then
        _pass "$label"
    else
        _fail "$label" "json${field}='${actual}' expected='${expected}'"
    fi
}

assert_exit_code() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        _pass "$label"
    else
        _fail "$label" "exit code=${actual} expected=${expected}"
    fi
}

# ---- Hook-specific assertions ----

# Run a hook with mock stdin and capture output + exit code
run_hook() {
    local hook_script="$1" stdin_json="$2"
    local output
    output=$(echo "$stdin_json" | bash "$hook_script" 2>/dev/null) || true
    echo "$output"
}

assert_hook_denies() {
    local label="$1" hook_script="$2" stdin_json="$3"
    local output
    output=$(echo "$stdin_json" | bash "$hook_script" 2>/dev/null) || true
    if echo "$output" | grep -q '"permissionDecision".*"deny"'; then
        _pass "$label"
    else
        _fail "$label" "expected deny decision, got: $(echo "$output" | head -1)"
    fi
}

assert_hook_allows() {
    local label="$1" hook_script="$2" stdin_json="$3"
    local output
    output=$(echo "$stdin_json" | bash "$hook_script" 2>/dev/null) || true
    if [ -z "$output" ] || ! echo "$output" | grep -q '"permissionDecision".*"deny"'; then
        _pass "$label"
    else
        _fail "$label" "expected allow (no deny), got: $(echo "$output" | head -1)"
    fi
}

assert_hook_asks() {
    local label="$1" hook_script="$2" stdin_json="$3"
    local output
    output=$(echo "$stdin_json" | bash "$hook_script" 2>/dev/null) || true
    if echo "$output" | grep -q '"permissionDecision".*"ask"'; then
        _pass "$label"
    else
        _fail "$label" "expected ask decision, got: $(echo "$output" | head -1)"
    fi
}

# ---- Helpers ----

# Create a mock PreToolUse JSON input
mock_pretool_json() {
    local tool_name="$1" tool_input="$2"
    printf '{"tool_name":"%s","tool_input":%s}' "$tool_name" "$tool_input"
}

mock_bash_json() {
    local command="$1"
    local escaped
    escaped=$(printf '%s' "$command" | sed 's/"/\\"/g')
    printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$escaped"
}

mock_read_json() {
    local file_path="$1"
    local escaped
    escaped=$(printf '%s' "$file_path" | sed 's/"/\\"/g')
    printf '{"tool_name":"Read","tool_input":{"file_path":"%s"}}' "$escaped"
}

mock_fetch_json() {
    local url="$1"
    local escaped
    escaped=$(printf '%s' "$url" | sed 's/"/\\"/g')
    printf '{"tool_name":"WebFetch","tool_input":{"url":"%s","prompt":"fetch"}}' "$escaped"
}

mock_write_json() {
    local file_path="$1" content="$2"
    local esc_path esc_content
    esc_path=$(printf '%s' "$file_path" | sed 's/"/\\"/g')
    esc_content=$(printf '%s' "$content" | sed 's/"/\\"/g')
    printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"%s"}}' "$esc_path" "$esc_content"
}

# Create a temp directory for test isolation
create_test_dir() {
    mktemp -d "${TMPDIR:-/tmp}/cc-test-XXXXXX"
}
