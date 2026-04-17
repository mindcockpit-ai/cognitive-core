#!/bin/bash
# Test suite: skill-sync preamble parsing
# Regression guard for #255 — brittle grep|sed JSON parsing + unguarded git log exit
# in core/skills/skill-sync/SKILL.md caused /skill-sync to fail on session start.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "22 — Skill Sync Preamble"

SKILL_FILE="${ROOT_DIR}/core/skills/skill-sync/SKILL.md"

# =============================================================================
# Section 1: Static content guards — non-regression against the buggy pattern
# =============================================================================

assert_file_exists "skill-sync SKILL.md exists" "$SKILL_FILE"

# The buggy pattern `cat ... | grep '"source"' | sed '...;s/".*//'` must not return.
# Use a distinctive substring that only appears in the old buggy form.
if grep -qF "s/\".*//" "$SKILL_FILE"; then
    _fail "non-regression: old sed pattern 's/\".*//' must not appear" \
          "found buggy sed pattern — should be 's/\"//' in the tighter form"
else
    _pass "non-regression: old sed pattern 's/\".*//' removed"
fi

# The fix should use jq with the conformant `.source // ""` filter
# (matches core/utilities/check-update.sh:27)
if grep -qF '.source // ""' "$SKILL_FILE"; then
    _pass "fix: jq '.source // \"\"' filter present"
else
    _fail "fix: jq '.source // \"\"' filter missing" \
          "expected new parsing pattern not found"
fi

# The git log must be guarded with `|| true` in the preamble
if grep -qE 'git -C "\$SOURCE" log --oneline -3 2>/dev/null \|\| true' "$SKILL_FILE"; then
    _pass "fix: git log guarded with '|| true'"
else
    _fail "fix: git log not guarded" \
          "preamble git log must end with '|| true' to survive non-zero exits"
fi

# =============================================================================
# Section 2: Runtime behaviour — extract and execute the preamble block
# =============================================================================

# The auto-executed preamble is on the line starting with "!`VF=".
# Extract the single-line shell fragment between the outer backticks.
extract_preamble() {
    awk '/^!`VF=/ { sub(/^!`/, ""); sub(/`$/, ""); print; exit }' "$SKILL_FILE"
}

PREAMBLE=$(extract_preamble)

if [ -z "$PREAMBLE" ]; then
    _fail "extract: preamble shell fragment found" "could not locate !\`VF=...\` block"
    suite_end
    exit $?
fi
_pass "extract: preamble shell fragment found"

# Security guard — the suite evaluates the extracted preamble with bash -c.
# If an attacker modifies SKILL.md to inject shell, refuse to execute.
# Blocks: network tools, shell escapes, TCP redirects, dynamic eval.
# Pattern expanded per POSIX ERE (no \b — use word boundaries via surrounding chars).
if echo "$PREAMBLE" | grep -qE '(^|[^a-zA-Z0-9_-])(curl|wget|nc|netcat|ssh|scp|eval|exec)[[:space:]]|/dev/tcp|/dev/udp|\$\(.*curl|\$\(.*wget|bash[[:space:]]+-i|python[[:space:]]+-c|perl[[:space:]]+-e'; then
    _fail "security: preamble contains disallowed tokens" \
          "extracted preamble includes network/eval tokens — refusing to execute"
    suite_end
    exit $?
fi
_pass "security: preamble passes allowlist guard"

# Helper: run the preamble in an isolated working directory
# Creates .claude/cognitive-core/version.json from the given JSON body,
# then executes the extracted preamble snippet. Prints: <exit>|<stdout>
run_preamble() {
    local json_body="$1" mock_dir
    mock_dir=$(create_test_dir)
    mkdir -p "${mock_dir}/.claude/cognitive-core"
    if [ -n "$json_body" ]; then
        printf '%s' "$json_body" > "${mock_dir}/.claude/cognitive-core/version.json"
    fi
    local out rc=0
    out=$(cd "$mock_dir" && bash -c "$PREAMBLE" 2>&1) || rc=$?
    rm -rf "$mock_dir"
    printf '%s|%s' "$rc" "$out"
}

# --- Test: valid version.json pointing at this repo ---
RESULT=$(run_preamble "$(printf '{"source": "%s", "version": "1.5.0"}' "$ROOT_DIR")")
RC="${RESULT%%|*}"
OUT="${RESULT#*|}"
assert_eq "valid json: exit code is 0" "0" "$RC"
assert_contains "valid json: outputs 'Framework:' prefix" "$OUT" "Framework:"
assert_contains "valid json: outputs resolved source path" "$OUT" "$ROOT_DIR"

