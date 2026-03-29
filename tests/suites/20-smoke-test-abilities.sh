#!/bin/bash
# Test suite: Smoke test ability scripts
# Validates the decomposed D-type and D/S-type ability scripts
# follow the contract, handle errors, and produce valid output.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "20 — Smoke Test Abilities"

ST_DIR="${ROOT_DIR}/core/skills/smoke-test"
SCRIPTS_DIR="${ST_DIR}/scripts"

# =============================================================================
# Section 1: File existence and structure
# =============================================================================

assert_file_exists "scripts: _smoke-lib.sh exists" "${SCRIPTS_DIR}/_smoke-lib.sh"
assert_file_exists "scripts: preflight.sh exists" "${SCRIPTS_DIR}/preflight.sh"
assert_file_exists "scripts: execute-test.sh exists" "${SCRIPTS_DIR}/execute-test.sh"
assert_file_exists "scripts: check-issues.sh exists" "${SCRIPTS_DIR}/check-issues.sh"
assert_file_exists "scripts: create-issue.sh exists" "${SCRIPTS_DIR}/create-issue.sh"
assert_file_exists "scripts: list-open-issues.sh exists" "${SCRIPTS_DIR}/list-open-issues.sh"

# =============================================================================
# Section 2: Syntax validation (bash -n)
# =============================================================================

for script in _smoke-lib.sh preflight.sh execute-test.sh check-issues.sh create-issue.sh list-open-issues.sh; do
    syntax_output=$(bash -n "${SCRIPTS_DIR}/${script}" 2>&1) || true
    if [ -z "$syntax_output" ]; then
        _pass "syntax: ${script} passes bash -n"
    else
        _fail "syntax: ${script} fails bash -n" "$syntax_output"
    fi
done

# =============================================================================
# Section 3: Shared library sources cleanly
# =============================================================================

MOCK_DIR=$(create_test_dir)

# Create minimal mock config
cat > "${MOCK_DIR}/cognitive-core.conf" << 'CONFEOF'
CC_SMOKE_TEST_COMMAND="echo test"
CC_SMOKE_TEST_URL="http://localhost:8080"
CC_SMOKE_TEST_LABEL="smoke-test"
CC_ORG="test-org"
CC_PROJECT_NAME="test-repo"
CONFEOF

# Test that _smoke-lib.sh can be sourced
lib_output=$(PROJECT_DIR="$MOCK_DIR" bash -c "source '${SCRIPTS_DIR}/_smoke-lib.sh' && _st_load_config && _st_repo" 2>&1) || true
assert_contains "lib: _st_repo returns org/repo" "$lib_output" "test-org/test-repo"

label_output=$(PROJECT_DIR="$MOCK_DIR" bash -c "source '${SCRIPTS_DIR}/_smoke-lib.sh' && _st_load_config && _st_label" 2>&1) || true
assert_contains "lib: _st_label returns default label" "$label_output" "smoke-test"

# =============================================================================
# Section 4: preflight.sh rejects missing config
# =============================================================================

EMPTY_DIR=$(create_test_dir)
cat > "${EMPTY_DIR}/cognitive-core.conf" << 'CONFEOF'
# Missing required vars
CONFEOF

preflight_exit=0
preflight_output=$(PROJECT_DIR="$EMPTY_DIR" bash "${SCRIPTS_DIR}/preflight.sh" 2>&1) || preflight_exit=$?
assert_ne "preflight: rejects missing config" "0" "$preflight_exit"
assert_contains "preflight: error mentions variable" "$preflight_output" "not set"

# =============================================================================
# Section 5: execute-test.sh rejects invalid JSON
# =============================================================================

BAD_JSON_DIR=$(create_test_dir)
cat > "${BAD_JSON_DIR}/cognitive-core.conf" << 'CONFEOF'
CC_SMOKE_TEST_COMMAND="echo 'not valid json'"
CC_SMOKE_TEST_URL="http://localhost:8080"
CC_ORG="test-org"
CC_PROJECT_NAME="test-repo"
CONFEOF

exec_exit=0
exec_output=$(PROJECT_DIR="$BAD_JSON_DIR" bash "${SCRIPTS_DIR}/execute-test.sh" 2>&1) || exec_exit=$?

if command -v jq &>/dev/null; then
    assert_ne "execute-test: rejects invalid JSON" "0" "$exec_exit"
    assert_contains "execute-test: error mentions JSON" "$exec_output" "JSON"
else
    _skip "execute-test: JSON validation (jq not available)"
fi

# =============================================================================
# Section 6: execute-test.sh accepts valid JSON
# =============================================================================

GOOD_JSON_DIR=$(create_test_dir)
cat > "${GOOD_JSON_DIR}/sample.json" << 'JSONEOF'
{"timestamp":"2026-03-29T12:00:00Z","server":"http://localhost","environment":"test","summary":{"total":2,"passed":1,"failed":1},"results":[{"name":"Home","url":"/","status":"PASS","httpCode":200,"errors":[]},{"name":"Admin","url":"/admin","status":"FAIL","httpCode":200,"errors":["ORA-00904"]}]}
JSONEOF
cat > "${GOOD_JSON_DIR}/cognitive-core.conf" << CONFEOF
CC_SMOKE_TEST_COMMAND="cat ${GOOD_JSON_DIR}/sample.json"
CC_SMOKE_TEST_URL="http://localhost:8080"
CC_ORG="test-org"
CC_PROJECT_NAME="test-repo"
CONFEOF

exec_good_exit=0
exec_good_output=$(PROJECT_DIR="$GOOD_JSON_DIR" bash "${SCRIPTS_DIR}/execute-test.sh" 2>&1) || exec_good_exit=$?

if command -v jq &>/dev/null; then
    assert_eq "execute-test: accepts valid JSON" "0" "$exec_good_exit"
    # Verify output is valid JSON
    echo "$exec_good_output" | jq . >/dev/null 2>&1
    jq_exit=$?
    assert_eq "execute-test: output is valid JSON" "0" "$jq_exit"
else
    _skip "execute-test: valid JSON check (jq not available)"
fi

# =============================================================================
# Section 7: create-issue.sh rejects missing title
# =============================================================================

create_exit=0
create_output=$(PROJECT_DIR="$MOCK_DIR" bash "${SCRIPTS_DIR}/create-issue.sh" 2>&1) || create_exit=$?
assert_ne "create-issue: rejects missing title" "0" "$create_exit"
assert_contains "create-issue: error mentions usage" "$create_output" "Usage"

# =============================================================================
# Section 8: SKILL.md has ability registry
# =============================================================================

skillmd_content=$(cat "${ST_DIR}/SKILL.md")
assert_contains "SKILL.md: has ability registry section" "$skillmd_content" "Ability Registry"
assert_contains "SKILL.md: references preflight.sh" "$skillmd_content" "preflight.sh"
assert_contains "SKILL.md: references execute-test.sh" "$skillmd_content" "execute-test.sh"
assert_contains "SKILL.md: references check-issues.sh" "$skillmd_content" "check-issues.sh"
assert_contains "SKILL.md: references create-issue.sh" "$skillmd_content" "create-issue.sh"

# =============================================================================
# Section 9: Ability type annotations present
# =============================================================================

assert_contains "SKILL.md: D-type annotation" "$skillmd_content" "[D]"
assert_contains "SKILL.md: D/S-type annotation" "$skillmd_content" "[D/S]"
assert_contains "SKILL.md: S/D-type annotation" "$skillmd_content" "[S/D]"
assert_contains "SKILL.md: H-type annotation" "$skillmd_content" "[H]"

suite_end
