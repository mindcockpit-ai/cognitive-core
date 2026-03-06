#!/bin/bash
# cognitive-core adapter: IntelliJ + Local LLM
# Translates cognitive-core components into IntelliJ-compatible configuration.
#
# Three integration layers:
#   Layer 1: Convention file (DEVOXXGENIE.md) — works with any LLM plugin
#   Layer 2: MCP server (cc-mcp-server) — DevoxxGenie, Continue.dev, Cline
#   Layer 3: ACP agent (future) — JetBrains 2025.3+ native
#
# - Hooks → DEVOXXGENIE.md rules (convention-based safety)
# - Agents → .cognitive-core/agents/ (read-only context)
# - Skills → .cognitive-core/skills/ (read-only context)
# - Settings → .devoxxgenie.yaml (plugin config)
# - Project readme → DEVOXXGENIE.md (context file)
#
# _adapter-lib.sh is sourced BEFORE this file by install.sh

_ADAPTER_NAME="intellij"
_ADAPTER_INSTALL_DIR=".cognitive-core"

# Internal: collect hooks for later convention extraction
_INTELLIJ_QUEUED_HOOKS=""

# ---- Required functions ----

_adapter_install_hook() {
    local source_path="$1" hook_name="$2"
    # Copy to .cognitive-core/hooks/ for reference and convention extraction
    mkdir -p "${CC_INSTALL_DIR}/hooks"
    cp "$source_path" "${CC_INSTALL_DIR}/hooks/${hook_name}"
    # Queue for convention extraction during post-install
    _INTELLIJ_QUEUED_HOOKS="${_INTELLIJ_QUEUED_HOOKS} ${hook_name}"
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
    local settings_file="${project_dir}/.devoxxgenie.yaml"
    local generate_py="${SCRIPT_DIR}/adapters/intellij/generate.py"

    if [ -f "$generate_py" ] && command -v python3 &>/dev/null; then
        python3 "$generate_py" \
            --mode settings \
            --project-dir "$project_dir" \
            --install-dir "$CC_INSTALL_DIR" \
            --config-file "${CONF_FILE:-}" \
            2>&1
        info "Generated .devoxxgenie.yaml via generate.py"
    else
        # Fallback: generate minimal .devoxxgenie.yaml directly
        cat > "$settings_file" << SETTINGSEOF
# cognitive-core generated IntelliJ / DevoxxGenie configuration
# Platform: intellij + local LLM
# Project: ${CC_PROJECT_NAME:-project}

# LLM provider configuration (adjust for your setup)
provider: ollama
model: ${CC_INTELLIJ_MODEL:-qwen2.5-coder:32b}
ollama_url: ${CC_INTELLIJ_OLLAMA_BASE:-http://localhost:11434}

# Context files (always loaded)
context_files:
  - DEVOXXGENIE.md

# Lint and test commands
lint_command: ${CC_LINT_COMMAND:-echo no-lint}
test_command: ${CC_TEST_COMMAND:-echo no-tests}

# MCP server (Layer 2 — enable if your plugin supports MCP)
mcp_server:
  enabled: false
  command: python3
  args:
    - .cognitive-core/mcp-server/server.py
  transport: stdio
SETTINGSEOF

        # Add agent docs as context
        if [ -d "${CC_INSTALL_DIR}/agents" ]; then
            for agent_file in "${CC_INSTALL_DIR}/agents/"*.md; do
                if [ -f "$agent_file" ]; then
                    local rel_path
                    rel_path=$(python3 -c "import os; print(os.path.relpath('$agent_file', '$project_dir'))" 2>/dev/null || echo "$agent_file")
                    echo "  - ${rel_path}" >> "$settings_file"
                fi
            done
        fi

        info "Generated .devoxxgenie.yaml (fallback mode)."
    fi
}

_adapter_generate_project_readme() {
    local project_dir="$1"
    local conventions_file="${project_dir}/DEVOXXGENIE.md"
    local generate_py="${SCRIPT_DIR}/adapters/intellij/generate.py"

    if [ -f "$generate_py" ] && command -v python3 &>/dev/null; then
        python3 "$generate_py" \
            --mode conventions \
            --project-dir "$project_dir" \
            --install-dir "$CC_INSTALL_DIR" \
            --config-file "${CONF_FILE:-}" \
            2>&1
        info "Generated DEVOXXGENIE.md via generate.py"
    else
        # Fallback: generate basic DEVOXXGENIE.md
        cat > "$conventions_file" << CONVEOF
# Project Conventions — ${CC_PROJECT_NAME:-project}

## Project Identity
- **Project**: ${CC_PROJECT_NAME:-project}
- **Language**: ${CC_LANGUAGE:-unknown}
- **Architecture**: ${CC_ARCHITECTURE:-none}
- **Database**: ${CC_DATABASE:-none}

## Code Standards
- Follow ${CC_LANGUAGE:-the project} community best practices
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

## MCP Server
If your IDE plugin supports MCP (Model Context Protocol), you can enable the
cognitive-core MCP server for programmatic access to lint, security validation,
and project information. See \`.cognitive-core/mcp-server/\` for details.
CONVEOF
        info "Generated DEVOXXGENIE.md (fallback mode)."
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
    mkdir -p "${install_dir}/mcp-server/tools"
    info "Created .cognitive-core/ directory tree (with MCP server)."
}

_adapter_post_install() {
    local project_dir="$1"
    local generate_py="${SCRIPT_DIR}/adapters/intellij/generate.py"

    # Install MCP server files
    local mcp_src="${SCRIPT_DIR}/adapters/intellij/mcp-server"
    local mcp_dst="${CC_INSTALL_DIR}/mcp-server"
    if [ -d "$mcp_src" ]; then
        cp -R "${mcp_src}/"* "${mcp_dst}/" 2>/dev/null || true
        info "Installed MCP server to .cognitive-core/mcp-server/"
    fi

    if [ -f "$generate_py" ] && command -v python3 &>/dev/null; then
        # Generate MCP config for IDE
        python3 "$generate_py" \
            --mode mcp-config \
            --project-dir "$project_dir" \
            --install-dir "$CC_INSTALL_DIR" \
            --config-file "${CONF_FILE:-}" \
            2>&1
        info "Generated MCP configuration"
    fi
}