# --- Test: whitespace variant (extra spaces around colon and value) ---
RESULT=$(run_preamble "$(printf '{  "source"  :   "%s"  , "version": "1.5.0"}' "$ROOT_DIR")")
RC="${RESULT%%|*}"
OUT="${RESULT#*|}"
assert_eq "whitespace json: exit code is 0" "0" "$RC"
assert_contains "whitespace json: outputs 'Framework:' prefix" "$OUT" "Framework:"

# --- Test: missing version.json ---
RESULT=$(run_preamble "")
RC="${RESULT%%|*}"
OUT="${RESULT#*|}"
assert_eq "missing file: exit code is 0" "0" "$RC"
assert_contains "missing file: outputs ERROR message" "$OUT" "ERROR:"

# --- Test: source key absent from JSON ---
RESULT=$(run_preamble '{"version": "1.5.0", "installed_at": "2026-01-01"}')
RC="${RESULT%%|*}"
OUT="${RESULT#*|}"
assert_eq "no source key: exit code is 0" "0" "$RC"
assert_contains "no source key: outputs ERROR message" "$OUT" "ERROR:"

# --- Test: source points to non-existent path ---
RESULT=$(run_preamble '{"source": "/nonexistent/path/xyzzy", "version": "1.5.0"}')
RC="${RESULT%%|*}"
OUT="${RESULT#*|}"
assert_eq "bad path: exit code is 0" "0" "$RC"
assert_contains "bad path: outputs ERROR message" "$OUT" "ERROR:"

# --- Test: uninitialized git repo — verifies '|| true' guards git log failure ---
NONGIT_DIR=$(create_test_dir)
RESULT=$(run_preamble "$(printf '{"source": "%s", "version": "1.5.0"}' "$NONGIT_DIR")")
RC="${RESULT%%|*}"
OUT="${RESULT#*|}"
assert_eq "non-git source: exit code is 0" "0" "$RC"
assert_contains "non-git source: outputs 'Framework:' prefix" "$OUT" "Framework:"
rm -rf "$NONGIT_DIR"

# --- Test: jq-absent fallback path ---
# Build a shadow PATH containing symlinks to every coreutil EXCEPT jq, so that
# `command -v jq` fails inside the subshell and the grep|sed branch runs.
JQ_PATH=$(command -v jq 2>/dev/null || true)
if [ -n "$JQ_PATH" ]; then
    SHADOW_DIR=$(create_test_dir)
    # Symlink every standard binary except jq from /usr/bin and /bin into the shadow.
    for src_dir in /usr/bin /bin; do
        [ -d "$src_dir" ] || continue
        for src_bin in "$src_dir"/*; do
            [ -x "$src_bin" ] || continue
            name=$(basename "$src_bin")
            [ "$name" = "jq" ] && continue
            [ -e "${SHADOW_DIR}/${name}" ] && continue
            ln -s "$src_bin" "${SHADOW_DIR}/${name}" 2>/dev/null || true
        done
    done

    sanity=$(PATH="$SHADOW_DIR" bash -c 'if command -v jq >/dev/null 2>&1; then echo PRESENT; else echo ABSENT; fi' 2>&1 || true)
    if [ "$sanity" = "ABSENT" ]; then
        mock_dir=$(create_test_dir)
        mkdir -p "${mock_dir}/.claude/cognitive-core"
        printf '{"source": "%s", "version": "1.5.0"}' "$ROOT_DIR" \
            > "${mock_dir}/.claude/cognitive-core/version.json"

        rc=0
        out=$(cd "$mock_dir" && PATH="$SHADOW_DIR" bash -c "$PREAMBLE" 2>&1) || rc=$?
        assert_eq "jq-absent fallback: exit code is 0" "0" "$rc"
        assert_contains "jq-absent fallback: outputs 'Framework:' prefix" "$out" "Framework:"
        assert_contains "jq-absent fallback: outputs resolved source path" "$out" "$ROOT_DIR"
        rm -rf "$mock_dir"
    else
        _skip "jq-absent fallback (could not isolate jq in shadow PATH)"
    fi
    rm -rf "$SHADOW_DIR"
else
    _skip "jq-absent fallback (jq not installed — cannot verify two-tier parse)"
fi

suite_end
