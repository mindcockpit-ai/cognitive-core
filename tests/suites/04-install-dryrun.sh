#!/bin/bash
# Test suite: Install to temp directory → verify structure
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "04 — Install Dry Run"

# Create a temp project directory
test_dir=$(create_test_dir)
git -C "$test_dir" init --quiet 2>/dev/null

# Create a minimal config file to drive non-interactive install
cat > "${test_dir}/cognitive-core.conf" << 'EOF'
#!/bin/false
CC_PROJECT_NAME="test-project"
CC_PROJECT_DESCRIPTION="Test project"
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
CC_AGENTS="coordinator reviewer researcher"
CC_COORDINATOR_MODEL="opus"
CC_SPECIALIST_MODEL="sonnet"
CC_SKILLS="session-resume code-review security-baseline"
CC_HOOKS="setup-env compact-reminder validate-bash validate-read validate-fetch validate-write post-edit-lint"
CC_MAIN_BRANCH="main"
CC_COMMIT_FORMAT="conventional"
CC_COMMIT_SCOPES="api core"
CC_ENABLE_CICD="false"
CC_RUNNER_TYPE="github-hosted"
CC_MONITORING="false"
CC_SECURITY_LEVEL="standard"
CC_BLOCKED_PATTERNS=""
CC_ALLOWED_DOMAINS=""
CC_KNOWN_SAFE_DOMAINS=""
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

# Run install
install_output=$(bash "${ROOT_DIR}/install.sh" "$test_dir" 2>&1) || {
    _fail "install.sh exited with error"
    echo "$install_output" | tail -20
    rm -rf "$test_dir"
    suite_end || true
    exit 1
}

# ---- Verify directory structure ----
assert_dir_exists "install: .claude/ created" "${test_dir}/.claude"
assert_dir_exists "install: .claude/hooks/ created" "${test_dir}/.claude/hooks"
assert_dir_exists "install: .claude/agents/ created" "${test_dir}/.claude/agents"
assert_dir_exists "install: .claude/skills/ created" "${test_dir}/.claude/skills"
assert_dir_exists "install: .claude/cognitive-core/ created" "${test_dir}/.claude/cognitive-core"

# ---- Verify hooks ----
assert_file_exists "install: _lib.sh installed" "${test_dir}/.claude/hooks/_lib.sh"
assert_file_exists "install: setup-env.sh installed" "${test_dir}/.claude/hooks/setup-env.sh"
assert_file_exists "install: validate-bash.sh installed" "${test_dir}/.claude/hooks/validate-bash.sh"
assert_file_exists "install: validate-read.sh installed" "${test_dir}/.claude/hooks/validate-read.sh"
assert_file_exists "install: validate-fetch.sh installed" "${test_dir}/.claude/hooks/validate-fetch.sh"
assert_file_exists "install: validate-write.sh installed" "${test_dir}/.claude/hooks/validate-write.sh"
assert_file_exists "install: post-edit-lint.sh installed" "${test_dir}/.claude/hooks/post-edit-lint.sh"
assert_file_executable "install: validate-bash.sh executable" "${test_dir}/.claude/hooks/validate-bash.sh"

# ---- Verify agents ----
assert_file_exists "install: project-coordinator.md installed" "${test_dir}/.claude/agents/project-coordinator.md"
assert_file_exists "install: code-standards-reviewer.md installed" "${test_dir}/.claude/agents/code-standards-reviewer.md"
assert_file_exists "install: research-analyst.md installed" "${test_dir}/.claude/agents/research-analyst.md"

# ---- Verify skills ----
assert_file_exists "install: session-resume skill installed" "${test_dir}/.claude/skills/session-resume/SKILL.md"
assert_file_exists "install: code-review skill installed" "${test_dir}/.claude/skills/code-review/SKILL.md"
assert_file_exists "install: security-baseline skill installed" "${test_dir}/.claude/skills/security-baseline/SKILL.md"

# ---- Verify settings.json ----
assert_file_exists "install: settings.json generated" "${test_dir}/.claude/settings.json"

# Check that new hooks are wired in settings.json
settings_content=$(cat "${test_dir}/.claude/settings.json")
assert_contains "install: settings has validate-read hook" "$settings_content" "validate-read.sh"
assert_contains "install: settings has validate-fetch hook" "$settings_content" "validate-fetch.sh"
assert_contains "install: settings has validate-write hook" "$settings_content" "validate-write.sh"

# ---- Verify version manifest ----
assert_file_exists "install: version.json created" "${test_dir}/.claude/cognitive-core/version.json"

version_content=$(cat "${test_dir}/.claude/cognitive-core/version.json")
assert_contains "install: version.json has version" "$version_content" '"version"'
assert_contains "install: version.json has source" "$version_content" '"source"'

# ---- Verify CLAUDE.md ----
assert_file_exists "install: CLAUDE.md generated" "${test_dir}/CLAUDE.md"

# ---- Verify utilities ----
assert_file_exists "install: check-update.sh installed" "${test_dir}/.claude/cognitive-core/check-update.sh"
assert_file_exists "install: context-cleanup.sh installed" "${test_dir}/.claude/cognitive-core/context-cleanup.sh"
assert_file_exists "install: health-check.sh installed" "${test_dir}/.claude/cognitive-core/health-check.sh"
assert_file_executable "install: health-check.sh executable" "${test_dir}/.claude/cognitive-core/health-check.sh"

# ---- Verify AGENTS_README.md ----
assert_file_exists "install: AGENTS_README.md generated" "${test_dir}/.claude/AGENTS_README.md"
agents_readme=$(cat "${test_dir}/.claude/AGENTS_README.md")
assert_contains "install: AGENTS_README has hub-and-spoke" "$agents_readme" "Hub-and-Spoke"
assert_contains "install: AGENTS_README has keyword routing" "$agents_readme" "Keyword"
assert_contains "install: AGENTS_README has Use when" "$agents_readme" "Use when"
assert_contains "install: AGENTS_README has Don't use for" "$agents_readme" "Don't use for"

# ---- Verify compact-reminder.sh installed ----
assert_file_exists "install: compact-reminder.sh installed" "${test_dir}/.claude/hooks/compact-reminder.sh"

# Cleanup
rm -rf "$test_dir"

suite_end
