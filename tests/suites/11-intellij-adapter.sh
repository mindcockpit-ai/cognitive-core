#!/bin/bash
# Test suite: IntelliJ adapter contract, generate.py, and install output
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"
source "${SCRIPT_DIR}/../lib/adapter-test-helpers.sh"

suite_start "11 — IntelliJ Adapter"

# ---- Adapter contract (#139 P5: shared helpers) ----
assert_adapter_validates "intellij"
assert_adapter_variables "intellij" ".cognitive-core"
assert_adapter_required_functions "intellij"
assert_adapter_py_compiles "intellij"

# ---- Test tool-map.yaml ----
assert_file_exists "intellij: tool-map.yaml exists" "${ROOT_DIR}/adapters/intellij/tool-map.yaml"
intellij_toolmap=$(cat "${ROOT_DIR}/adapters/intellij/tool-map.yaml")
assert_contains "intellij tool-map: has adapter field" "$intellij_toolmap" "adapter: intellij"
assert_contains "intellij tool-map: has capabilities" "$intellij_toolmap" "capabilities:"
assert_contains "intellij tool-map: has safety_approach" "$intellij_toolmap" "safety_approach:"

# ---- Test DEVOXXGENIE.md template ----
assert_file_exists "intellij: DEVOXXGENIE.md.tmpl exists" "${ROOT_DIR}/adapters/intellij/templates/DEVOXXGENIE.md.tmpl"
tmpl=$(cat "${ROOT_DIR}/adapters/intellij/templates/DEVOXXGENIE.md.tmpl")
assert_contains "template: has project placeholder" "$tmpl" "{{CC_PROJECT_NAME}}"
assert_contains "template: has safety rules placeholder" "$tmpl" "{{SAFETY_RULES}}"
assert_contains "template: has agent context placeholder" "$tmpl" "{{AGENT_CONTEXT}}"
assert_contains "template: has MCP server section" "$tmpl" "MCP Server"

# ---- Test MCP server files exist ----
assert_file_exists "intellij: server.py exists" "${ROOT_DIR}/adapters/intellij/mcp-server/server.py"
assert_file_exists "intellij: security_validate.py exists" "${ROOT_DIR}/adapters/intellij/mcp-server/tools/security_validate.py"
assert_file_exists "intellij: requirements.txt exists" "${ROOT_DIR}/adapters/intellij/mcp-server/requirements.txt"

# ---- Test full install with CC_PLATFORM=intellij ----
test_dir=$(create_test_dir)
trap 'rm -rf "$test_dir"' EXIT
git -C "$test_dir" init --quiet 2>/dev/null

cat > "${test_dir}/cognitive-core.conf" << 'EOF'
#!/bin/false
CC_PROJECT_NAME="intellij-test"
CC_PROJECT_DESCRIPTION="Test intellij adapter"
CC_ORG="test-org"
CC_PLATFORM="intellij"
CC_LANGUAGE="java"
CC_LINT_EXTENSIONS=".java"
CC_LINT_COMMAND="mvn checkstyle:check"
CC_FORMAT_COMMAND=""
CC_TEST_COMMAND="mvn test"
CC_TEST_PATTERN="src/test/**/*.java"
CC_DATABASE="oracle"
CC_ARCHITECTURE="hexagonal"
CC_SRC_ROOT="src/main/java"
CC_TEST_ROOT="src/test/java"
CC_AGENTS="coordinator reviewer"
CC_COORDINATOR_MODEL="opus"
CC_SPECIALIST_MODEL="sonnet"
CC_SKILLS="code-review"
CC_HOOKS="setup-env validate-bash"
CC_MAIN_BRANCH="main"
CC_COMMIT_FORMAT="conventional"
CC_COMMIT_SCOPES="core"
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
CC_INTELLIJ_MODEL="qwen2.5-coder:32b"
CC_INTELLIJ_OLLAMA_BASE="http://localhost:11434"
EOF

install_output=$(bash "${ROOT_DIR}/install.sh" "$test_dir" 2>&1) || {
    _fail "install with intellij adapter: exited with error"
    echo "$install_output" | tail -20
    suite_end || true
    exit 1
}

