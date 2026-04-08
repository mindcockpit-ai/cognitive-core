#!/bin/bash
# Test suite: VS Code adapter contract, generate.py, and install output
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"
source "${SCRIPT_DIR}/../lib/adapter-test-helpers.sh"

suite_start "18 — VS Code Adapter"

# ---- Adapter contract (#139 P5: shared helpers) ----
assert_adapter_validates "vscode"
assert_adapter_variables "vscode" ".cognitive-core"
assert_adapter_required_functions "vscode"
assert_adapter_py_compiles "vscode"

# ---- Test tool-map.yaml ----
assert_file_exists "vscode: tool-map.yaml exists" "${ROOT_DIR}/adapters/vscode/tool-map.yaml"
vscode_toolmap=$(cat "${ROOT_DIR}/adapters/vscode/tool-map.yaml")
assert_contains "vscode tool-map: has adapter field" "$vscode_toolmap" "adapter: vscode"
assert_contains "vscode tool-map: has capabilities" "$vscode_toolmap" "capabilities:"
assert_contains "vscode tool-map: has safety_approach" "$vscode_toolmap" "safety_approach:"

# ---- Test copilot-instructions.md template ----
assert_file_exists "vscode: copilot-instructions.md.tmpl exists" "${ROOT_DIR}/adapters/vscode/templates/copilot-instructions.md.tmpl"
tmpl=$(cat "${ROOT_DIR}/adapters/vscode/templates/copilot-instructions.md.tmpl")
assert_contains "template: has project placeholder" "$tmpl" "{{CC_PROJECT_NAME}}"
assert_contains "template: has language placeholder" "$tmpl" "{{CC_LANGUAGE}}"
assert_contains "template: has safety rules placeholder" "$tmpl" "{{SAFETY_RULES}}"
assert_contains "template: has agent context placeholder" "$tmpl" "{{AGENT_CONTEXT}}"
assert_contains "template: has MCP server section" "$tmpl" "MCP Server"
assert_contains "template: has commit format placeholder" "$tmpl" "{{CC_COMMIT_FORMAT}}"
assert_contains "template: has src root placeholder" "$tmpl" "{{CC_SRC_ROOT}}"
assert_contains "template: has test root placeholder" "$tmpl" "{{CC_TEST_ROOT}}"
assert_contains "template: has compact rules placeholder" "$tmpl" "{{CC_COMPACT_RULES}}"

# ---- Test full install with CC_PLATFORM=vscode ----
test_dir=$(create_test_dir)
trap 'rm -rf "$test_dir"' EXIT
git -C "$test_dir" init --quiet 2>/dev/null

cat > "${test_dir}/cognitive-core.conf" << 'EOF'
#!/bin/false
CC_PROJECT_NAME="vscode-test"
CC_PROJECT_DESCRIPTION="Test vscode adapter"
CC_ORG="test-org"
CC_PLATFORM="vscode"
CC_LANGUAGE="python"
CC_LINT_EXTENSIONS=".py"
CC_LINT_COMMAND="ruff check"
CC_FORMAT_COMMAND=""
CC_TEST_COMMAND="pytest"
CC_TEST_PATTERN="tests/**/*.py"
CC_DATABASE="postgresql"
CC_ARCHITECTURE="ddd"
CC_SRC_ROOT="src"
CC_TEST_ROOT="tests"
CC_AGENTS="coordinator reviewer"
CC_COORDINATOR_MODEL="opus"
CC_SPECIALIST_MODEL="sonnet"
CC_SKILLS="code-review"
CC_HOOKS="setup-env validate-bash"
CC_MAIN_BRANCH="main"
CC_COMMIT_FORMAT="conventional"
CC_COMMIT_SCOPES="api ui db"
CC_ENABLE_CICD="false"
CC_RUNNER_TYPE="github-hosted"
CC_MONITORING="false"
CC_SECURITY_LEVEL="standard"
CC_BLOCKED_PATTERNS=""
CC_ALLOWED_DOMAINS=""
CC_KNOWN_SAFE_DOMAINS=""
CC_COMPACT_RULES="1. Follow coding standards"
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

