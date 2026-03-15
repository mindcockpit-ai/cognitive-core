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

    # Check YAML frontmatter delimiters exist (avoid sed|grep pipe — SIGPIPE under pipefail)
    has_frontmatter=false
    if [ "$(grep -c '^---' "$skill_md")" -ge 2 ]; then
        has_frontmatter=true
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
    if [ "$(grep -c '^---' "$skill_md")" -ge 2 ]; then
        has_frontmatter=true
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

# Validate supported-languages field format when present
while IFS= read -r skill_md; do
    skill_name="$(basename "$(dirname "$skill_md")")"
    _sl_line=$(grep '^supported-languages:' "$skill_md" 2>/dev/null | head -1 || echo "")
    if [ -n "$_sl_line" ]; then
        _sl_value=$(echo "$_sl_line" | sed 's/supported-languages:[[:space:]]*//')
        if echo "$_sl_value" | grep -qE '^\[([a-zA-Z0-9_-]+(,[[:space:]]*[a-zA-Z0-9_-]+)*)?\]$'; then
            _pass "supported-languages format: ${skill_name}/SKILL.md"
        else
            _fail "supported-languages format: ${skill_name}/SKILL.md — invalid: ${_sl_value}"
        fi
    fi
done < <(find "${ROOT_DIR}/core/skills" "${ROOT_DIR}/language-packs" "${ROOT_DIR}/database-packs" -name "SKILL.md" -type f 2>/dev/null | sort)

suite_end
