#!/bin/bash
# cognitive-core hook: PreToolUse (Bash)
# Universal safety guard blocking dangerous commands
# All patterns use POSIX ERE (no \s, \b, \w) for macOS + Linux compatibility
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

# Strip quoted strings so patterns don't false-positive on commit messages or echo content.
# E.g. git commit -m "fix chmod 777 message" should NOT trigger the chmod guard.
CMD_STRIPPED=$(echo "$CMD_LOWER" | sed \
    -e 's/"\$(cat <<[^)]*)"//g' \
    -e "s/\"[^\"]*\"//g" \
    -e "s/'[^']*'//g")

# Detect interpreter wrapping: bash -c "...", sh -c '...', eval "..."
# When the payload is inside quotes, CMD_STRIPPED loses it — fall back to CMD_LOWER.
_CMD_CHECK="$CMD_STRIPPED"
if echo "$_CMD_CHECK" | grep -qE '(^|[;&|])[[:space:]]*(bash|sh|zsh|dash|python[23]?|perl|ruby)[[:space:]]+-c[[:space:]]*$|(^|[;&|])[[:space:]]*eval[[:space:]]*$'; then
    _CMD_CHECK="$CMD_LOWER"
fi

REASON=""

# --- Built-in safety patterns (always active) ---

# rm targeting system-critical paths
if echo "$_CMD_CHECK" | grep -qE 'rm[[:space:]]+(-[a-z]*f[a-z]*[[:space:]]+)?(/|/etc|/usr|/var|/home|/System|/Library)([[:space:]]|$|["'"'"'])'; then
    REASON="Blocked: rm targeting system-critical path"
fi

# git push --force to main/master
if [ -z "$REASON" ] && echo "$_CMD_CHECK" | grep -qE 'git[[:space:]]+push[[:space:]]+.*--force.*[[:space:]]+(master|main)([[:space:]]|$)|git[[:space:]]+push[[:space:]]+.*-f[[:space:]]+.*(master|main)([[:space:]]|$)'; then
    REASON="Blocked: force push to ${CC_MAIN_BRANCH:-main}"
fi

# git reset --hard
if [ -z "$REASON" ] && echo "$_CMD_CHECK" | grep -qE 'git[[:space:]]+reset[[:space:]]+--hard'; then
    REASON="Blocked: git reset --hard (destructive, may lose work)"
fi

# DROP TABLE / TRUNCATE TABLE
if [ -z "$REASON" ] && echo "$_CMD_CHECK" | grep -qiE '(drop|truncate)[[:space:]]+table'; then
    REASON="Blocked: DROP/TRUNCATE TABLE (destructive database operation)"
fi

# DELETE FROM without WHERE
if [ -z "$REASON" ] && echo "$_CMD_CHECK" | grep -qiE 'delete[[:space:]]+from[[:space:]]+[a-zA-Z0-9_]+[[:space:]]*$|delete[[:space:]]+from[[:space:]]+[a-zA-Z0-9_]+[[:space:]]*;'; then
    REASON="Blocked: DELETE FROM without WHERE clause (would delete all rows). Add a WHERE clause to limit scope"
fi

# rm .git
if [ -z "$REASON" ] && echo "$_CMD_CHECK" | grep -qE 'rm[[:space:]]+(-[a-z]*[[:space:]]+)?\.git([[:space:]]|$|/)'; then
    REASON="Blocked: removing .git directory"
fi

# chmod 777
if [ -z "$REASON" ] && echo "$_CMD_CHECK" | grep -qE 'chmod[[:space:]]+777'; then
    REASON="Blocked: chmod 777 (world-writable is insecure). Use 755 for directories, 644 for files, or 700 for private"
fi

# git clean -f (without dry-run)
if [ -z "$REASON" ] && echo "$_CMD_CHECK" | grep -qE 'git[[:space:]]+clean[[:space:]]+-[a-z]*f' && ! echo "$_CMD_CHECK" | grep -qE 'git[[:space:]]+clean[[:space:]]+-[a-z]*n'; then
    REASON="Blocked: git clean -f (removes untracked files). Use 'git clean -n' to preview first, then 'git clean -fd' if confirmed"
fi

# --- Security level gated patterns ---
# CC_SECURITY_LEVEL: minimal|standard|strict (default: standard)
_SECURITY_LEVEL="${CC_SECURITY_LEVEL:-standard}"

