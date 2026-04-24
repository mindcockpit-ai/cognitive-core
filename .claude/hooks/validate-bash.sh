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

# --- Branch guard: prevent direct feature/fix commits to main ---
# Agents should work on feature branches, not commit directly to main.
# Allowed on main: chore(), docs(), revert, merge commits, and git push.
if [ -z "$REASON" ] && echo "$_CMD_CHECK" | grep -qE 'git[[:space:]]+commit'; then
    _CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    _MAIN_BRANCH="${CC_MAIN_BRANCH:-main}"
    if [ -n "$_CURRENT_BRANCH" ] && [ "$_CURRENT_BRANCH" = "$_MAIN_BRANCH" ]; then
        # Extract commit message from -m flag (check CMD_LOWER for the type prefix)
        if echo "$CMD_LOWER" | grep -qE 'git[[:space:]]+commit.*-m'; then
            # Allow: chore(), docs(), revert, ci(), build(), style()
            if ! echo "$CMD_LOWER" | grep -qE '(chore|docs|revert|ci|build|style)[[:space:]]*(\(|:)'; then
                REASON="Blocked: direct feat/fix commit to ${_MAIN_BRANCH}. Create a feature branch first: git checkout -b feat/N-description"
                _cc_security_log "DENY" "branch-guard" "${REASON} | cmd=${CMD}"
                _cc_json_pretool_deny_structured "$REASON" "policy" "true" "Create a branch with 'git checkout -b feat/N-slug' or 'fix/N-slug', commit there, then open a PR"
                exit 0
            fi
        fi
    fi
fi

# --- Closure guard: prevent direct gh issue close (policy) ---
# Gate behind CC_REQUIRE_CLOSURE_VERIFICATION (default: follows CC_REQUIRE_HUMAN_APPROVAL)
_CLOSURE_GUARD="${CC_REQUIRE_CLOSURE_VERIFICATION:-${CC_REQUIRE_HUMAN_APPROVAL:-true}}"

if [ -z "$REASON" ] && [ "$_CLOSURE_GUARD" = "true" ]; then
    if echo "$CMD_LOWER" | grep -qE 'gh[[:space:]]+issue[[:space:]]+close'; then
        # Exempt legitimate skill paths
        _CLOSURE_EXEMPT="false"
        if echo "$CMD" | grep -qF "Canceled:"; then
            _CLOSURE_EXEMPT="true"
        fi
        if echo "$CMD" | grep -qF "Approved by @"; then
            _CLOSURE_EXEMPT="true"
        fi
        if [ "$_CLOSURE_EXEMPT" = "false" ]; then
            REASON="Blocked: direct gh issue close bypasses closure guard"
            _cc_security_log "DENY" "closure-guard" "${REASON} | cmd=${CMD}"
            _cc_json_pretool_deny_structured "$REASON" "policy" "true" "Use '/project-board approve N' for verified issues or '/project-board close N' for unverified"
            exit 0
        fi
    fi

    # gh api state-change bypass: REST (state=closed) or GraphQL (CloseIssue mutation)
    # Uses CMD_LOWER (not _CMD_CHECK) because payloads are typically inside quotes
    # that CMD_STRIPPED removes — same rationale as gh issue close above.
    # gh api state-change: always block (no exemptions — use gh issue close path with "Approved by @" or "Canceled:")
    if echo "$CMD_LOWER" | grep -qE 'gh[[:space:]]+api[[:space:]]' && \
       echo "$CMD_LOWER" | grep -qE 'state[^a-z]*closed|closeissue'; then
        _API_CLOSURE_EXEMPT="false"
        if echo "$CMD" | grep -qF "Canceled:"; then
            _API_CLOSURE_EXEMPT="true"
        fi
        if [ "$_API_CLOSURE_EXEMPT" = "false" ]; then
            REASON="Blocked: gh api call attempts to close issue via REST/GraphQL, bypassing closure guard"
            _cc_security_log "DENY" "closure-guard-api" "${REASON} | cmd=${CMD}"
            _cc_json_pretool_deny_structured "$REASON" "policy" "true" "Use '/project-board approve N' for verified issues or '/project-board close N --comment \"Approved by @user\"' to close with exemption"
            exit 0
        fi
    fi
fi

# --- Shared-state gate: merge/push to shared branches + Jira transitions ---
# These actions are visible to others and hard to reverse.
# Deterministic: cannot be bypassed by LLM prompt or memory drift.
# Gate: CC_REQUIRE_SHARED_STATE_APPROVAL (default: true)
_SHARED_GATE="${CC_REQUIRE_SHARED_STATE_APPROVAL:-true}"

