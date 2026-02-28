#!/bin/bash
# cognitive-core hook: SessionStart (compact)
# Re-injects critical project rules after context compaction.
# Without this, Claude loses project-specific constraints when the
# conversation is compressed, leading to standards violations.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"
_cc_load_config

BRANCH=$(git -C "$CC_PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")
DIRTY_FILES=$(git -C "$CC_PROJECT_DIR" status --porcelain 2>/dev/null | head -10)

# ---- Build critical rules (always present) ----

PROJECT="${CC_PROJECT_NAME:-Project}"
LANG="${CC_LANGUAGE:-unknown}"
ARCH="${CC_ARCHITECTURE:-none}"
LINT="${CC_LINT_COMMAND:-echo no-lint}"
TEST="${CC_TEST_COMMAND:-echo no-tests}"
MAIN="${CC_MAIN_BRANCH:-main}"
SEC="${CC_SECURITY_LEVEL:-standard}"

RULES="CRITICAL RULES (always in effect, survive compaction):

1. ARCHITECTURE: Follow the '${ARCH}' pattern. Read CLAUDE.md for layer definitions and allowed dependencies.
2. GIT COMMITS: type(scope): subject format. NO AI/Claude/tool references. Professional codebase only.
3. LINT: Run \`${LINT}\` before every commit. All code must pass automated checks.
4. SECURITY: Level '${SEC}' active. Hooks guard Bash, Read, WebFetch, Write. Do not bypass.
5. AGENTS: Hub-and-spoke model. project-coordinator delegates to specialists. See .claude/AGENTS_README.md."

# ---- Agent routing quick reference ----

ROUTING="AGENT ROUTING:
- New feature/workflow/architecture -> solution-architect
- Code review/standards check -> code-standards-reviewer
- Tests needed/failing -> test-specialist
- Unknown error/library/research -> research-analyst
- DB performance/queries -> database-specialist
- Multi-step coordination -> project-coordinator"

# ---- Project-specific compact rules from config ----

CUSTOM=""
if [ -n "${CC_COMPACT_RULES:-}" ]; then
    CUSTOM="
PROJECT-SPECIFIC RULES:
${CC_COMPACT_RULES}"
fi

# ---- Language pack compact rules ----

PACK_RULES=""
if [ -n "${CC_LANGUAGE:-}" ]; then
    PACK_RULES_FILE="${CC_PROJECT_DIR}/.claude/cognitive-core/packs/${CC_LANGUAGE}/compact-rules.md"
    if [ -f "$PACK_RULES_FILE" ]; then
        PACK_RULES="
LANGUAGE RULES (${CC_LANGUAGE}):
$(cat "$PACK_RULES_FILE")"
    fi
fi

# ---- Database pack compact rules ----

DB_RULES=""
if [ -n "${CC_DATABASE:-}" ] && [ "${CC_DATABASE}" != "none" ]; then
    DB_RULES_FILE="${CC_PROJECT_DIR}/.claude/cognitive-core/packs/${CC_DATABASE}/compact-rules.md"
    if [ -f "$DB_RULES_FILE" ]; then
        DB_RULES="
DATABASE RULES (${CC_DATABASE}):
$(cat "$DB_RULES_FILE")"
    fi
fi

# ---- Compose context message ----

REMINDER="CONTEXT COMPACTION DETECTED — Critical rules re-injected for ${PROJECT} (${LANG}/${ARCH}).

Branch: ${BRANCH}
Uncommitted: ${DIRTY_FILES:-None}

${RULES}

${ROUTING}
${CUSTOM}${PACK_RULES}${DB_RULES}

QUICK REFERENCE: Lint: \`${LINT}\` | Test: \`${TEST}\` | Main: ${MAIN}
Read CLAUDE.md for full project standards."

_cc_json_session_context "$REMINDER"
