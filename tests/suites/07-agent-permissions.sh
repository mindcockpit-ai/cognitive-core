#!/bin/bash
# Test suite: Verify agent frontmatter (disallowedTools, required fields)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "07 - Agent Permissions"

AGENTS_DIR="${ROOT_DIR}/core/agents"

# ---- Check required frontmatter fields ----
for agent_md in "${AGENTS_DIR}"/*.md; do
    [ -f "$agent_md" ] || continue
    agent_name=$(basename "$agent_md" .md)

    # Check frontmatter exists
    has_frontmatter=false
    # Single awk, no pipeline: grep -q exiting early made sed hit SIGPIPE,
    # which pipefail turned into a random "missing frontmatter"
    if awk 'NR == 1 && !/^---/ { exit 1 } NR > 1 && /^---/ { found = 1; exit } END { exit !found }' "$agent_md"; then
        has_frontmatter=true
    fi

    if $has_frontmatter; then
        # Check for name field
        if grep -q '^name:' "$agent_md"; then
            _pass "agent ${agent_name}: has name field"
        else
            _fail "agent ${agent_name}: missing name field"
        fi

        # Check for model field
        if grep -q '^model:' "$agent_md"; then
            _pass "agent ${agent_name}: has model field"
        else
            _fail "agent ${agent_name}: missing model field"
        fi
    else
        _fail "agent ${agent_name}: missing frontmatter"
    fi
done

# ---- Verify specific disallowedTools restrictions ----

# code-standards-reviewer should NOT have WebFetch/WebSearch
reviewer="${AGENTS_DIR}/code-standards-reviewer.md"
if [ -f "$reviewer" ]; then
    if grep -q 'WebFetch' "$reviewer" && grep -q 'disallowedTools' "$reviewer"; then
        _pass "reviewer: WebFetch in disallowedTools"
    else
        _fail "reviewer: should have WebFetch in disallowedTools"
    fi

    if grep -q 'WebSearch' "$reviewer" && grep -q 'disallowedTools' "$reviewer"; then
        _pass "reviewer: WebSearch in disallowedTools"
    else
        _fail "reviewer: should have WebSearch in disallowedTools"
    fi
else
    _skip "code-standards-reviewer.md not found"
fi

# research-analyst should NOT have Write/Edit
researcher="${AGENTS_DIR}/research-analyst.md"
if [ -f "$researcher" ]; then
    if grep -q 'Write' "$researcher" && grep -q 'disallowedTools' "$researcher"; then
        _pass "researcher: Write in disallowedTools"
    else
        _fail "researcher: should have Write in disallowedTools"
    fi

    if grep -q 'Edit' "$researcher" && grep -q 'disallowedTools' "$researcher"; then
        _pass "researcher: Edit in disallowedTools"
    else
        _fail "researcher: should have Edit in disallowedTools"
    fi
else
    _skip "research-analyst.md not found"
fi

suite_end