# Verify .cognitive-core directory structure
assert_dir_exists "intellij install: .cognitive-core/ created" "${test_dir}/.cognitive-core"
assert_dir_exists "intellij install: .cognitive-core/agents/ created" "${test_dir}/.cognitive-core/agents"
assert_dir_exists "intellij install: .cognitive-core/skills/ created" "${test_dir}/.cognitive-core/skills"
assert_dir_exists "intellij install: .cognitive-core/hooks/ created" "${test_dir}/.cognitive-core/hooks"
assert_dir_exists "intellij install: .cognitive-core/mcp-server/ created" "${test_dir}/.cognitive-core/mcp-server"

# Verify agents were copied
assert_file_exists "intellij install: project-coordinator.md" "${test_dir}/.cognitive-core/agents/project-coordinator.md"
assert_file_exists "intellij install: code-standards-reviewer.md" "${test_dir}/.cognitive-core/agents/code-standards-reviewer.md"

# Verify hooks were copied (for convention extraction)
assert_file_exists "intellij install: validate-bash.sh copied" "${test_dir}/.cognitive-core/hooks/validate-bash.sh"

# Verify IntelliJ-specific output files
assert_file_exists "intellij install: .devoxxgenie.yaml generated" "${test_dir}/.devoxxgenie.yaml"
assert_file_exists "intellij install: DEVOXXGENIE.md generated" "${test_dir}/DEVOXXGENIE.md"

# Verify MCP server was installed
assert_file_exists "intellij install: mcp server.py installed" "${test_dir}/.cognitive-core/mcp-server/server.py"
assert_file_exists "intellij install: security_validate.py installed" "${test_dir}/.cognitive-core/mcp-server/tools/security_validate.py"

# Verify DEVOXXGENIE.md contains safety rules
conventions=$(cat "${test_dir}/DEVOXXGENIE.md")
assert_contains "devoxxgenie: has safety section" "$conventions" "Safety Rules"
assert_contains "devoxxgenie: has rm rule" "$conventions" "rm"
assert_contains "devoxxgenie: has force push rule" "$conventions" "force"
assert_contains "devoxxgenie: has git reset rule" "$conventions" "reset"
assert_contains "devoxxgenie: has MCP section" "$conventions" "MCP"

# Verify no unresolved template placeholders
if echo "$conventions" | grep -qE '\{\{[A-Z_]+\}\}'; then
    _fail "devoxxgenie: no unresolved placeholders" "Found {{...}} in DEVOXXGENIE.md"
else
    _pass "devoxxgenie: no unresolved placeholders"
fi

# Verify .devoxxgenie.yaml content
dg_conf=$(cat "${test_dir}/.devoxxgenie.yaml")
assert_contains "devoxxgenie yaml: has provider" "$dg_conf" "provider:"
assert_contains "devoxxgenie yaml: has model" "$dg_conf" "model:"
assert_contains "devoxxgenie yaml: has ollama_url" "$dg_conf" "ollama_url:"
assert_contains "devoxxgenie yaml: has context_files" "$dg_conf" "context_files:"
assert_contains "devoxxgenie yaml: has DEVOXXGENIE.md" "$dg_conf" "DEVOXXGENIE.md"
assert_contains "devoxxgenie yaml: has mcp_server" "$dg_conf" "mcp_server:"

# Verify version.json has platform=intellij
version_json=$(cat "${test_dir}/.cognitive-core/cognitive-core/version.json")
assert_contains "version.json: platform=intellij" "$version_json" '"intellij"'

# Verify NO .claude directory was created
if [ -d "${test_dir}/.claude" ]; then
    _fail "intellij install: should NOT create .claude/"
else
    _pass "intellij install: no .claude/ directory (correct)"
fi

# Verify NO CLAUDE.md was created
if [ -f "${test_dir}/CLAUDE.md" ]; then
    _fail "intellij install: should NOT create CLAUDE.md"
else
    _pass "intellij install: no CLAUDE.md (correct — has DEVOXXGENIE.md instead)"
fi

suite_end
