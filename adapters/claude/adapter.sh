#!/bin/bash
# cognitive-core adapter: Claude Code (identity adapter)
# This is the reference implementation - it passes through all operations
# unchanged, producing identical output to pre-adapter install.sh behavior.
#
# _adapter-lib.sh is sourced BEFORE this file by install.sh

_ADAPTER_NAME="claude-code"
_ADAPTER_INSTALL_DIR=".claude"

# ---- Platform-specific functions (install_hook/agent use lib defaults) ----

_adapter_install_skill() {
    local source_dir="$1" skill_name="$2"
    mkdir -p "${CC_INSTALL_DIR}/skills/${skill_name}"
    cp -R "${source_dir}/"* "${CC_INSTALL_DIR}/skills/${skill_name}/" 2>/dev/null || true

    # Claude Code auto-discovers user-invocable skills from SKILL.md frontmatter.
    # Do NOT create .claude/commands/ stubs - that causes duplicate entries.
    # Clean up any orphaned command stubs from previous installations.
    local orphan="${CC_INSTALL_DIR}/commands/${skill_name}.md"
    if [ -f "$orphan" ]; then
        rm -f "$orphan"
    fi
}

# A hook referenced in settings.json or settings.local.json must not be
# pruned, otherwise every matching tool call fails with "No such file".
_adapter_hook_is_wired() {
    local settings
    for settings in "${1}/${_ADAPTER_INSTALL_DIR}/settings.json" "${1}/${_ADAPTER_INSTALL_DIR}/settings.local.json"; do
        [ -f "$settings" ] && grep -qF "hooks/${2}" "$settings" && return 0
    done
    return 1
}

_adapter_generate_settings() {
    local project_dir="$1"
    local settings_file="${CC_INSTALL_DIR}/settings.json"

    if [ -f "${SCRIPT_DIR}/core/templates/settings.json.tmpl" ]; then
        local _esc_name _esc_lang _esc_arch _esc_branch _esc_lint _esc_test _esc_teams
        _esc_name=$(_sed_escape_replacement "${CC_PROJECT_NAME:-project}")
        _esc_lang=$(_sed_escape_replacement "${CC_LANGUAGE:-none}")
        _esc_arch=$(_sed_escape_replacement "${CC_ARCHITECTURE:-none}")
        _esc_branch=$(_sed_escape_replacement "${CC_MAIN_BRANCH:-main}")
        _esc_lint=$(_sed_escape_replacement "${CC_LINT_COMMAND:-echo no-lint}")
        _esc_test=$(_sed_escape_replacement "${CC_TEST_COMMAND:-echo no-tests}")
        _esc_teams=$(_sed_escape_replacement "${CC_AGENT_TEAMS:-false}")
        sed \
            -e "s|{{CC_PROJECT_NAME}}|${_esc_name}|g" \
            -e "s|{{CC_LANGUAGE}}|${_esc_lang}|g" \
            -e "s|{{CC_ARCHITECTURE}}|${_esc_arch}|g" \
            -e "s|{{CC_MAIN_BRANCH}}|${_esc_branch}|g" \
            -e "s|{{CC_LINT_COMMAND}}|${_esc_lint}|g" \
            -e "s|{{CC_TEST_COMMAND}}|${_esc_test}|g" \
            -e "s|{{CC_AGENT_TEAMS}}|${_esc_teams}|g" \
            "${SCRIPT_DIR}/core/templates/settings.json.tmpl" > "$settings_file"
        info "Generated settings.json from template."
    else
        cat > "$settings_file" << SETEOF
{
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(${CC_LINT_COMMAND:-echo no-lint})",
      "Bash(${CC_TEST_COMMAND:-echo no-tests})"
    ],
    "deny": []
  },
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          ".claude/hooks/setup-env.sh"
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          ".claude/hooks/validate-bash.sh"
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          ".claude/hooks/post-edit-lint.sh"
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "compact",
        "hooks": [
          ".claude/hooks/compact-reminder.sh"
        ]
      }
    ]
  }
}
SETEOF
        info "Generated settings.json (no template found, used defaults)."
    fi
}

