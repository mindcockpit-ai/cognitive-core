#!/bin/bash
# Test suite: Aider adapter contract, generate.py, and install output
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "10 — Aider Adapter"

# ---- Test adapter.sh passes contract validation ----
aider_validate=$(bash -c "
    err() { printf '%s\n' \"\$*\" >&2; }
    info() { printf '%s\n' \"\$*\"; }
    warn() { printf '%s\n' \"\$*\"; }
    SCRIPT_DIR='${ROOT_DIR}'
    FORCE=false
    CC_INSTALL_DIR='/tmp/test-cc'
    source '${ROOT_DIR}/adapters/_adapter-lib.sh'
    source '${ROOT_DIR}/adapters/aider/adapter.sh'
    _adapter_validate && echo 'VALID'
" 2>&1)
assert_contains "aider adapter: passes validation" "$aider_validate" "VALID"

# ---- Test adapter variables ----
adapter_name=$(bash -c "
    err() { : ; }; info() { : ; }; warn() { : ; }
    SCRIPT_DIR='${ROOT_DIR}'; FORCE=false; CC_INSTALL_DIR='/tmp/test-cc'
    source '${ROOT_DIR}/adapters/_adapter-lib.sh'
    source '${ROOT_DIR}/adapters/aider/adapter.sh'
    echo \"\$_ADAPTER_NAME\"
" 2>&1)
assert_eq "aider adapter: _ADAPTER_NAME=aider" "aider" "$adapter_name"

install_dir=$(bash -c "
    err() { : ; }; info() { : ; }; warn() { : ; }
    SCRIPT_DIR='${ROOT_DIR}'; FORCE=false; CC_INSTALL_DIR='/tmp/test-cc'
    source '${ROOT_DIR}/adapters/_adapter-lib.sh'
    source '${ROOT_DIR}/adapters/aider/adapter.sh'
    echo \"\$_ADAPTER_INSTALL_DIR\"
" 2>&1)
assert_eq "aider adapter: _ADAPTER_INSTALL_DIR=.cognitive-core" ".cognitive-core" "$install_dir"

# ---- Test generate.py exists and is valid Python ----
assert_file_exists "aider: generate.py exists" "${ROOT_DIR}/adapters/aider/generate.py"

if command -v python3 &>/dev/null; then
    py_check=$(python3 -c "import py_compile; py_compile.compile('${ROOT_DIR}/adapters/aider/generate.py', doraise=True)" 2>&1) || true
    if [ -z "$py_check" ]; then
        _pass "aider: generate.py compiles without error"
    else
        _fail "aider: generate.py compiles without error" "$py_check"
    fi
else
    _skip "aider: generate.py compile check (python3 not available)"
fi

# ---- Test tool-map.yaml ----
assert_file_exists "aider: tool-map.yaml exists" "${ROOT_DIR}/adapters/aider/tool-map.yaml"
aider_toolmap=$(cat "${ROOT_DIR}/adapters/aider/tool-map.yaml")
assert_contains "aider tool-map: has adapter field" "$aider_toolmap" "adapter: aider"
assert_contains "aider tool-map: has capabilities" "$aider_toolmap" "capabilities:"
assert_contains "aider tool-map: has safety_approach" "$aider_toolmap" "safety_approach:"

# ---- Test CONVENTIONS.md template ----
assert_file_exists "aider: CONVENTIONS.md.tmpl exists" "${ROOT_DIR}/adapters/aider/templates/CONVENTIONS.md.tmpl"
tmpl=$(cat "${ROOT_DIR}/adapters/aider/templates/CONVENTIONS.md.tmpl")
assert_contains "template: has project placeholder" "$tmpl" "{{CC_PROJECT_NAME}}"
assert_contains "template: has safety rules placeholder" "$tmpl" "{{SAFETY_RULES}}"
assert_contains "template: has agent context placeholder" "$tmpl" "{{AGENT_CONTEXT}}"

# ---- Test full install with CC_PLATFORM=aider ----
test_dir=$(create_test_dir)
git -C "$test_dir" init --quiet 2>/dev/null

cat > "${test_dir}/cognitive-core.conf" << 'EOF'
#!/bin/false
CC_PROJECT_NAME="aider-test"
CC_PROJECT_DESCRIPTION="Test aider adapter"
CC_ORG="test-org"
CC_PLATFORM="aider"
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
CC_AIDER_MODEL="qwen2.5-coder:32b"
CC_AIDER_OLLAMA_BASE="http://localhost:11434"
CC_AIDER_EDIT_FORMAT="diff"
EOF

install_output=$(bash "${ROOT_DIR}/install.sh" "$test_dir" 2>&1) || {
    _fail "install with aider adapter: exited with error"
    echo "$install_output" | tail -20
    rm -rf "$test_dir"
    suite_end || true
    exit 1
}

# Verify .cognitive-core directory structure
assert_dir_exists "aider install: .cognitive-core/ created" "${test_dir}/.cognitive-core"
assert_dir_exists "aider install: .cognitive-core/agents/ created" "${test_dir}/.cognitive-core/agents"
assert_dir_exists "aider install: .cognitive-core/skills/ created" "${test_dir}/.cognitive-core/skills"
assert_dir_exists "aider install: .cognitive-core/hooks/ created" "${test_dir}/.cognitive-core/hooks"

# Verify agents were copied
assert_file_exists "aider install: project-coordinator.md" "${test_dir}/.cognitive-core/agents/project-coordinator.md"
assert_file_exists "aider install: code-standards-reviewer.md" "${test_dir}/.cognitive-core/agents/code-standards-reviewer.md"

# Verify hooks were copied (for convention extraction)
assert_file_exists "aider install: validate-bash.sh copied" "${test_dir}/.cognitive-core/hooks/validate-bash.sh"

# Verify Aider-specific output files
assert_file_exists "aider install: .aider.conf.yml generated" "${test_dir}/.aider.conf.yml"
assert_file_exists "aider install: CONVENTIONS.md generated" "${test_dir}/CONVENTIONS.md"
assert_file_exists "aider install: .aiderignore generated" "${test_dir}/.aiderignore"
assert_file_exists "aider install: cc-aider-start.sh generated" "${test_dir}/cc-aider-start.sh"
assert_file_executable "aider install: cc-aider-start.sh executable" "${test_dir}/cc-aider-start.sh"

# Verify CONVENTIONS.md contains safety rules
conventions=$(cat "${test_dir}/CONVENTIONS.md")
assert_contains "conventions: has safety section" "$conventions" "Safety Rules"
assert_contains "conventions: has rm -rf rule" "$conventions" "rm"
assert_contains "conventions: has force push rule" "$conventions" "force"
assert_contains "conventions: has git reset rule" "$conventions" "reset"

# Verify .aider.conf.yml content
aider_conf=$(cat "${test_dir}/.aider.conf.yml")
assert_contains "aider conf: has model" "$aider_conf" "ollama_chat/"
assert_contains "aider conf: has auto-lint" "$aider_conf" "auto-lint: true"
assert_contains "aider conf: has lint-cmd" "$aider_conf" "lint-cmd:"
assert_contains "aider conf: has CONVENTIONS.md in read" "$aider_conf" "CONVENTIONS.md"

# Verify .aiderignore content
aiderignore=$(cat "${test_dir}/.aiderignore")
assert_contains "aiderignore: has .env" "$aiderignore" ".env"
assert_contains "aiderignore: has .git/" "$aiderignore" ".git/"

# Verify version.json has platform=aider
version_json=$(cat "${test_dir}/.cognitive-core/cognitive-core/version.json")
assert_contains "version.json: platform=aider" "$version_json" '"aider"'

# Verify NO .claude directory was created
if [ -d "${test_dir}/.claude" ]; then
    _fail "aider install: should NOT create .claude/"
else
    _pass "aider install: no .claude/ directory (correct)"
fi

# Verify NO CLAUDE.md was created
if [ -f "${test_dir}/CLAUDE.md" ]; then
    _fail "aider install: should NOT create CLAUDE.md"
else
    _pass "aider install: no CLAUDE.md (correct — has CONVENTIONS.md instead)"
fi

rm -rf "$test_dir"

suite_end
