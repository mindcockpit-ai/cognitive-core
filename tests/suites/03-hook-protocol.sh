#!/bin/bash
# Test suite: Hook protocol — mock stdin → verify JSON output format
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "03 — Hook Protocol (JSON I/O)"

HOOKS_DIR="${ROOT_DIR}/core/hooks"

# ---- validate-bash.sh: deny patterns produce valid JSON ----
VALIDATE_BASH="${HOOKS_DIR}/validate-bash.sh"

if [ -f "$VALIDATE_BASH" ]; then
    # Test: rm -rf / should be denied
    assert_hook_denies \
        "validate-bash: rm -rf / → deny" \
        "$VALIDATE_BASH" \
        "$(mock_bash_json "rm -rf /")"

    # Test: git push --force main should be denied
    assert_hook_denies \
        "validate-bash: git push --force main → deny" \
        "$VALIDATE_BASH" \
        "$(mock_bash_json "git push --force origin main")"

    # Test: git reset --hard should be denied
    assert_hook_denies \
        "validate-bash: git reset --hard → deny" \
        "$VALIDATE_BASH" \
        "$(mock_bash_json "git reset --hard HEAD~1")"

    # Test: chmod 777 should be denied
    assert_hook_denies \
        "validate-bash: chmod 777 → deny" \
        "$VALIDATE_BASH" \
        "$(mock_bash_json "chmod 777 /tmp/foo")"

    # Test: safe commands should pass
    assert_hook_allows \
        "validate-bash: ls -la → allow" \
        "$VALIDATE_BASH" \
        "$(mock_bash_json "ls -la")"

    assert_hook_allows \
        "validate-bash: git status → allow" \
        "$VALIDATE_BASH" \
        "$(mock_bash_json "git status")"

    assert_hook_allows \
        "validate-bash: npm test → allow" \
        "$VALIDATE_BASH" \
        "$(mock_bash_json "npm test")"

    # Test: deny output is valid JSON
    output=$(echo "$(mock_bash_json "rm -rf /")" | bash "$VALIDATE_BASH" 2>/dev/null) || true
    if command -v jq &>/dev/null; then
        if echo "$output" | jq . &>/dev/null; then
            _pass "validate-bash: deny output is valid JSON"
        else
            _fail "validate-bash: deny output is not valid JSON" "$output"
        fi
    else
        _skip "validate-bash: JSON validation (jq not available)"
    fi
else
    _skip "validate-bash.sh not found"
fi

# ---- setup-env.sh: produces valid SessionStart JSON ----
SETUP_ENV="${HOOKS_DIR}/setup-env.sh"

if [ -f "$SETUP_ENV" ]; then
    # setup-env.sh needs to be run in a git repo context
    test_dir=$(create_test_dir)
    git -C "$test_dir" init --quiet 2>/dev/null || true

    output=$(CC_PROJECT_DIR="$test_dir" CLAUDE_PROJECT_DIR="$test_dir" \
        bash "$SETUP_ENV" 2>/dev/null) || true

    if [ -n "$output" ]; then
        if command -v jq &>/dev/null; then
            event=$(echo "$output" | jq -r '.hookSpecificOutput.hookEventName // ""' 2>/dev/null)
            assert_eq "setup-env: hookEventName is SessionStart" "SessionStart" "$event"
        else
            assert_contains "setup-env: output has SessionStart" "$output" "SessionStart"
        fi
    else
        _fail "setup-env: produced no output"
    fi

    rm -rf "$test_dir"
else
    _skip "setup-env.sh not found"
fi

# ---- _lib.sh: JSON helper functions ----
LIB="${HOOKS_DIR}/_lib.sh"

if [ -f "$LIB" ]; then
    # Test _cc_json_pretool_deny
    output=$(bash -c "source '${LIB}'; _cc_json_pretool_deny 'test reason'" 2>/dev/null)
    if command -v jq &>/dev/null; then
        decision=$(echo "$output" | jq -r '.hookSpecificOutput.permissionDecision // ""' 2>/dev/null)
        assert_eq "_lib: pretool_deny decision=deny" "deny" "$decision"

        reason=$(echo "$output" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""' 2>/dev/null)
        assert_eq "_lib: pretool_deny reason" "test reason" "$reason"
    else
        assert_contains "_lib: pretool_deny contains deny" "$output" "deny"
    fi

    # Test _cc_json_session_context
    output=$(bash -c "source '${LIB}'; _cc_json_session_context 'hello world'" 2>/dev/null)
    if command -v jq &>/dev/null; then
        ctx=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null)
        assert_eq "_lib: session_context value" "hello world" "$ctx"
    else
        assert_contains "_lib: session_context contains hello" "$output" "hello world"
    fi

    # Test _cc_json_posttool_context
    output=$(bash -c "source '${LIB}'; _cc_json_posttool_context 'post info'" 2>/dev/null)
    if command -v jq &>/dev/null; then
        ctx=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null)
        assert_eq "_lib: posttool_context value" "post info" "$ctx"
    else
        assert_contains "_lib: posttool_context contains post" "$output" "post info"
    fi
else
    _skip "_lib.sh not found"
fi

# ---- compact-reminder.sh: produces valid SessionStart JSON ----
COMPACT_REMINDER="${HOOKS_DIR}/compact-reminder.sh"

if [ -f "$COMPACT_REMINDER" ]; then
    test_dir=$(create_test_dir)
    git -C "$test_dir" init --quiet 2>/dev/null || true

    output=$(CC_PROJECT_DIR="$test_dir" CLAUDE_PROJECT_DIR="$test_dir" \
        bash "$COMPACT_REMINDER" 2>/dev/null) || true

    if [ -n "$output" ]; then
        if command -v jq &>/dev/null; then
            event=$(echo "$output" | jq -r '.hookSpecificOutput.hookEventName // ""' 2>/dev/null)
            assert_eq "compact-reminder: hookEventName is SessionStart" "SessionStart" "$event"

            ctx=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null)
            assert_contains "compact-reminder: includes CRITICAL RULES" "$ctx" "CRITICAL RULES"
            assert_contains "compact-reminder: includes AGENT ROUTING" "$ctx" "AGENT ROUTING"
            assert_contains "compact-reminder: includes COMPACTION DETECTED" "$ctx" "COMPACTION DETECTED"
        else
            assert_contains "compact-reminder: output has SessionStart" "$output" "SessionStart"
        fi
    else
        _fail "compact-reminder: produced no output"
    fi

    rm -rf "$test_dir"
else
    _skip "compact-reminder.sh not found"
fi

suite_end
