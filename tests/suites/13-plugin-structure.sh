#!/bin/bash
# Test suite: Plugin structure validation
# Validates the plugin/ directory conforms to Claude Code plugin specification
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PLUGIN_DIR="${ROOT_DIR}/plugin"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "13 — Plugin Structure"

# ---- Existence checks ----

assert_file_exists "plugin.json exists" \
    "${PLUGIN_DIR}/.claude-plugin/plugin.json"

assert_file_exists "hooks.json exists" \
    "${PLUGIN_DIR}/hooks/hooks.json"

assert_dir_exists "scripts/ directory exists" \
    "${PLUGIN_DIR}/scripts"

assert_dir_exists "agents/ directory exists" \
    "${PLUGIN_DIR}/agents"

assert_dir_exists "skills/ directory exists" \
    "${PLUGIN_DIR}/skills"

# ---- plugin.json validation ----

if command -v jq &>/dev/null; then
    if jq empty "${PLUGIN_DIR}/.claude-plugin/plugin.json" 2>/dev/null; then
        _pass "plugin.json is valid JSON"
    else
        _fail "plugin.json is invalid JSON"
    fi

    # Required field: name
    name=$(jq -r '.name // ""' "${PLUGIN_DIR}/.claude-plugin/plugin.json")
    if [ -n "$name" ]; then
        _pass "plugin.json has name field: ${name}"
    else
        _fail "plugin.json missing required 'name' field"
    fi

    # Name must be kebab-case (no spaces, no uppercase)
    if echo "$name" | grep -qE '^[a-z0-9]([a-z0-9-]*[a-z0-9])?$'; then
        _pass "plugin name is kebab-case"
    else
        _fail "plugin name must be kebab-case: ${name}"
    fi

    # Version field present
    version=$(jq -r '.version // ""' "${PLUGIN_DIR}/.claude-plugin/plugin.json")
    if [ -n "$version" ]; then
        _pass "plugin.json has version: ${version}"
    else
        _skip "plugin.json has no version field (optional)"
    fi
else
    _skip "jq not installed — skipping plugin.json validation"
fi

# ---- hooks.json validation ----

if command -v jq &>/dev/null; then
    if jq empty "${PLUGIN_DIR}/hooks/hooks.json" 2>/dev/null; then
        _pass "hooks.json is valid JSON"
    else
        _fail "hooks.json is invalid JSON"
    fi

    # Check hook events are valid
    valid_events="SessionStart PreToolUse PostToolUse PostToolUseFailure PermissionRequest UserPromptSubmit Notification SubagentStart SubagentStop Stop TeammateIdle TaskCompleted PreCompact InstructionsLoaded ConfigChange WorktreeCreate WorktreeRemove SessionEnd"
    while IFS= read -r event; do
        if echo "$valid_events" | grep -qw "$event"; then
            _pass "hooks.json event '${event}' is valid"
        else
            _fail "hooks.json event '${event}' is not a valid Claude Code hook event"
        fi
    done < <(jq -r '.hooks | keys[]' "${PLUGIN_DIR}/hooks/hooks.json" 2>/dev/null)

    # Check all command paths use CLAUDE_PLUGIN_ROOT
    bad_paths=$(jq -r '.. | .command? // empty' "${PLUGIN_DIR}/hooks/hooks.json" | grep -v 'CLAUDE_PLUGIN_ROOT' || true)
    if [ -z "$bad_paths" ]; then
        _pass "all hook commands use \${CLAUDE_PLUGIN_ROOT}"
    else
        _fail "hook commands must use \${CLAUDE_PLUGIN_ROOT}, found: ${bad_paths}"
    fi

    # Count registered hooks
    hook_count=$(jq '[.. | .command? // empty] | length' "${PLUGIN_DIR}/hooks/hooks.json" 2>/dev/null)
    if [ "$hook_count" -gt 0 ]; then
        _pass "hooks.json registers ${hook_count} hook commands"
    else
        _fail "hooks.json has no hook commands registered"
    fi
else
    _skip "jq not installed — skipping hooks.json validation"
fi

# ---- Script checks ----

# _lib.sh must exist
assert_file_exists "_lib.sh shared library exists" \
    "${PLUGIN_DIR}/scripts/_lib.sh"

# All scripts must pass bash -n
for script in "${PLUGIN_DIR}/scripts/"*.sh; do
    [ -f "$script" ] || continue
    basename=$(basename "$script")
    if bash -n "$script" 2>/dev/null; then
        _pass "syntax check: ${basename}"
    else
        _fail "syntax error: ${basename}"
    fi
