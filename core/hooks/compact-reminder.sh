#!/bin/bash
# cognitive-core hook: SessionStart (compact)
# Re-injects critical project rules after context compaction
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"
_cc_load_config

BRANCH=$(git -C "$CC_PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")
DIRTY_FILES=$(git -C "$CC_PROJECT_DIR" status --porcelain 2>/dev/null | head -10)

# Load language pack compact rules if available
PACK_RULES=""
if [ -n "${CC_LANGUAGE:-}" ]; then
    PACK_RULES_FILE="${CC_PROJECT_DIR}/.claude/cognitive-core/packs/${CC_LANGUAGE}/compact-rules.md"
    if [ -f "$PACK_RULES_FILE" ]; then
        PACK_RULES=$(cat "$PACK_RULES_FILE")
    fi
fi

# Load database pack compact rules if available
DB_RULES=""
if [ -n "${CC_DATABASE:-}" ] && [ "${CC_DATABASE}" != "none" ]; then
    DB_RULES_FILE="${CC_PROJECT_DIR}/.claude/cognitive-core/packs/${CC_DATABASE}/compact-rules.md"
    if [ -f "$DB_RULES_FILE" ]; then
        DB_RULES=$(cat "$DB_RULES_FILE")
    fi
fi

REMINDER="## Post-Compaction Context Refresh

**Project**: ${CC_PROJECT_NAME:-Project}
**Branch**: ${BRANCH}
**Uncommitted**: ${DIRTY_FILES:-None}

**Critical Rules (re-injected after compaction)**:
${CC_COMPACT_RULES:-No project rules configured. Add CC_COMPACT_RULES to cognitive-core.conf.}

${PACK_RULES:+**Language-Specific Rules (${CC_LANGUAGE})**:
${PACK_RULES}}

${DB_RULES:+**Database Rules (${CC_DATABASE})**:
${DB_RULES}}"

_cc_json_session_context "$REMINDER"