install_output=$(bash "${ROOT_DIR}/install.sh" "$test_dir" 2>&1) || {
    _fail "install with vscode adapter: exited with error"
    echo "$install_output" | tail -20
    suite_end || true
    exit 1
}

# Verify .cognitive-core directory structure
assert_dir_exists "vscode install: .cognitive-core/ created" "${test_dir}/.cognitive-core"
assert_dir_exists "vscode install: .cognitive-core/agents/ created" "${test_dir}/.cognitive-core/agents"
assert_dir_exists "vscode install: .cognitive-core/skills/ created" "${test_dir}/.cognitive-core/skills"
assert_dir_exists "vscode install: .cognitive-core/hooks/ created" "${test_dir}/.cognitive-core/hooks"
assert_dir_exists "vscode install: .cognitive-core/mcp-server/ created" "${test_dir}/.cognitive-core/mcp-server"

# Verify agents were copied
assert_file_exists "vscode install: project-coordinator.md" "${test_dir}/.cognitive-core/agents/project-coordinator.md"
assert_file_exists "vscode install: code-standards-reviewer.md" "${test_dir}/.cognitive-core/agents/code-standards-reviewer.md"

# Verify hooks were copied (for convention extraction)
assert_file_exists "vscode install: validate-bash.sh copied" "${test_dir}/.cognitive-core/hooks/validate-bash.sh"

# Verify VS Code-specific output files
assert_dir_exists "vscode install: .github/ created" "${test_dir}/.github"
assert_file_exists "vscode install: copilot-instructions.md generated" "${test_dir}/.github/copilot-instructions.md"
assert_dir_exists "vscode install: .vscode/ created" "${test_dir}/.vscode"
assert_file_exists "vscode install: .vscode/mcp.json generated" "${test_dir}/.vscode/mcp.json"

# Verify MCP server was installed
assert_file_exists "vscode install: mcp server.py installed" "${test_dir}/.cognitive-core/mcp-server/server.py"
assert_file_exists "vscode install: security_validate.py installed" "${test_dir}/.cognitive-core/mcp-server/tools/security_validate.py"

# Verify copilot-instructions.md contains safety rules
instructions=$(cat "${test_dir}/.github/copilot-instructions.md")
assert_contains "copilot-instructions: has safety section" "$instructions" "Safety Rules"
assert_contains "copilot-instructions: has rm rule" "$instructions" "rm"
assert_contains "copilot-instructions: has force push rule" "$instructions" "force"
assert_contains "copilot-instructions: has git reset rule" "$instructions" "reset"
assert_contains "copilot-instructions: has MCP section" "$instructions" "MCP"

# Verify no unresolved template placeholders
if echo "$instructions" | grep -qE '\{\{[A-Z_]+\}\}'; then
    _fail "copilot-instructions: no unresolved placeholders" "Found {{...}} in copilot-instructions.md"
else
    _pass "copilot-instructions: no unresolved placeholders"
fi

# Verify .vscode/mcp.json content
mcp_json=$(cat "${test_dir}/.vscode/mcp.json")
assert_contains "mcp.json: has servers" "$mcp_json" "servers"
assert_contains "mcp.json: has cognitive-core" "$mcp_json" "cognitive-core"
assert_contains "mcp.json: has stdio type" "$mcp_json" "stdio"
assert_contains "mcp.json: has python3 command" "$mcp_json" "python3"
assert_contains "mcp.json: has server.py" "$mcp_json" "server.py"

# Verify version.json has platform=vscode
version_json=$(cat "${test_dir}/.cognitive-core/cognitive-core/version.json")
assert_contains "version.json: platform=vscode" "$version_json" '"vscode"'

# Verify NO .claude directory was created
if [ -d "${test_dir}/.claude" ]; then
    _fail "vscode install: should NOT create .claude/"
else
    _pass "vscode install: no .claude/ directory (correct)"
fi

