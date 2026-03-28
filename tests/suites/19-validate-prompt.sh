#!/bin/bash
# Test suite 19 — Validate Prompt (deterministic prompt linter)
# Tests core/skills/project-board/validate-prompt.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"
suite_start "19 — Validate Prompt"

VP_SCRIPT="${ROOT_DIR}/core/skills/project-board/validate-prompt.sh"

# =============================================================================
# Section 1: File existence and structure
# =============================================================================

assert_file_exists "validate-prompt.sh exists" "$VP_SCRIPT"

assert_file_executable "validate-prompt.sh is executable" "$VP_SCRIPT"

SHEBANG=$(head -1 "$VP_SCRIPT")
assert_eq "shebang is bash" "#!/bin/bash" "$SHEBANG"

assert_contains "has set -euo pipefail" "$(head -15 "$VP_SCRIPT")" "set -euo pipefail"

# Syntax check
if bash -n "$VP_SCRIPT" 2>/dev/null; then _pass "syntax check: bash -n"; else _fail "syntax check: bash -n"; fi

# =============================================================================
# Section 2: Clean prompt — zero pattern warnings
# =============================================================================

CLEAN_PROMPT='<scope>
1. Create the authentication module at core/auth/handler.sh
2. Implement token validation logic
3. Add error handling for expired tokens
</scope>

<constraints>
- Do NOT modify existing session management
- Use POSIX ERE regex only
- Follow core/hooks/ conventions
</constraints>

<agents>
- @code-standards-reviewer: verify conventions
</agents>'

output=$(echo "$CLEAN_PROMPT" | bash "$VP_SCRIPT" 2>/dev/null) || true
assert_contains "clean prompt: has disclaimer" "$output" "Disclaimer"
assert_contains "clean prompt: 0 pattern warnings" "$output" "0 warning"

# Stderr should be empty on clean input
stderr=$(echo "$CLEAN_PROMPT" | bash "$VP_SCRIPT" 2>&1 >/dev/null) || true
assert_eq "clean prompt: empty stderr" "" "$stderr"

# Exit code 0
if echo "$CLEAN_PROMPT" | bash "$VP_SCRIPT" > /dev/null 2>&1; then _pass "clean prompt: exit 0"; else _fail "clean prompt: exit 0"; fi

# =============================================================================
# Section 3: Pattern detection — every sub-pattern tested individually
# =============================================================================

