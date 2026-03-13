#!/bin/bash
# SPDX-License-Identifier: FSL-1.1-ALv2
# Build the cognitive-core Claude Code plugin from core/ sources
# Usage: bash build-plugin.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="${SCRIPT_DIR}/plugin"
CORE_DIR="${SCRIPT_DIR}/core"

info() { echo "[build-plugin] $*"; }
warn() { echo "[build-plugin] WARNING: $*" >&2; }

# Validate source directories exist
if [ ! -d "${CORE_DIR}/hooks" ] || [ ! -d "${CORE_DIR}/agents" ] || [ ! -d "${CORE_DIR}/skills" ]; then
    echo "ERROR: core/ directory structure not found. Run from repo root." >&2
    exit 1
fi

# Preserve static plugin files (manifest, hooks config)
info "Building plugin from core/ sources..."

# Clean dynamic content (hooks, agents, skills) but preserve static files
rm -rf "${PLUGIN_DIR}/scripts" "${PLUGIN_DIR}/agents" "${PLUGIN_DIR}/skills"
mkdir -p "${PLUGIN_DIR}/scripts" "${PLUGIN_DIR}/agents" "${PLUGIN_DIR}/skills"

# Ensure static structure exists
mkdir -p "${PLUGIN_DIR}/.claude-plugin" "${PLUGIN_DIR}/hooks"

# ---- Copy hook scripts ----
info "Copying hook scripts..."
cp "${CORE_DIR}/hooks/"*.sh "${PLUGIN_DIR}/scripts/"
chmod +x "${PLUGIN_DIR}/scripts/"*.sh

# Patch _lib.sh for dual-mode (plugin cache + legacy) path resolution
info "Patching _lib.sh for plugin mode..."
sed -i '' 's|^# Resolve project directory|# Resolve paths (dual-mode: plugin cache or legacy .claude/hooks/)|' \
    "${PLUGIN_DIR}/scripts/_lib.sh"
sed -i '' '/^CC_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE\[0\]}")\/\.\.\/.\./" && pwd)}"$/c\
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then\
    # Plugin mode: scripts live in plugin cache\
    SCRIPT_DIR="${CLAUDE_PLUGIN_ROOT}/scripts"\
    CC_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"\
else\
    # Legacy mode: scripts live in .claude/hooks/ within the project\
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" \&\& pwd)"\
    CC_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "${SCRIPT_DIR}/../.." \&\& pwd)}"\
fi' "${PLUGIN_DIR}/scripts/_lib.sh"

# ---- Copy agents ----
info "Copying agents..."
cp "${CORE_DIR}/agents/"*.md "${PLUGIN_DIR}/agents/"

# ---- Copy skills ----
info "Copying skills..."
cp -R "${CORE_DIR}/skills/"* "${PLUGIN_DIR}/skills/"

# ---- Copy LICENSE ----
if [ -f "${SCRIPT_DIR}/LICENSE" ]; then
    cp "${SCRIPT_DIR}/LICENSE" "${PLUGIN_DIR}/LICENSE"
fi

# ---- Validate ----
HOOK_COUNT=$(find "${PLUGIN_DIR}/scripts" -name "*.sh" -not -name "_lib.sh" | wc -l | tr -d ' ')
AGENT_COUNT=$(find "${PLUGIN_DIR}/agents" -name "*.md" | wc -l | tr -d ' ')
SKILL_COUNT=$(find "${PLUGIN_DIR}/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')

info "Plugin built successfully:"
info "  Hooks:  ${HOOK_COUNT} scripts"
info "  Agents: ${AGENT_COUNT} agents"
info "  Skills: ${SKILL_COUNT} skills"
info "  Output: ${PLUGIN_DIR}/"

# Syntax check all scripts
SYNTAX_ERRORS=0
for script in "${PLUGIN_DIR}/scripts/"*.sh; do
    if ! bash -n "$script" 2>/dev/null; then
        warn "Syntax error in $(basename "$script")"
        SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
    fi
done

if [ "$SYNTAX_ERRORS" -gt 0 ]; then
    warn "${SYNTAX_ERRORS} script(s) have syntax errors!"
    exit 1
fi

# Validate JSON files
for json_file in "${PLUGIN_DIR}/.claude-plugin/plugin.json" "${PLUGIN_DIR}/hooks/hooks.json"; do
    if [ -f "$json_file" ] && command -v jq &>/dev/null; then
        if ! jq empty "$json_file" 2>/dev/null; then
            warn "Invalid JSON: $(basename "$json_file")"
            exit 1
        fi
    fi
done

info "All validations passed."
