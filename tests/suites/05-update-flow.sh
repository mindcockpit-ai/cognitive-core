#!/bin/bash
# Test suite: Install → modify → update → verify preservation
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "05 — Update Flow"

# Need python3 for update.sh JSON parsing
if ! command -v python3 &>/dev/null; then
    _skip "python3 not available (needed for update.sh)"
    suite_end || true
    exit 0
fi

# Create a temp project directory
test_dir=$(create_test_dir)
git -C "$test_dir" init --quiet 2>/dev/null

# Create config
cat > "${test_dir}/cognitive-core.conf" << 'EOF'
#!/bin/false
CC_PROJECT_NAME="update-test"
CC_PROJECT_DESCRIPTION="Update test project"
CC_ORG="test-org"
CC_LANGUAGE="python"
CC_LINT_EXTENSIONS=".py"
CC_LINT_COMMAND="ruff check $1"
CC_FORMAT_COMMAND=""
CC_TEST_COMMAND="pytest"
CC_TEST_PATTERN="tests/**/*.py"
CC_DATABASE="none"
CC_ARCHITECTURE="ddd"
CC_SRC_ROOT="src"
CC_TEST_ROOT="tests"
CC_AGENTS="coordinator reviewer"
CC_COORDINATOR_MODEL="opus"
CC_SPECIALIST_MODEL="sonnet"
CC_SKILLS="session-resume code-review"
CC_HOOKS="setup-env compact-reminder validate-bash post-edit-lint"
CC_MAIN_BRANCH="main"
CC_COMMIT_FORMAT="conventional"
CC_COMMIT_SCOPES="api core"
CC_ENABLE_CICD="false"
CC_RUNNER_TYPE="github-hosted"
CC_MONITORING="false"
CC_COMPACT_RULES="1. Follow standards"
CC_ENABLE_CLEANUP_CRON="false"
CC_SESSION_DOCS_DIR="docs"
CC_SESSION_MAX_AGE_DAYS="30"
CC_FITNESS_LINT="60"
CC_FITNESS_COMMIT="80"
CC_FITNESS_TEST="85"
CC_FITNESS_MERGE="90"
CC_FITNESS_DEPLOY="95"
CC_RUNNER_NODES="1"
CC_RUNNER_LABELS="self-hosted"
CC_AGENT_TEAMS="false"
CC_MCP_SERVERS=""
EOF

# Step 1: Install
install_output=$(bash "${ROOT_DIR}/install.sh" "$test_dir" 2>&1) || {
    _fail "install failed"
    rm -rf "$test_dir"
    suite_end || true
    exit 1
}
_pass "step 1: install succeeds"

# Step 2: Modify a file (user customization)
echo "# User customization" >> "${test_dir}/.claude/hooks/validate-bash.sh"
_pass "step 2: modified validate-bash.sh"

# Step 3: Run update
update_output=$(bash "${ROOT_DIR}/update.sh" "$test_dir" 2>&1) || {
    _fail "update failed"
    echo "$update_output" | tail -20
    rm -rf "$test_dir"
    suite_end || true
    exit 1
}
_pass "step 3: update succeeds"

# Step 4: Verify user-modified file was preserved
if grep -q "# User customization" "${test_dir}/.claude/hooks/validate-bash.sh"; then
    _pass "step 4: user-modified validate-bash.sh preserved"
else
    _fail "step 4: user-modified validate-bash.sh was overwritten"
fi

# Step 5: Verify unmodified files were updated (or remain unchanged)
# _lib.sh should be current (was not modified)
if [ -f "${test_dir}/.claude/hooks/_lib.sh" ]; then
    _pass "step 5: _lib.sh still present after update"
else
    _fail "step 5: _lib.sh missing after update"
fi

# Step 6: Verify version manifest was updated
if grep -q '"updated_at"' "${test_dir}/.claude/cognitive-core/version.json"; then
    _pass "step 6: version.json has updated_at timestamp"
else
    _fail "step 6: version.json missing updated_at"
fi

# Cleanup
rm -rf "$test_dir"

suite_end
