#!/bin/bash
# cognitive-core adapter: Aider + Ollama
# Translates cognitive-core components into Aider-compatible configuration.
#
# - Hooks → CONVENTIONS.md rules (convention-based safety)
# - Agents → .cognitive-core/agents/ (read-only context)
# - Skills → .cognitive-core/skills/ (read-only context)
# - Settings → .aider.conf.yml
# - Project readme → CONVENTIONS.md
#
# _adapter-lib.sh is sourced BEFORE this file by install.sh

_ADAPTER_NAME="aider"
_ADAPTER_INSTALL_DIR=".cognitive-core"

# Internal: collect hooks for later convention extraction
_AIDER_QUEUED_HOOKS=""

# ---- Required functions ----

_adapter_install_hook() {
    local source_path="$1" hook_name="$2"
    # Copy to .cognitive-core/hooks/ for reference and convention extraction
    mkdir -p "${CC_INSTALL_DIR}/hooks"
    cp "$source_path" "${CC_INSTALL_DIR}/hooks/${hook_name}"
    # Queue for convention extraction during post-install
    _AIDER_QUEUED_HOOKS="${_AIDER_QUEUED_HOOKS} ${hook_name}"
}

_adapter_install_agent() {
    local source_path="$1" agent_name="$2"
    mkdir -p "${CC_INSTALL_DIR}/agents"
    cp "$source_path" "${CC_INSTALL_DIR}/agents/${agent_name}"
}

_adapter_install_skill() {
    local source_dir="$1" skill_name="$2"
    mkdir -p "${CC_INSTALL_DIR}/skills/${skill_name}"
    cp -R "${source_dir}/"* "${CC_INSTALL_DIR}/skills/${skill_name}/" 2>/dev/null || true
}

_adapter_generate_settings() {
    local project_dir="$1"
    local conf_file="${project_dir}/.aider.conf.yml"
    local generate_py="${SCRIPT_DIR}/adapters/aider/generate.py"

    if [ -f "$generate_py" ] && command -v python3 &>/dev/null; then
        python3 "$generate_py" \
            --mode settings \
            --project-dir "$project_dir" \
            --install-dir "$CC_INSTALL_DIR" \
            --config-file "${CONF_FILE:-}" \
            2>&1
        info "Generated .aider.conf.yml via generate.py"
    else
        # Fallback: generate minimal .aider.conf.yml directly
        cat > "$conf_file" << AIDEREOF
# cognitive-core generated Aider configuration
# Platform: aider + ollama
# Project: ${CC_PROJECT_NAME:-project}

# Model configuration (adjust for your Ollama setup)
model: ollama_chat/${CC_AIDER_MODEL:-qwen2.5-coder:32b}
editor-model: ollama_chat/${CC_AIDER_MODEL:-qwen2.5-coder:32b}

# Edit format
edit-format: ${CC_AIDER_EDIT_FORMAT:-diff}

# Auto-lint after edits
auto-lint: true
lint-cmd: ${CC_LINT_COMMAND:-echo no-lint}

# Auto-test after edits
auto-test: false
test-cmd: ${CC_TEST_COMMAND:-echo no-tests}

# Read-only context files (always in context)
read:
  - CONVENTIONS.md
AIDEREOF

        # Add agent docs as read-only context
        if [ -d "${CC_INSTALL_DIR}/agents" ]; then
            for agent_file in "${CC_INSTALL_DIR}/agents/"*.md; do
                if [ -f "$agent_file" ]; then
                    local rel_path
                    rel_path=$(python3 -c "import os; print(os.path.relpath('$agent_file', '$project_dir'))" 2>/dev/null || echo "$agent_file")
                    echo "  - ${rel_path}" >> "$conf_file"
                fi
            done
        fi

        info "Generated .aider.conf.yml (fallback mode)."
    fi
}

