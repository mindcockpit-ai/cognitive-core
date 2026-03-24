#!/bin/bash
# Test suite: VS Code adapter contract, generate.py, and install output
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "18 — VS Code Adapter"

# ---- Test adapter.sh passes contract validation ----
vscode_validate=$(bash -c "
    err() { printf '%s\n' \"\$*\" >&2; }
    info() { printf '%s\n' \"\$*\"; }
    warn() { printf '%s\n' \"\$*\"; }
    SCRIPT_DIR='${ROOT_DIR}'
    FORCE=false
    CC_INSTALL_DIR='/tmp/test-cc'
    source '${ROOT_DIR}/adapters/_adapter-lib.sh'
    source '${ROOT_DIR}/adapters/vscode/adapter.sh'
    _adapter_validate && echo 'VALID'
" 2>&1)
assert_contains "vscode adapter: passes validation" "$vscode_validate" "VALID"

# ---- Test adapter variables ----
adapter_name=$(bash -c "
    err() { : ; }; info() { : ; }; warn() { : ; }
    SCRIPT_DIR='${ROOT_DIR}'; FORCE=false; CC_INSTALL_DIR='/tmp/test-cc'
    source '${ROOT_DIR}/adapters/_adapter-lib.sh'
    source '${ROOT_DIR}/adapters/vscode/adapter.sh'
    echo \"\$_ADAPTER_NAME\"
" 2>&1)
assert_eq "vscode adapter: _ADAPTER_NAME=vscode" "vscode" "$adapter_name"

install_dir=$(bash -c "
    err() { : ; }; info() { : ; }; warn() { : ; }
    SCRIPT_DIR='${ROOT_DIR}'; FORCE=false; CC_INSTALL_DIR='/tmp/test-cc'
    source '${ROOT_DIR}/adapters/_adapter-lib.sh'
    source '${ROOT_DIR}/adapters/vscode/adapter.sh'
    echo \"\$_ADAPTER_INSTALL_DIR\"
" 2>&1)
assert_eq "vscode adapter: _ADAPTER_INSTALL_DIR=.cognitive-core" ".cognitive-core" "$install_dir"

# ---- Test all 5 required functions are defined ----
for fn in _adapter_install_hook _adapter_install_agent _adapter_install_skill _adapter_generate_settings _adapter_generate_project_readme; do
    fn_check=$(bash -c "
        err() { : ; }; info() { : ; }; warn() { : ; }
        SCRIPT_DIR='${ROOT_DIR}'; FORCE=false; CC_INSTALL_DIR='/tmp/test-cc'
        source '${ROOT_DIR}/adapters/_adapter-lib.sh'
        source '${ROOT_DIR}/adapters/vscode/adapter.sh'
        type $fn &>/dev/null && echo 'DEFINED'
    " 2>&1)
    assert_eq "vscode adapter: ${fn} defined" "DEFINED" "$fn_check"
done

# ---- Test generate.py exists and is valid Python ----
assert_file_exists "vscode: generate.py exists" "${ROOT_DIR}/adapters/vscode/generate.py"

if command -v python3 &>/dev/null; then
    py_check=$(python3 -c "import py_compile; py_compile.compile('${ROOT_DIR}/adapters/vscode/generate.py', doraise=True)" 2>&1) || true
    if [ -z "$py_check" ]; then
        _pass "vscode: generate.py compiles without error"
    else
        _fail "vscode: generate.py compiles without error" "$py_check"
    fi
else
    _skip "vscode: generate.py compile check (python3 not available)"
fi

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

suite_end