if [ -z "$REASON" ] && [ "$_SHARED_GATE" = "true" ]; then
    # Block git push to develop or master (not feature branches)
    if echo "$CMD_LOWER" | grep -qE 'git[[:space:]]+push[[:space:]]+(origin[[:space:]]+)?(develop|master|main)([[:space:]]|$)'; then
        _PUSH_TARGET=$(echo "$CMD_LOWER" | grep -oE '(develop|master|main)' | head -1)
        REASON="Blocked: pushing to shared branch '${_PUSH_TARGET}' requires user approval"
        _cc_security_log "DENY" "shared-state-push" "${REASON} | cmd=${CMD}"
        _cc_json_pretool_deny_structured "$REASON" "policy" "true" "Ask the user to confirm before pushing to ${_PUSH_TARGET}"
        exit 0
    fi

    # Block git merge when on develop or master
    if echo "$CMD_LOWER" | grep -qE 'git[[:space:]]+merge'; then
        _CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
        if [ "$_CURRENT_BRANCH" = "develop" ] || [ "$_CURRENT_BRANCH" = "master" ] || [ "$_CURRENT_BRANCH" = "main" ]; then
            REASON="Blocked: merging into shared branch '${_CURRENT_BRANCH}' requires user approval"
            _cc_security_log "DENY" "shared-state-merge" "${REASON} | cmd=${CMD}"
            _cc_json_pretool_deny_structured "$REASON" "policy" "true" "Ask the user to confirm the merge into ${_CURRENT_BRANCH}"
            exit 0
        fi
    fi

    # Block Jira/issue-tracker transitions (ticket status changes are visible to team)
    # CC_JIRA_ALLOWED_TRANSITIONS: comma-separated IDs that pass without approval
    # Empty/unset = block all transitions (backward-compatible default)
    if echo "$CMD_LOWER" | grep -qE 'curl.*atlassian\.net.*/transitions'; then
        _TICKET=$(echo "$CMD" | grep -oE '[A-Z]+-[0-9]+' | head -1 || echo "unknown")
        _JIRA_ALLOWED="${CC_JIRA_ALLOWED_TRANSITIONS:-}"
        _TRANSITION_ID=""

        # Extract transition ID from curl body (-d, --data, --data-raw, --data-binary)
        # Body format: {"transition":{"id":"21"}}
        _CURL_BODY=$(echo "$CMD" | grep -oE '(-d|--data|--data-raw|--data-binary)[[:space:]]+'"'"'[^'"'"']*'"'"'' | head -1 || true)
        if [ -z "$_CURL_BODY" ]; then
            _CURL_BODY=$(echo "$CMD" | grep -oE '(-d|--data|--data-raw|--data-binary)[[:space:]]+"[^"]*"' | head -1 || true)
        fi
        if [ -n "$_CURL_BODY" ]; then
            _TRANSITION_ID=$(echo "$_CURL_BODY" | grep -oE '"id"[[:space:]]*:[[:space:]]*"[0-9]+"' | grep -oE '[0-9]+' | head -1 || true)
        fi

        # Check allowlist (exact match: "2" must not match "21")
        _JIRA_ALLOWED_MATCH="false"
        if [ -n "$_TRANSITION_ID" ] && [ -n "$_JIRA_ALLOWED" ]; then
            case ",${_JIRA_ALLOWED}," in
                *",${_TRANSITION_ID},"*)
                    _JIRA_ALLOWED_MATCH="true"
                    ;;
            esac
        fi

        if [ "$_JIRA_ALLOWED_MATCH" = "true" ]; then
            _cc_security_log "ALLOW" "shared-state-jira" "Allowed transition ${_TRANSITION_ID} for ${_TICKET} | cmd=${CMD}"
        else
            REASON="Blocked: Jira status transition for ${_TICKET} requires user approval"
            if [ -n "$_TRANSITION_ID" ]; then
                REASON="Blocked: Jira transition ${_TRANSITION_ID} for ${_TICKET} requires user approval"
            fi
            _cc_security_log "DENY" "shared-state-jira" "${REASON} | cmd=${CMD}"
            _cc_json_pretool_deny_structured "$REASON" "policy" "true" "Ask the user to confirm the Jira transition for ${_TICKET}"
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
