#!/bin/bash
# Test suite: Adapter interface contract and Claude identity adapter
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "09 - Adapter Interface"

# ---- Test _adapter-lib.sh is sourceable ----
lib_output=$(bash -c "source '${ROOT_DIR}/adapters/_adapter-lib.sh'" 2>&1) || true
assert_eq "adapter-lib: sourceable without error" "" "$lib_output"

# ---- Test _adapter_validate detects missing functions ----
validate_output=$(bash -c "
    # Define minimal helpers needed by _adapter-lib.sh
    err() { printf '%s\n' \"\$*\" >&2; }
    info() { printf '%s\n' \"\$*\"; }
    source '${ROOT_DIR}/adapters/_adapter-lib.sh'
    _adapter_validate
" 2>&1) || true
assert_contains "adapter-lib: validates missing _ADAPTER_NAME" "$validate_output" "_ADAPTER_NAME"

# ---- Test Claude adapter passes validation ----
claude_validate=$(bash -c "
    err() { printf '%s\n' \"\$*\" >&2; }
    info() { printf '%s\n' \"\$*\"; }
    warn() { printf '%s\n' \"\$*\"; }
    SCRIPT_DIR='${ROOT_DIR}'
    FORCE=false
    source '${ROOT_DIR}/adapters/_adapter-lib.sh'
    source '${ROOT_DIR}/adapters/claude/adapter.sh'
    _adapter_validate && echo 'VALID'
" 2>&1)
assert_contains "claude adapter: passes validation" "$claude_validate" "VALID"

# ---- Test Claude adapter variables ----
adapter_name=$(bash -c "
    err() { : ; }; info() { : ; }; warn() { : ; }
    SCRIPT_DIR='${ROOT_DIR}'; FORCE=false
    source '${ROOT_DIR}/adapters/_adapter-lib.sh'
    source '${ROOT_DIR}/adapters/claude/adapter.sh'
    echo \"\$_ADAPTER_NAME\"
" 2>&1)
assert_eq "claude adapter: _ADAPTER_NAME=claude-code" "claude-code" "$adapter_name"

install_dir=$(bash -c "
    err() { : ; }; info() { : ; }; warn() { : ; }
    SCRIPT_DIR='${ROOT_DIR}'; FORCE=false
    source '${ROOT_DIR}/adapters/_adapter-lib.sh'
    source '${ROOT_DIR}/adapters/claude/adapter.sh'
    echo \"\$_ADAPTER_INSTALL_DIR\"
" 2>&1)
assert_eq "claude adapter: _ADAPTER_INSTALL_DIR=.claude" ".claude" "$install_dir"

# ---- Test tool-map.yaml exists and has required fields ----
assert_file_exists "claude adapter: tool-map.yaml exists" "${ROOT_DIR}/adapters/claude/tool-map.yaml"

tool_map=$(cat "${ROOT_DIR}/adapters/claude/tool-map.yaml")
assert_contains "tool-map: has adapter field" "$tool_map" "adapter:"
assert_contains "tool-map: has capabilities" "$tool_map" "capabilities:"
assert_contains "tool-map: has file_read" "$tool_map" "file_read:"
assert_contains "tool-map: has file_write" "$tool_map" "file_write:"
assert_contains "tool-map: has shell_execute" "$tool_map" "shell_execute:"
assert_contains "tool-map: has hooks section" "$tool_map" "hooks:"
assert_contains "tool-map: has skills section" "$tool_map" "skills:"
assert_contains "tool-map: has agents section" "$tool_map" "agents:"

# ---- Test adapter-interface.yaml exists and has required fields ----
assert_file_exists "adapter-interface.yaml exists" "${ROOT_DIR}/adapters/adapter-interface.yaml"

interface=$(cat "${ROOT_DIR}/adapters/adapter-interface.yaml")
assert_contains "interface: has required_functions" "$interface" "required_functions:"
assert_contains "interface: has required_variables" "$interface" "required_variables:"
assert_contains "interface: has capability_matrix" "$interface" "capability_matrix:"
assert_contains "interface: has _adapter_install_hook" "$interface" "_adapter_install_hook"
assert_contains "interface: has _adapter_install_agent" "$interface" "_adapter_install_agent"
assert_contains "interface: has _adapter_install_skill" "$interface" "_adapter_install_skill"
assert_contains "interface: has _adapter_generate_settings" "$interface" "_adapter_generate_settings"
assert_contains "interface: has _adapter_generate_project_readme" "$interface" "_adapter_generate_project_readme"

# Optional prune functions (#328): declared in the interface, defaulted in the lib
adapter_lib=$(cat "${ROOT_DIR}/adapters/_adapter-lib.sh")
for fn in _adapter_hook_is_wired _adapter_post_prune; do
    assert_contains "interface: has optional ${fn}" "$interface" "$fn"
    assert_contains "adapter lib: default ${fn}" "$adapter_lib" "${fn}() {"
done

# ---- Test MCP server install ships source files only (#398) ----
# Fixture framework: the real MCP server plus planted bytecode
mcp_root=$(create_test_dir)
mcp_src="${mcp_root}/fw/adapters/_shared/mcp-server"
mkdir -p "${mcp_root}/fw/adapters/_shared"
cp -R "${ROOT_DIR}/adapters/_shared/mcp-server" "$mcp_src"
mkdir -p "${mcp_src}/__pycache__" "${mcp_src}/tools/__pycache__"
touch "${mcp_src}/__pycache__/server.cpython-314.pyc" "${mcp_src}/tools/__pycache__/utils.cpython-314.pyc"
mcp_expected=$(cd "$mcp_src" && find . -type f ! -path '*/__pycache__/*' | sort)

# Each adapter's real post-install (generate.py is absent from the fixture, so it is skipped)
for adapter in claude vscode intellij; do
    proj="${mcp_root}/proj-${adapter}"
    mkdir -p "$proj"
    bash -c "
        info() { :; }; warn() { :; }
        SCRIPT_DIR='${mcp_root}/fw'; CC_INSTALL_DIR='${proj}/.cognitive-core'
        source '${ROOT_DIR}/adapters/_adapter-lib.sh'
        source '${ROOT_DIR}/adapters/${adapter}/adapter.sh'
        _adapter_post_install '${proj}'
    " >/dev/null 2>&1 || true
    assert_eq "mcp install (${adapter}): every source file, no bytecode" \
        "$mcp_expected" "$(cd "${proj}/.cognitive-core/mcp-server" 2>/dev/null && find . -type f | sort)"
done

mcp_lib() {
    mcp_rc=0
    mcp_out=$(bash -c "
        warn() { printf '%s\\n' \"\$*\"; }
        SCRIPT_DIR='$1'
        source '${ROOT_DIR}/adapters/_adapter-lib.sh'
        _adapter_install_mcp_server '$2'
    " 2>&1) || mcp_rc=$?
}
mcp_lib "${mcp_root}/none" "${mcp_root}/out-none"
assert_eq "mcp install: no MCP server in framework returns 1" "1" "$mcp_rc"
assert_eq "mcp install: no MCP server in framework creates nothing" "" "$(find "$mcp_root" -maxdepth 1 -name out-none)"

touch "${mcp_root}/blocker"
mcp_lib "${mcp_root}/fw" "${mcp_root}/blocker/mcp-server"
assert_eq "mcp install: failed copy returns 2" "2" "$mcp_rc"
assert_contains "mcp install: failed copy warns" "$mcp_out" "MCP server not installed"
rm -rf "$mcp_root"

# ---- Test install with claude adapter produces same structure ----
test_dir=$(create_test_dir)
git -C "$test_dir" init --quiet 2>/dev/null

cat > "${test_dir}/cognitive-core.conf" << 'EOF'
#!/bin/false
CC_PROJECT_NAME="adapter-test"
CC_PROJECT_DESCRIPTION="Test adapter"
CC_ORG="test-org"
CC_PLATFORM="claude"
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
EOF

install_output=$(bash "${ROOT_DIR}/install.sh" "$test_dir" 2>&1) || {
    _fail "install with claude adapter: exited with error"
    echo "$install_output" | tail -10
    rm -rf "$test_dir"
    suite_end || true
    exit 1
}

# Verify adapter-specific output
assert_dir_exists "claude adapter install: .claude/ created" "${test_dir}/.claude"
assert_file_exists "claude adapter install: settings.json" "${test_dir}/.claude/settings.json"
assert_file_exists "claude adapter install: CLAUDE.md" "${test_dir}/CLAUDE.md"

# Verify version.json has platform field
version_json=$(cat "${test_dir}/.claude/cognitive-core/version.json")
assert_contains "version.json: has platform field" "$version_json" '"platform"'
assert_contains "version.json: platform=claude" "$version_json" '"claude"'

# Verify install output mentions platform
assert_contains "install output: shows platform" "$install_output" "Platform:"

rm -rf "$test_dir"

# ---- Test _sed_escape_replacement (#237) ----
_esc_output=$(bash -c "
    source '${ROOT_DIR}/adapters/_adapter-lib.sh'
    _sed_escape_replacement 'cmd1 || cmd2 | grep foo'
" 2>&1)
assert_eq "sed escape: pipes escaped" 'cmd1 \|\| cmd2 \| grep foo' "$_esc_output"

_esc_output2=$(bash -c "
    source '${ROOT_DIR}/adapters/_adapter-lib.sh'
    _sed_escape_replacement 'simple-value'
" 2>&1)
assert_eq "sed escape: simple value unchanged" "simple-value" "$_esc_output2"

_esc_output3=$(bash -c "
    source '${ROOT_DIR}/adapters/_adapter-lib.sh'
    _sed_escape_replacement 'path/to/file & more'
" 2>&1)
assert_eq "sed escape: slash and ampersand escaped" 'path\/to\/file \& more' "$_esc_output3"

# Verify escaped value works in actual sed substitution
_sed_result=$(bash -c "
    source '${ROOT_DIR}/adapters/_adapter-lib.sh'
    VAL='./mvnw check -q 2>/dev/null || mvn check -q || echo no-lint'
    ESC=\$(_sed_escape_replacement \"\$VAL\")
    echo '{{PLACEHOLDER}}' | sed \"s|{{PLACEHOLDER}}|\${ESC}|g\"
" 2>&1)
assert_eq "sed escape: end-to-end substitution" \
    './mvnw check -q 2>/dev/null || mvn check -q || echo no-lint' \
    "$_sed_result"

suite_end
