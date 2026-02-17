#!/bin/bash
# Test suite: Validate SKILL.md required fields
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "02 — Skill Frontmatter Validation"

# Required: YAML frontmatter with description field
# Skills use frontmatter (---) with at minimum: name, description

while IFS= read -r skill_md; do
    rel="${skill_md#${ROOT_DIR}/}"
    skill_name="$(basename "$(dirname "$skill_md")")"

    # Check YAML frontmatter delimiters exist
    has_frontmatter=false
    if head -1 "$skill_md" | grep -q '^---'; then
        if sed -n '2,$p' "$skill_md" | grep -qm1 '^---'; then
            has_frontmatter=true
        fi
    fi

    missing=""
    if ! $has_frontmatter; then
        missing="${missing} frontmatter"
    fi
    if ! grep -q '^name:' "$skill_md"; then
        missing="${missing} name"
    fi
    if ! grep -q '^description:' "$skill_md"; then
        missing="${missing} description"
    fi

    if [ -z "$missing" ]; then
        _pass "frontmatter: ${skill_name}/SKILL.md"
    else
        _fail "frontmatter: ${skill_name}/SKILL.md — missing:${missing}"
    fi
done < <(find "${ROOT_DIR}/core/skills" -name "SKILL.md" -type f 2>/dev/null | sort)

# Also check language pack skills
while IFS= read -r skill_md; do
    rel="${skill_md#${ROOT_DIR}/}"
    skill_name="$(basename "$(dirname "$skill_md")")"

    has_frontmatter=false
    if head -1 "$skill_md" | grep -q '^---'; then
        if sed -n '2,$p' "$skill_md" | grep -qm1 '^---'; then
            has_frontmatter=true
        fi
    fi

    missing=""
    if ! $has_frontmatter; then
        missing="${missing} frontmatter"
    fi
    if ! grep -q '^name:' "$skill_md"; then
        missing="${missing} name"
    fi
    if ! grep -q '^description:' "$skill_md"; then
        missing="${missing} description"
    fi

    if [ -z "$missing" ]; then
        _pass "frontmatter: ${rel}"
    else
        _fail "frontmatter: ${rel} — missing:${missing}"
    fi
done < <(find "${ROOT_DIR}/language-packs" "${ROOT_DIR}/database-packs" -name "SKILL.md" -type f 2>/dev/null | sort)

suite_end
