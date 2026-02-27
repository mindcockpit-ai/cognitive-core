#!/bin/bash
# cognitive-core adapter: Claude Code (identity adapter)
# This is the reference implementation — it passes through all operations
# unchanged, producing identical output to pre-adapter install.sh behavior.
#
# _adapter-lib.sh is sourced BEFORE this file by install.sh

_ADAPTER_NAME="claude-code"
_ADAPTER_INSTALL_DIR=".claude"

# ---- Required functions ----

_adapter_install_hook() {
    local source_path="$1" hook_name="$2"
    cp "$source_path" "${CC_INSTALL_DIR}/hooks/${hook_name}"
}

_adapter_install_agent() {
    local source_path="$1" agent_name="$2"
    cp "$source_path" "${CC_INSTALL_DIR}/agents/${agent_name}"
}

_adapter_install_skill() {
    local source_dir="$1" skill_name="$2"
    mkdir -p "${CC_INSTALL_DIR}/skills/${skill_name}"
    cp -R "${source_dir}/"* "${CC_INSTALL_DIR}/skills/${skill_name}/" 2>/dev/null || true
}

_adapter_generate_settings() {
    local project_dir="$1"
    local settings_file="${CC_INSTALL_DIR}/settings.json"

    if [ -f "${SCRIPT_DIR}/core/templates/settings.json.tmpl" ]; then
        sed \
            -e "s|{{CC_PROJECT_NAME}}|${CC_PROJECT_NAME:-project}|g" \
            -e "s|{{CC_LANGUAGE}}|${CC_LANGUAGE:-none}|g" \
            -e "s|{{CC_ARCHITECTURE}}|${CC_ARCHITECTURE:-none}|g" \
            -e "s|{{CC_MAIN_BRANCH}}|${CC_MAIN_BRANCH:-main}|g" \
            -e "s|{{CC_LINT_COMMAND}}|${CC_LINT_COMMAND:-echo no-lint}|g" \
            -e "s|{{CC_TEST_COMMAND}}|${CC_TEST_COMMAND:-echo no-tests}|g" \
            -e "s|{{CC_AGENT_TEAMS}}|${CC_AGENT_TEAMS:-false}|g" \
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