# Verify NO CLAUDE.md was created
if [ -f "${test_dir}/CLAUDE.md" ]; then
    _fail "vscode install: should NOT create CLAUDE.md"
else
    _pass "vscode install: no CLAUDE.md (correct — has copilot-instructions.md instead)"
fi

# Verify NO DEVOXXGENIE.md was created
if [ -f "${test_dir}/DEVOXXGENIE.md" ]; then
    _fail "vscode install: should NOT create DEVOXXGENIE.md"
else
    _pass "vscode install: no DEVOXXGENIE.md (correct — has copilot-instructions.md instead)"
fi

# ===========================================================================
# Integration test: install vscode adapter on a real cloned repo
# Workflow: clone repo → clean AI artifacts → install → validate → sanity
# ===========================================================================

# Use cognitive-core itself as the test target (always available)
repo_test_dir=$(create_test_dir)
repo_dir="${repo_test_dir}/repo"

git clone --depth 1 --quiet "file://${ROOT_DIR}" "$repo_dir" 2>/dev/null || {
    _skip "repo integration: git clone failed (skipping repo-based tests)"
    suite_end || true
    exit 0
}

# ---- Phase 1: Clean all AI/framework artifacts ----
rm -rf "${repo_dir}/.claude" \
       "${repo_dir}/.claude-plugin" \
       "${repo_dir}/.cognitive-core" \
       "${repo_dir}/.vscode" \
       "${repo_dir}/.github/copilot-instructions.md" \
       "${repo_dir}/.devoxxgenie.yaml" \
       "${repo_dir}/DEVOXXGENIE.md" \
       "${repo_dir}/CONVENTIONS.md" \
       "${repo_dir}/.mcp.json" 2>/dev/null || true

# Track if CLAUDE.md existed before install (repo may have its own)
pre_existing_claudemd="false"
if [ -f "${repo_dir}/CLAUDE.md" ]; then
    pre_existing_claudemd="true"
fi

# ---- Phase 2: Write vscode config ----
cat > "${repo_dir}/cognitive-core.conf" << 'REPOEOF'
#!/bin/false
CC_PROJECT_NAME="repo-integration-test"
CC_PROJECT_DESCRIPTION="Integration test on real repo"
CC_ORG="test-org"
CC_PLATFORM="vscode"
CC_LANGUAGE="bash"
CC_LINT_EXTENSIONS=".sh"
CC_LINT_COMMAND="bash -n"
CC_FORMAT_COMMAND=""
CC_TEST_COMMAND="bash tests/run-all.sh"
CC_TEST_PATTERN="tests/**/*.sh"
CC_DATABASE="none"
CC_ARCHITECTURE="layered"
CC_SRC_ROOT="core"
CC_TEST_ROOT="tests"
CC_AGENTS="coordinator reviewer"
CC_COORDINATOR_MODEL="opus"
CC_SPECIALIST_MODEL="sonnet"
CC_SKILLS="code-review"
CC_HOOKS="setup-env validate-bash validate-write"
CC_MAIN_BRANCH="main"
CC_COMMIT_FORMAT="conventional"
CC_COMMIT_SCOPES="hooks,agents,skills,adapters"
CC_ENABLE_CICD="false"
CC_RUNNER_TYPE="github-hosted"
CC_MONITORING="false"
CC_SECURITY_LEVEL="standard"
CC_BLOCKED_PATTERNS=""
CC_ALLOWED_DOMAINS=""
CC_KNOWN_SAFE_DOMAINS=""
CC_COMPACT_RULES="1. This IS the framework"
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
REPOEOF

# ---- Phase 3: Run install ----
repo_install_output=$(bash "${ROOT_DIR}/install.sh" "$repo_dir" 2>&1) || {
    _fail "repo integration: install.sh exited with error"
    echo "$repo_install_output" | tail -20
    rm -rf "$repo_test_dir"
    suite_end || true
    exit 1
}
_pass "repo integration: install.sh completed successfully"