# Helper: test a single trigger phrase against expected category
_test_pattern() {
    local label="$1" phrase="$2" category="$3"
    local out
    out=$(echo "<scope>
${phrase} core/auth/handler.sh
</scope>
<constraints>Do NOT skip tests</constraints>" | bash "$VP_SCRIPT" 2>/dev/null) || true
    assert_contains "$label" "$out" "$category"
}

# -- Politeness (5 sub-patterns) --
_test_pattern "pattern: please" "please implement the fix at" "politeness"
_test_pattern "pattern: could you" "could you update the config at" "politeness"
_test_pattern "pattern: would you" "would you refactor the module at" "politeness"
_test_pattern "pattern: it would be nice" "it would be nice to fix" "politeness"
_test_pattern "pattern: feel free to" "feel free to adjust" "politeness"

# -- Hedging (5 sub-patterns) --
_test_pattern "pattern: consider" "consider using a different approach for" "hedging"
_test_pattern "pattern: might" "this might need refactoring in" "hedging"
_test_pattern "pattern: possibly" "possibly update the logic in" "hedging"
_test_pattern "pattern: perhaps" "perhaps change the implementation of" "hedging"
_test_pattern "pattern: maybe" "maybe refactor the handler in" "hedging"

# -- Vague terms (4 sub-patterns) --
_test_pattern "pattern: adequate" "ensure adequate coverage of" "vague term"
_test_pattern "pattern: reasonable" "use a reasonable approach for" "vague term"
_test_pattern "pattern: appropriate" "use the appropriate solution for" "vague term"
_test_pattern "pattern: sufficient" "add sufficient tests for" "vague term"

# -- Escape clauses (3 sub-patterns) --
_test_pattern "pattern: where possible" "optimise where possible in" "escape clause"
_test_pattern "pattern: as appropriate" "add logging as appropriate to" "escape clause"
_test_pattern "pattern: as needed" "refactor as needed in" "escape clause"

# -- Open-ended (3 sub-patterns) --
_test_pattern "pattern: etc." "add logging, metrics, etc. to" "open-ended"
_test_pattern "pattern: and so on" "fix errors, warnings, and so on in" "open-ended"
_test_pattern "pattern: including but not limited to" "update including but not limited to" "open-ended"

# -- Temporal vague (3 sub-patterns) --
_test_pattern "pattern: soon" "soon refactor the module at" "temporal vague"
_test_pattern "pattern: eventually" "eventually migrate the handler at" "temporal vague"
_test_pattern "pattern: shortly" "shortly update the config at" "temporal vague"

# -- Ambiguous quantifiers (4 sub-patterns) --
_test_pattern "pattern: several" "fix several issues in" "ambiguous quantifier"
_test_pattern "pattern: multiple" "update multiple files in" "ambiguous quantifier"
_test_pattern "pattern: various" "refactor various modules in" "ambiguous quantifier"
_test_pattern "pattern: a number of" "address a number of bugs in" "ambiguous quantifier"

# =============================================================================
# Section 4: False-positive prevention — clean corpus
# =============================================================================

# Imperative verbs should NOT trigger
output=$(echo "<scope>
Implement the fix at core/auth/handler.sh immediately
</scope>
<constraints>Do NOT skip tests</constraints>" | bash "$VP_SCRIPT" 2>/dev/null) || true
assert_contains "false-pos: imperative verb clean" "$output" "0 warning"

# "reconsider" triggers "consider" — accepted mid-word match (documented)
output=$(echo "<scope>
reconsider the approach for core/auth/handler.sh
</scope>
<constraints>Do NOT skip tests</constraints>" | bash "$VP_SCRIPT" 2>/dev/null) || true
assert_contains "false-pos: reconsider triggers hedging (accepted)" "$output" "hedging"

# Content inside <acceptance_criteria> should NOT trigger (section stripped)
output=$(echo "<scope>
Implement the fix at core/auth/handler.sh
</scope>
<constraints>Do NOT skip tests</constraints>
<acceptance_criteria>
- [ ] please consider using the appropriate solution eventually
</acceptance_criteria>" | bash "$VP_SCRIPT" 2>/dev/null) || true
assert_contains "false-pos: AC section stripped" "$output" "0 warning"

# Content inside <context> should NOT trigger
output=$(echo "<scope>
Implement the fix at core/auth/handler.sh
</scope>
<constraints>Do NOT skip tests</constraints>
<context>
This might eventually be appropriate for several use cases
</context>" | bash "$VP_SCRIPT" 2>/dev/null) || true
assert_contains "false-pos: context section stripped" "$output" "0 warning"

# =============================================================================
# Section 5: Structural checks
# =============================================================================

# Missing <constraints>
output=$(echo "<scope>
Implement the fix at core/auth/handler.sh
</scope>" | bash "$VP_SCRIPT" 2>/dev/null) || true
assert_contains "structural: missing constraints" "$output" "missing <constraints>"

# Missing file paths
output=$(echo "<scope>
Implement the authentication fix
</scope>
<constraints>Do NOT skip tests</constraints>" | bash "$VP_SCRIPT" 2>/dev/null) || true
assert_contains "structural: missing file paths" "$output" "no file paths"

# File paths present — no warning
output=$(echo "<scope>
Implement fix in core/auth/handler.sh
</scope>
<constraints>Do NOT skip tests</constraints>" | bash "$VP_SCRIPT" 2>/dev/null) || true
assert_not_contains "structural: paths present = no warning" "$output" "no file paths"

# Word count boundary: generate >400 words in <scope>
LONG_SCOPE="<scope>"
for i in $(seq 1 85); do LONG_SCOPE="${LONG_SCOPE}
Implement step ${i} of the core/auth/handler.sh refactor plan now"; done
LONG_SCOPE="${LONG_SCOPE}
</scope>
<constraints>Do NOT skip tests</constraints>"
output=$(echo "$LONG_SCOPE" | bash "$VP_SCRIPT" 2>/dev/null) || true
assert_contains "structural: word count >400" "$output" "exceeds 400"

# Short prompt — no word count warning
output=$(echo "$CLEAN_PROMPT" | bash "$VP_SCRIPT" 2>/dev/null) || true
assert_not_contains "structural: short prompt no word warning" "$output" "exceeds 400"

# =============================================================================
# Section 6: Security mitigations
# =============================================================================

# Binary input — exit 0, no crash
if printf '\x89PNG\r\n\x1a\x00' | bash "$VP_SCRIPT" > /dev/null 2>&1; then _pass "security: binary input exit 0"; else _fail "security: binary input exit 0"; fi

# Empty stdin — exit 0
if echo -n "" | bash "$VP_SCRIPT" > /dev/null 2>&1; then _pass "security: empty input exit 0"; else _fail "security: empty input exit 0"; fi

output=$(echo -n "" | bash "$VP_SCRIPT" 2>/dev/null) || true
assert_contains "security: empty input 0 warnings" "$output" "0 warning"

# Null bytes in text — no crash
output=$(printf 'consider\x00 using core/auth/handler.sh' | bash "$VP_SCRIPT" 2>/dev/null) || true
assert_contains "security: null bytes handled" "$output" "Disclaimer"

# No raw matched text in output: inject a distinctive string and verify it's NOT echoed
INJECTION='INJECTION_PAYLOAD_12345'
output=$(echo "<scope>
please ${INJECTION} at core/auth/handler.sh
</scope>
<constraints>Do NOT skip</constraints>" | bash "$VP_SCRIPT" 2>/dev/null) || true
assert_not_contains "security: no raw text echo" "$output" "$INJECTION"

# =============================================================================
# Section 7: Exit-0 contract
# =============================================================================

# With warnings
if echo "please consider" | bash "$VP_SCRIPT" > /dev/null 2>&1; then _pass "exit-0: with warnings"; else _fail "exit-0: with warnings"; fi

# Empty
if echo -n "" | bash "$VP_SCRIPT" > /dev/null 2>&1; then _pass "exit-0: empty"; else _fail "exit-0: empty"; fi

# Binary
if printf '\xff\xfe\x00\x01' | bash "$VP_SCRIPT" > /dev/null 2>&1; then _pass "exit-0: binary"; else _fail "exit-0: binary"; fi

# =============================================================================
# Section 8: Multiple warnings accumulation
# =============================================================================

MULTI_WARN='<scope>
please consider using the appropriate solution eventually
several modules need adequate refactoring
</scope>'

output=$(echo "$MULTI_WARN" | bash "$VP_SCRIPT" 2>/dev/null) || true
# Should have multiple WARN lines
warn_lines=$(echo "$output" | grep -c 'WARN' || echo "0")
if [ "$warn_lines" -ge 3 ]; then
    _pass "accumulation: 3+ warnings detected ($warn_lines)"
else
    _fail "accumulation: expected 3+ warnings, got $warn_lines"
fi

assert_contains "accumulation: has WARN prefix" "$output" "WARN"
assert_contains "accumulation: has disclaimer" "$output" "Disclaimer"
assert_contains "accumulation: has summary line" "$output" "warning(s)"

suite_end