_adapter_generate_project_readme() {
    local project_dir="$1"
    local conventions_file="${project_dir}/CONVENTIONS.md"
    local generate_py="${SCRIPT_DIR}/adapters/aider/generate.py"

    if [ -f "$generate_py" ] && command -v python3 &>/dev/null; then
        python3 "$generate_py" \
            --mode conventions \
            --project-dir "$project_dir" \
            --install-dir "$CC_INSTALL_DIR" \
            --config-file "${CONF_FILE:-}" \
            2>&1
        info "Generated CONVENTIONS.md via generate.py"
    else
        # Fallback: generate basic CONVENTIONS.md
        cat > "$conventions_file" << CONVEOF
# Project Conventions — ${CC_PROJECT_NAME:-project}

## Project Identity
- **Project**: ${CC_PROJECT_NAME:-project}
- **Language**: ${CC_LANGUAGE:-unknown}
- **Architecture**: ${CC_ARCHITECTURE:-none}
- **Database**: ${CC_DATABASE:-none}

## Code Standards
- Follow ${CC_LANGUAGE:-the project's} community best practices
- Run lint before every commit: \`${CC_LINT_COMMAND:-echo no-lint}\`
- Run tests: \`${CC_TEST_COMMAND:-echo no-tests}\`
- All new code must have tests

## Git Conventions
- Main branch: \`${CC_MAIN_BRANCH:-main}\`
- Commit format: \`type(scope): subject\` (${CC_COMMIT_FORMAT:-conventional} format)
- Scopes: ${CC_COMMIT_SCOPES:-core}
- NO AI/tool references in commit messages

## Safety Rules (CRITICAL)
These rules MUST be followed at all times:

1. NEVER execute: rm -rf targeting /, /etc, /usr, /var, /home, /System, /Library
2. NEVER execute: git push --force to main/master
3. NEVER execute: git reset --hard
4. NEVER execute: DROP TABLE or TRUNCATE TABLE
5. NEVER execute: DELETE FROM without WHERE clause
6. NEVER execute: rm .git
7. NEVER execute: chmod 777
8. NEVER execute: git clean -f (without -n dry-run)
9. NEVER pipe curl/wget output to sh/bash (supply chain risk)
10. NEVER use base64 -d | sh (encoded command execution)
11. NEVER use eval with command substitution
12. NEVER pipe environment variables (env |) to external commands

## Architecture
Pattern: **${CC_ARCHITECTURE:-none}**
Source root: \`${CC_SRC_ROOT:-src}\`
Test root: \`${CC_TEST_ROOT:-tests}\`

## Agent Context
Agent documentation is available in \`.cognitive-core/agents/\` for reference.
These describe specialist roles — use their guidance when working in their domains.
CONVEOF
        info "Generated CONVENTIONS.md (fallback mode)."
    fi
}

# ---- Optional functions ----

_adapter_install_dir_structure() {
    local project_dir="$1"
    local install_dir="${project_dir}/${_ADAPTER_INSTALL_DIR}"
    mkdir -p "${install_dir}/hooks"
    mkdir -p "${install_dir}/agents"
    mkdir -p "${install_dir}/skills"
    mkdir -p "${install_dir}/cognitive-core"
    info "Created .cognitive-core/ directory tree."
}

_adapter_post_install() {
    local project_dir="$1"
    local generate_py="${SCRIPT_DIR}/adapters/aider/generate.py"

    if [ -f "$generate_py" ] && command -v python3 &>/dev/null; then
        # Generate .aiderignore
        python3 "$generate_py" \
            --mode ignore \
            --project-dir "$project_dir" \
            --install-dir "$CC_INSTALL_DIR" \
            --config-file "${CONF_FILE:-}" \
            2>&1
        info "Generated .aiderignore"

        # Generate launcher script
        python3 "$generate_py" \
            --mode launcher \
            --project-dir "$project_dir" \
            --install-dir "$CC_INSTALL_DIR" \
            --config-file "${CONF_FILE:-}" \
            2>&1
        chmod +x "${project_dir}/cc-aider-start.sh"
        info "Generated cc-aider-start.sh launcher"
    else
        # Fallback: generate minimal files
        _aider_generate_ignore "$project_dir"
        _aider_generate_launcher "$project_dir"
    fi
}

# ---- Fallback generators (when Python not available) ----

_aider_generate_ignore() {
    local project_dir="$1"
    cat > "${project_dir}/.aiderignore" << 'IGNEOF'
# cognitive-core generated .aiderignore
# Prevents Aider from reading sensitive files

# Secrets and credentials
.env
.env.*
*.pem
*.key
credentials.json
secrets.yaml

# Runtime logs
.cognitive-core/cognitive-core/security.log

# Build artifacts
node_modules/
__pycache__/
*.pyc
.git/
IGNEOF
    info "Generated .aiderignore (fallback mode)."
}

_aider_generate_launcher() {
    local project_dir="$1"
    cat > "${project_dir}/cc-aider-start.sh" << LAUNCHEOF
#!/bin/bash
# cognitive-core Aider launcher
# Sets up environment and launches Aider with correct configuration
set -euo pipefail

SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"

# Environment setup (from cognitive-core.conf)
if [ -f "\${SCRIPT_DIR}/cognitive-core.conf" ]; then
    # shellcheck disable=SC1091
    source "\${SCRIPT_DIR}/cognitive-core.conf"
fi

# Set Ollama base URL if configured
export OLLAMA_API_BASE="\${CC_AIDER_OLLAMA_BASE:-http://localhost:11434}"

echo "cognitive-core Aider launcher"
echo "Model: \${CC_AIDER_MODEL:-qwen2.5-coder:32b}"
echo "Ollama: \${OLLAMA_API_BASE}"
echo ""

# Launch Aider
exec aider "\$@"
LAUNCHEOF
    chmod +x "${project_dir}/cc-aider-start.sh"
    info "Generated cc-aider-start.sh (fallback mode)."
}