# ---- Phase 4: Validate output ----
assert_dir_exists  "repo: .cognitive-core/ created"    "${repo_dir}/.cognitive-core"
assert_dir_exists  "repo: .cognitive-core/agents/"     "${repo_dir}/.cognitive-core/agents"
assert_dir_exists  "repo: .cognitive-core/hooks/"      "${repo_dir}/.cognitive-core/hooks"
assert_dir_exists  "repo: .cognitive-core/mcp-server/" "${repo_dir}/.cognitive-core/mcp-server"
assert_dir_exists  "repo: .github/ exists"             "${repo_dir}/.github"
assert_dir_exists  "repo: .vscode/ exists"             "${repo_dir}/.vscode"

assert_file_exists "repo: copilot-instructions.md"     "${repo_dir}/.github/copilot-instructions.md"
assert_file_exists "repo: .vscode/mcp.json"            "${repo_dir}/.vscode/mcp.json"
assert_file_exists "repo: MCP server.py"               "${repo_dir}/.cognitive-core/mcp-server/server.py"
assert_file_exists "repo: project-coordinator.md"      "${repo_dir}/.cognitive-core/agents/project-coordinator.md"
assert_file_exists "repo: validate-bash.sh"            "${repo_dir}/.cognitive-core/hooks/validate-bash.sh"

# Content checks
repo_instructions=$(cat "${repo_dir}/.github/copilot-instructions.md")
assert_contains "repo: instructions have project name" "$repo_instructions" "repo-integration-test"
assert_contains "repo: instructions have safety rules" "$repo_instructions" "Safety Rules"

if echo "$repo_instructions" | grep -qE '\{\{[A-Z_]+\}\}'; then
    _fail "repo: no unresolved placeholders"
else
    _pass "repo: no unresolved placeholders"
fi

repo_version=$(cat "${repo_dir}/.cognitive-core/cognitive-core/version.json")
assert_contains "repo: version.json platform=vscode" "$repo_version" '"vscode"'

# ---- Phase 5: Conditional checks for pre-existing files ----
if [ "$pre_existing_claudemd" = "true" ]; then
    # CLAUDE.md existed before install — adapter should NOT have deleted it
    if [ -f "${repo_dir}/CLAUDE.md" ]; then
        _pass "repo: pre-existing CLAUDE.md preserved (correct)"
        _note "repo: CLAUDE.md was pre-existing — adapter correctly left it alone"
    else
        _fail "repo: pre-existing CLAUDE.md was deleted by adapter"
    fi
else
    # No pre-existing CLAUDE.md — adapter should NOT have created one
    if [ -f "${repo_dir}/CLAUDE.md" ]; then
        _fail "repo: should NOT create CLAUDE.md on vscode platform"
    else
        _pass "repo: no CLAUDE.md created (correct)"
    fi
fi

if [ -f "${repo_dir}/DEVOXXGENIE.md" ]; then
    _fail "repo: should NOT create DEVOXXGENIE.md"
else
    _pass "repo: no DEVOXXGENIE.md (correct)"
fi

# ---- Phase 6: Sanity — no broken files ----
# MCP server should be valid Python
if command -v python3 &>/dev/null; then
    py_ok=$(python3 -c "import py_compile; py_compile.compile('${repo_dir}/.cognitive-core/mcp-server/server.py', doraise=True)" 2>&1) || true
    if [ -z "$py_ok" ]; then
        _pass "repo: MCP server.py is valid Python"
    else
        _fail "repo: MCP server.py compile error" "$py_ok"
    fi
else
    _skip "repo: MCP server.py compile check (python3 not available)"
fi

# All .sh files in hooks should be executable
for hook_file in "${repo_dir}/.cognitive-core/hooks/"*.sh; do
    [ -f "$hook_file" ] || continue
    hook_base=$(basename "$hook_file")
    if [ -x "$hook_file" ]; then
        _pass "repo: ${hook_base} is executable"
    else
        _fail "repo: ${hook_base} is not executable"
    fi
done

# Cleanup
rm -rf "$repo_test_dir"

suite_end
