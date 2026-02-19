#!/bin/bash
# Test suite: Validate workspace-monitor skill
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "08 — Workspace Monitor Skill"

SKILL_DIR="${ROOT_DIR}/core/skills/workspace-monitor"
SKILL_MD="${SKILL_DIR}/SKILL.md"
ERROR_PATTERNS="${SKILL_DIR}/references/error-patterns.md"

# ---- SKILL.md existence and structure ----

assert_file_exists "SKILL.md exists" "$SKILL_MD"
assert_file_exists "error-patterns.md exists" "$ERROR_PATTERNS"
assert_dir_exists "references/ directory exists" "${SKILL_DIR}/references"

# ---- Frontmatter validation ----

has_frontmatter=false
if head -1 "$SKILL_MD" | grep -q '^---'; then
    if sed -n '2,$p' "$SKILL_MD" | grep -qm1 '^---'; then
        has_frontmatter=true
    fi
fi

if $has_frontmatter; then
    _pass "SKILL.md has YAML frontmatter"
else
    _fail "SKILL.md missing YAML frontmatter"
fi

# Required frontmatter fields
if grep -q '^name:' "$SKILL_MD"; then
    _pass "frontmatter: name field present"
else
    _fail "frontmatter: name field missing"
fi

if grep -q '^description:' "$SKILL_MD"; then
    _pass "frontmatter: description field present"
else
    _fail "frontmatter: description field missing"
fi

if grep -q '^user-invocable:' "$SKILL_MD"; then
    _pass "frontmatter: user-invocable field present"
else
    _fail "frontmatter: user-invocable field missing"
fi

if grep -q '^allowed-tools:' "$SKILL_MD"; then
    _pass "frontmatter: allowed-tools field present"
else
    _fail "frontmatter: allowed-tools field missing"
fi

# ---- No hardcoded absolute paths ----

if grep -qE '/Users/|/home/[a-z]' "$SKILL_MD" 2>/dev/null; then
    hardcoded_paths=$(grep -cE '/Users/|/home/[a-z]' "$SKILL_MD" 2>/dev/null || true)
    _fail "SKILL.md contains ${hardcoded_paths} hardcoded absolute path(s)"
else
    _pass "SKILL.md has no hardcoded absolute paths"
fi

if grep -qE '/Users/|/home/[a-z]' "$ERROR_PATTERNS" 2>/dev/null; then
    hardcoded_ref_paths=$(grep -cE '/Users/|/home/[a-z]' "$ERROR_PATTERNS" 2>/dev/null || true)
    _fail "error-patterns.md contains ${hardcoded_ref_paths} hardcoded absolute path(s)"
else
    _pass "error-patterns.md has no hardcoded absolute paths"
fi

# ---- CC_* variable usage ----

if grep -q 'CC_MONITOR_LOG_DIRS' "$SKILL_MD"; then
    _pass "SKILL.md references CC_MONITOR_LOG_DIRS"
else
    _fail "SKILL.md missing CC_MONITOR_LOG_DIRS reference"
fi

if grep -q 'CC_MONITOR_TEST_DIRS' "$SKILL_MD"; then
    _pass "SKILL.md references CC_MONITOR_TEST_DIRS"
else
    _fail "SKILL.md missing CC_MONITOR_TEST_DIRS reference"
fi

if grep -q 'CC_MONITOR_BUILD_DIRS' "$SKILL_MD"; then
    _pass "SKILL.md references CC_MONITOR_BUILD_DIRS"
else
    _fail "SKILL.md missing CC_MONITOR_BUILD_DIRS reference"
fi

if grep -q 'CC_LANGUAGE' "$SKILL_MD"; then
    _pass "SKILL.md references CC_LANGUAGE for pattern loading"
else
    _fail "SKILL.md missing CC_LANGUAGE reference"
fi

if grep -q 'CC_MONITOR_REPORT_DIR' "$SKILL_MD"; then
    _pass "SKILL.md references CC_MONITOR_REPORT_DIR"
else
    _fail "SKILL.md missing CC_MONITOR_REPORT_DIR reference"
fi

if grep -q 'CC_WORKSPACE_PROJECTS' "$SKILL_MD"; then
    _pass "SKILL.md references CC_WORKSPACE_PROJECTS for workspace mode"
else
    _fail "SKILL.md missing CC_WORKSPACE_PROJECTS reference"
fi

# ---- Required sections ----

for section in "## Arguments" "## Configuration" "## Live Context" "## Instructions" "## Examples" "## See Also"; do
    if grep -qF "$section" "$SKILL_MD"; then
        _pass "SKILL.md has section: ${section}"
    else
        _fail "SKILL.md missing section: ${section}"
    fi
done

# ---- Report template contains required sections ----

for report_section in "## Alerts" "## Test Results" "## Build Health" "## Log Growth" "## Error Details" "## Recommended Actions"; do
    if grep -qF "$report_section" "$SKILL_MD"; then
        _pass "report template has: ${report_section}"
    else
        _fail "report template missing: ${report_section}"
    fi
done

# ---- Error patterns reference covers all supported languages ----

for language in "Perl" "Python" "Java" "Node" "Go" "Rust" "Shell"; do
    if grep -qF "## ${language}" "$ERROR_PATTERNS"; then
        _pass "error-patterns.md covers: ${language}"
    else
        _fail "error-patterns.md missing: ${language}"
    fi
done

# ---- Language pack monitor-patterns.conf files ----

for lang in perl python java node; do
    pattern_file="${ROOT_DIR}/language-packs/${lang}/monitor-patterns.conf"
    if [ -f "$pattern_file" ]; then
        _pass "language pack: ${lang}/monitor-patterns.conf exists"

        # Validate required variables in pattern file
        for var in MONITOR_ERROR_REGEX MONITOR_TEST_FORMAT MONITOR_TEST_REGEX; do
            if grep -q "^${var}=" "$pattern_file"; then
                _pass "  ${lang}: ${var} defined"
            else
                _fail "  ${lang}: ${var} missing"
            fi
        done
    else
        _fail "language pack: ${lang}/monitor-patterns.conf not found"
    fi
done

# ---- Config example includes CC_MONITOR_* variables ----

CONF_EXAMPLE="${ROOT_DIR}/cognitive-core.conf.example"
if [ -f "$CONF_EXAMPLE" ]; then
    for var in CC_MONITOR_LOG_DIRS CC_MONITOR_TEST_DIRS CC_MONITOR_BUILD_DIRS CC_MONITOR_SINCE CC_MONITOR_REPORT_DIR CC_MONITOR_MAX_LOG_SIZE; do
        if grep -q "^${var}=" "$CONF_EXAMPLE"; then
            _pass "conf.example: ${var} defined"
        else
            _fail "conf.example: ${var} missing"
        fi
    done
else
    _skip "cognitive-core.conf.example not found"
fi

suite_end