_adapter_generate_project_readme() {
    local project_dir="$1"
    local claudemd="${project_dir}/CLAUDE.md"

    if [ -f "$claudemd" ] && [ "${FORCE:-false}" != "true" ]; then
        info "CLAUDE.md already exists (preserved)."
        return 0
    fi

    cat > "$claudemd" << 'CLAUDEEOF'
# Project Development Guide

## Quick Reference

| Item | Value |
|------|-------|
CLAUDEEOF

    cat >> "$claudemd" << CLAUDEEOF
| **Project** | ${CC_PROJECT_NAME} |
| **Language** | ${CC_LANGUAGE} |
| **Architecture** | ${CC_ARCHITECTURE} |
| **Database** | ${CC_DATABASE} |
| **Main Branch** | ${CC_MAIN_BRANCH} |
| **Test Command** | \`${CC_TEST_COMMAND}\` |
| **Lint Command** | \`${CC_LINT_COMMAND}\` |

## Architecture

Pattern: **${CC_ARCHITECTURE}**
Source root: \`${CC_SRC_ROOT}\`
Test root: \`${CC_TEST_ROOT}\`

<!-- TODO: Document your architecture layers and patterns here -->

## Code Standards

- Follow ${CC_LANGUAGE} community best practices
- Run lint before every commit
- All new code must have tests
- Git commits: \`type(scope): subject\` (${CC_COMMIT_FORMAT} format)
- NO AI/tool references in commit messages

## Key Rules

<!-- TODO: Add your project's critical rules here -->
<!-- These survive context compaction and are always visible -->

1. Follow the architecture pattern defined above
2. Use parameterized queries for all database operations
3. Run lint before every commit

## Agents

See \`.claude/AGENTS_README.md\` for the agent team documentation.

## Development Workflow

1. Check current branch and status
2. Implement changes following architecture pattern
3. Run tests: \`${CC_TEST_COMMAND}\`
4. Run lint: \`${CC_LINT_COMMAND}\`
5. Commit with conventional format
CLAUDEEOF

    # Append @import statements for installed rule files
    local rules_dir="${project_dir}/.claude/rules"
    if [ -d "$rules_dir" ]; then
        local has_rules=false
        for rule_file in "${rules_dir}/"*.md; do
            [ -f "$rule_file" ] || continue
            has_rules=true
            break
        done
        if [ "$has_rules" = true ]; then
            cat >> "$claudemd" << 'IMPORTEOF'

## Imported Rules

IMPORTEOF
            for rule_file in "${rules_dir}/"*.md; do
                [ -f "$rule_file" ] || continue
                echo "@import .claude/rules/$(basename "$rule_file")" >> "$claudemd"
            done
        fi
    fi

    info "Generated CLAUDE.md scaffold."
}

# ---- Optional functions ----

_adapter_install_dir_structure() {
    local project_dir="$1"
    local install_dir="${project_dir}/${_ADAPTER_INSTALL_DIR}"
    mkdir -p "${install_dir}/hooks"
    mkdir -p "${install_dir}/agents"
    mkdir -p "${install_dir}/skills"
    mkdir -p "${install_dir}/cognitive-core"
    info "Created .claude/ directory tree."
}

_adapter_post_install() {
    local project_dir="$1"

    # Install shared MCP server if available
    if _adapter_install_mcp_server "${project_dir}/.cognitive-core/mcp-server"; then
        info "Installed cognitive-core MCP server."
    fi

    # Generate .mcp.json for Claude Code MCP integration
    local mcp_json="${project_dir}/.mcp.json"
    if [ ! -f "$mcp_json" ] || [ "${FORCE:-false}" = "true" ]; then
        cat > "$mcp_json" << 'MCPEOF'
{
  "mcpServers": {
    "cognitive-core": {
      "command": "python3",
      "args": [".cognitive-core/mcp-server/server.py"],
      "env": {
        "CC_PROJECT_DIR": ".",
        "CC_INSTALL_DIR": ".cognitive-core"
      }
    }
  }
}
MCPEOF
        info "Generated .mcp.json (cognitive-core MCP server registered)."
    else
        info ".mcp.json already exists (preserved)."
    fi
}
