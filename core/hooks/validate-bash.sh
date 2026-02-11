#!/bin/bash
# cognitive-core hook: PreToolUse (Bash)
# Universal safety guard blocking dangerous commands
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"
_cc_load_config

# Read stdin JSON
INPUT=$(cat)

# Extract the command
CMD=$(echo "$INPUT" | _cc_json_get ".tool_input.command")

if [ -z "$CMD" ]; then
    exit 0
fi

CMD_LOWER=$(echo "$CMD" | tr '[:upper:]' '[:lower:]')

REASON=""

# --- Built-in safety patterns (always active) ---

# rm targeting system-critical paths
if echo "$CMD_LOWER" | grep -qE 'rm\s+(-[a-z]*f[a-z]*\s+)?(/|/etc|/usr|/var|/home|/System|/Library)\b'; then
    REASON="Blocked: rm targeting system-critical path"
fi

# git push --force to main/master
if [ -z "$REASON" ] && echo "$CMD_LOWER" | grep -qE 'git\s+push\s+.*--force.*\s+(master|main)\b|git\s+push\s+.*-f\s+.*(master|main)\b'; then
    REASON="Blocked: force push to ${CC_MAIN_BRANCH:-main}"
fi

# git reset --hard
if [ -z "$REASON" ] && echo "$CMD_LOWER" | grep -qE 'git\s+reset\s+--hard'; then
    REASON="Blocked: git reset --hard (destructive, may lose work)"
fi

# DROP TABLE / TRUNCATE TABLE
if [ -z "$REASON" ] && echo "$CMD_LOWER" | grep -qiE '(drop|truncate)\s+table'; then
    REASON="Blocked: DROP/TRUNCATE TABLE (destructive database operation)"
fi

# DELETE FROM without WHERE
if [ -z "$REASON" ] && echo "$CMD_LOWER" | grep -qiE 'delete\s+from\s+\w+\s*$|delete\s+from\s+\w+\s*;'; then
    REASON="Blocked: DELETE FROM without WHERE clause"
fi

# rm .git
if [ -z "$REASON" ] && echo "$CMD_LOWER" | grep -qE 'rm\s+(-[a-z]*\s+)?\.git\b'; then
    REASON="Blocked: removing .git directory"
fi

# chmod 777
if [ -z "$REASON" ] && echo "$CMD_LOWER" | grep -qE 'chmod\s+777'; then
    REASON="Blocked: chmod 777 (insecure permissions)"
fi

# git clean -f (without dry-run)
if [ -z "$REASON" ] && echo "$CMD_LOWER" | grep -qE 'git\s+clean\s+-[a-z]*f' && ! echo "$CMD_LOWER" | grep -qE 'git\s+clean\s+-[a-z]*n'; then
    REASON="Blocked: git clean -f (removes untracked files)"
fi

# --- Project-specific blocked patterns (from config) ---
if [ -z "$REASON" ] && [ -n "${CC_BLOCKED_PATTERNS:-}" ]; then
    for pattern in $CC_BLOCKED_PATTERNS; do
        if echo "$CMD_LOWER" | grep -qE "$pattern"; then
            REASON="Blocked: matches project safety rule: ${pattern}"
            break
        fi
    done
fi

# Output deny JSON if blocked, otherwise silent exit 0
if [ -n "$REASON" ]; then
    _cc_json_pretool_deny "$REASON"
fi

exit 0