done

# All scripts must be executable
for script in "${PLUGIN_DIR}/scripts/"*.sh; do
    [ -f "$script" ] || continue
    basename=$(basename "$script")
    if [ -x "$script" ]; then
        _pass "executable: ${basename}"
    else
        _fail "not executable: ${basename}"
    fi
done

# _lib.sh must support plugin mode (CLAUDE_PLUGIN_ROOT check)
if grep -q 'CLAUDE_PLUGIN_ROOT' "${PLUGIN_DIR}/scripts/_lib.sh"; then
    _pass "_lib.sh supports plugin mode (CLAUDE_PLUGIN_ROOT)"
else
    _fail "_lib.sh missing CLAUDE_PLUGIN_ROOT support"
fi

# ---- Agent checks ----

agent_count=$(find "${PLUGIN_DIR}/agents" -name "*.md" | wc -l | tr -d ' ')
if [ "$agent_count" -gt 0 ]; then
    _pass "agents/ contains ${agent_count} agent definitions"
else
    _fail "agents/ is empty"
fi

# Check agents have frontmatter
for agent in "${PLUGIN_DIR}/agents/"*.md; do
    [ -f "$agent" ] || continue
    basename=$(basename "$agent")
    if head -1 "$agent" | grep -q '^---$'; then
        _pass "agent frontmatter: ${basename}"
    else
        _fail "agent missing frontmatter: ${basename}"
    fi
done

# ---- Skill checks ----

skill_count=$(find "${PLUGIN_DIR}/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
if [ "$skill_count" -gt 0 ]; then
    _pass "skills/ contains ${skill_count} skill directories"
else
    _fail "skills/ is empty"
fi

# Check each skill has SKILL.md with frontmatter
for skill_dir in "${PLUGIN_DIR}/skills/"*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    skill_file="${skill_dir}SKILL.md"
    if [ -f "$skill_file" ]; then
        _pass "SKILL.md exists: ${skill_name}"
        if head -1 "$skill_file" | grep -q '^---$'; then
            _pass "skill frontmatter: ${skill_name}"
        else
            _fail "skill missing frontmatter: ${skill_name}"
        fi
    else
        _fail "SKILL.md missing: ${skill_name}"
    fi
done

# ---- Structure rule: .claude-plugin/ must contain only plugin.json ----

extra_files=$(find "${PLUGIN_DIR}/.claude-plugin" -type f ! -name "plugin.json" | wc -l | tr -d ' ')
if [ "$extra_files" -eq 0 ]; then
    _pass ".claude-plugin/ contains only plugin.json"
else
    _fail ".claude-plugin/ must contain only plugin.json (found ${extra_files} extra files)"
fi

# ---- License check ----

if [ -f "${PLUGIN_DIR}/LICENSE" ]; then
    _pass "LICENSE file present"
else
    _skip "LICENSE file not present (optional)"
fi

# ---- Component parity check (plugin vs core) ----

core_agents=$(find "${ROOT_DIR}/core/agents" -name "*.md" | wc -l | tr -d ' ')
plugin_agents=$(find "${PLUGIN_DIR}/agents" -name "*.md" | wc -l | tr -d ' ')
if [ "$plugin_agents" -ge "$core_agents" ]; then
    _pass "agent parity: plugin(${plugin_agents}) >= core(${core_agents})"
else
    _fail "agent parity: plugin(${plugin_agents}) < core(${core_agents}) — missing agents"
fi

core_skills=$(find "${ROOT_DIR}/core/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
plugin_skills=$(find "${PLUGIN_DIR}/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
if [ "$plugin_skills" -ge "$core_skills" ]; then
    _pass "skill parity: plugin(${plugin_skills}) >= core(${core_skills})"
else
    _fail "skill parity: plugin(${plugin_skills}) < core(${core_skills}) — missing skills"
fi

core_hooks=$(find "${ROOT_DIR}/core/hooks" -name "*.sh" -not -name "_*.sh" | wc -l | tr -d ' ')
plugin_hooks=$(find "${PLUGIN_DIR}/scripts" -name "*.sh" -not -name "_*.sh" | wc -l | tr -d ' ')
if [ "$plugin_hooks" -ge "$core_hooks" ]; then
    _pass "hook parity: plugin(${plugin_hooks}) >= core(${core_hooks})"
else
    _fail "hook parity: plugin(${plugin_hooks}) < core(${core_hooks}) — missing hooks"
fi

suite_end
