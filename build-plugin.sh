#!/bin/bash
# SPDX-License-Identifier: FSL-1.1-ALv2
# Build the cognitive-core Claude Code plugin from core/ sources
# Usage: bash build-plugin.sh
#
# The dynamic content (scripts, agents, skills) is built in a staging
# directory, validated there, and only then swapped into plugin/. A failed
# build leaves plugin/ unchanged (#320). Hooks are copied verbatim: _lib.sh
# resolves plugin mode itself through CLAUDE_PLUGIN_ROOT, so nothing is patched.
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

info "Building plugin from core/ sources..."

# Stage next to plugin/ so the final swap is a rename on the same filesystem
STAGE="$(mktemp -d "${SCRIPT_DIR}/.plugin-build.XXXXXX")"
KEEP_STAGE=false
trap '[ "$KEEP_STAGE" = true ] || rm -rf "$STAGE"' EXIT
mkdir -p "${STAGE}/scripts" "${STAGE}/agents" "${STAGE}/skills"

# ---- Copy hook scripts ----
info "Copying hook scripts..."
cp "${CORE_DIR}/hooks/"*.sh "${STAGE}/scripts/"
chmod +x "${STAGE}/scripts/"*.sh

# ---- Copy agents ----
info "Copying agents..."
cp "${CORE_DIR}/agents/"*.md "${STAGE}/agents/"

# ---- Copy skills ----
info "Copying skills..."
cp -R "${CORE_DIR}/skills/"* "${STAGE}/skills/"

# ---- Validate the staged build ----
for d in scripts agents skills; do
    if [ -z "$(ls -A "${STAGE}/${d}")" ]; then
        warn "Staged ${d}/ is empty. plugin/ left unchanged."
        exit 1
    fi
done
SYNTAX_ERRORS=0
for script in "${STAGE}/scripts/"*.sh; do
    if ! bash -n "$script" 2>/dev/null; then
        warn "Syntax error in $(basename "$script")"
        SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
    fi
done
if [ "$SYNTAX_ERRORS" -gt 0 ]; then
    warn "${SYNTAX_ERRORS} script(s) have syntax errors! plugin/ left unchanged."
    exit 1
fi

# Static plugin files are maintained by hand; they must be valid JSON
for json_file in "${PLUGIN_DIR}/.claude-plugin/plugin.json" "${PLUGIN_DIR}/hooks/hooks.json"; do
    if [ -f "$json_file" ] && command -v jq &>/dev/null; then
        if ! jq empty "$json_file" 2>/dev/null; then
            warn "Invalid JSON: $(basename "$json_file"). plugin/ left unchanged."
            exit 1
        fi
    fi
done

# ---- Swap the staged content into plugin/ ----
# Current dirs move into the stage first, so a failed rename can be rolled
# back; the trap then removes the old content with the stage.
mkdir -p "${PLUGIN_DIR}/.claude-plugin" "${PLUGIN_DIR}/hooks" "${STAGE}/old"
rollback() {
    local d
    for d in scripts agents skills; do
        if [ -e "${STAGE}/old/${d}" ]; then
            rm -rf "${PLUGIN_DIR:?}/${d}"
            if ! mv "${STAGE}/old/${d}" "${PLUGIN_DIR}/${d}"; then
                KEEP_STAGE=true
                warn "Restore failed: previous plugin/${d} kept in ${STAGE}/old/${d}"
            fi
        fi
    done
    [ "$KEEP_STAGE" = true ] || warn "Swap failed. plugin/ restored."
    exit 1
}
for d in scripts agents skills; do
    if [ -e "${PLUGIN_DIR}/${d}" ] || [ -L "${PLUGIN_DIR}/${d}" ]; then
        mv "${PLUGIN_DIR}/${d}" "${STAGE}/old/${d}" || rollback
    fi
    mv "${STAGE}/${d}" "${PLUGIN_DIR}/${d}" || rollback
done

if [ -f "${SCRIPT_DIR}/LICENSE" ]; then
    cp "${SCRIPT_DIR}/LICENSE" "${PLUGIN_DIR}/LICENSE"
fi

HOOK_COUNT=$(find "${PLUGIN_DIR}/scripts" -name "*.sh" -not -name "_*.sh" | wc -l | tr -d ' ')
AGENT_COUNT=$(find "${PLUGIN_DIR}/agents" -name "*.md" | wc -l | tr -d ' ')
SKILL_COUNT=$(find "${PLUGIN_DIR}/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')

info "Plugin built successfully:"
info "  Hooks:  ${HOOK_COUNT} scripts"
info "  Agents: ${AGENT_COUNT} agents"
info "  Skills: ${SKILL_COUNT} skills"
info "  Output: ${PLUGIN_DIR}/"
info "All validations passed."