if [ "$_SECURITY_LEVEL" != "minimal" ]; then
    # === Standard level: exfiltration, encoded commands, pipe-to-shell ===

    # Exfiltration patterns
    if [ -z "$REASON" ] && echo "$_CMD_CHECK" | grep -qE 'curl[[:space:]]+.*-d[[:space:]]+.*@'; then
        REASON="Blocked: potential data exfiltration (curl -d @file)"
    fi
    if [ -z "$REASON" ] && echo "$_CMD_CHECK" | grep -qE 'cat[[:space:]]+.*\|.*curl'; then
        REASON="Blocked: potential data exfiltration (cat | curl)"
    fi
    if [ -z "$REASON" ] && echo "$_CMD_CHECK" | grep -qE 'cat[[:space:]]+.*\|.*([[:space:]]|^)nc([[:space:]]|$)'; then
        REASON="Blocked: potential data exfiltration (cat | nc)"
    fi
    if [ -z "$REASON" ] && echo "$_CMD_CHECK" | grep -qE '(^|[[:space:]])env[[:space:]]*\|'; then
        REASON="Blocked: environment variable leak (env |)"
    fi

    # Encoded command bypass
    if [ -z "$REASON" ] && echo "$_CMD_CHECK" | grep -qE 'base64.*-d.*\|.*(ba)?sh'; then
        REASON="Blocked: encoded command execution (base64 -d | sh)"
    fi
    if [ -z "$REASON" ] && echo "$_CMD_CHECK" | grep -qE 'echo[[:space:]]+.*\|.*base64.*-d'; then
        REASON="Blocked: encoded command execution (echo | base64 -d)"
    fi
    if [ -z "$REASON" ] && echo "$_CMD_CHECK" | grep -qE '(^|[[:space:]])eval[[:space:]]+.*\$\('; then
        REASON="Blocked: eval with command substitution"
    fi

    # Pipe-to-shell (supply chain attack vector)
    if [ -z "$REASON" ] && echo "$_CMD_CHECK" | grep -qE 'curl[[:space:]]+.*\|.*(ba)?sh'; then
        REASON="Blocked: pipe-to-shell (curl | sh) — supply chain risk"
    fi
    if [ -z "$REASON" ] && echo "$_CMD_CHECK" | grep -qE 'wget[[:space:]]+.*\|.*(ba)?sh'; then
        REASON="Blocked: pipe-to-shell (wget | sh) — supply chain risk"
    fi
    if [ -z "$REASON" ] && echo "$_CMD_CHECK" | grep -qE 'wget[[:space:]]+.*-O-[[:space:]]*\|'; then
        REASON="Blocked: pipe-to-shell (wget -O- |) — supply chain risk"
    fi
fi

# --- Closure guard: prevent direct gh issue close (policy) ---
# Gate behind CC_REQUIRE_CLOSURE_VERIFICATION (default: follows CC_REQUIRE_HUMAN_APPROVAL)
_CLOSURE_GUARD="${CC_REQUIRE_CLOSURE_VERIFICATION:-${CC_REQUIRE_HUMAN_APPROVAL:-true}}"

if [ -z "$REASON" ] && [ "$_CLOSURE_GUARD" = "true" ]; then
    if echo "$CMD_LOWER" | grep -qE 'gh[[:space:]]+issue[[:space:]]+close'; then
        # Exempt legitimate skill paths
        _CLOSURE_EXEMPT="false"
        if echo "$CMD" | grep -qF "Approved by @"; then
            _CLOSURE_EXEMPT="true"
        fi
        if echo "$CMD" | grep -qF "Canceled:"; then
            _CLOSURE_EXEMPT="true"
        fi
        if [ "$_CLOSURE_EXEMPT" = "false" ]; then
            REASON="Blocked: direct gh issue close bypasses closure guard"
            _cc_security_log "DENY" "closure-guard" "${REASON} | cmd=${CMD}"
            _cc_json_pretool_deny_structured "$REASON" "policy" "true" "Use '/project-board approve N' for verified issues or '/project-board close N --comment \"Approved by @user\"' to close with exemption"
            exit 0
        fi
    fi
fi

# --- Project-specific blocked patterns (from config) ---
if [ -z "$REASON" ] && [ -n "${CC_BLOCKED_PATTERNS:-}" ]; then
    for pattern in $CC_BLOCKED_PATTERNS; do
        if echo "$_CMD_CHECK" | grep -qE "$pattern"; then
            REASON="Blocked: matches project safety rule '${pattern}'. Check CC_BLOCKED_PATTERNS in cognitive-core.conf"
            break
        fi
    done
fi

# Output deny JSON if blocked, otherwise silent exit 0
if [ -n "$REASON" ]; then
    _cc_security_log "DENY" "bash-blocked" "${REASON} | cmd=${CMD}"
    _cc_json_pretool_deny_structured "$REASON" "security" "false"
fi

exit 0
