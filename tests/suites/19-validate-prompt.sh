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

# S3: Missing "Do NOT" boundaries — triggers only when >200 instruction words
LONG_NO_DONOT="<scope>"
for i in $(seq 1 45); do LONG_NO_DONOT="${LONG_NO_DONOT}
Implement step ${i} of the core/auth/handler.sh refactor plan now safely"; done
LONG_NO_DONOT="${LONG_NO_DONOT}
</scope>
<constraints>Follow conventions for core/auth/handler.sh</constraints>"
output=$(echo "$LONG_NO_DONOT" | bash "$VP_SCRIPT" 2>/dev/null) || true
assert_contains "structural: missing Do NOT (>200 words)" "$output" "Do NOT"

# S3 negative: "Do NOT" present — no warning
LONG_WITH_DONOT="<scope>"
for i in $(seq 1 45); do LONG_WITH_DONOT="${LONG_WITH_DONOT}
Implement step ${i} of the core/auth/handler.sh refactor plan now safely"; done
LONG_WITH_DONOT="${LONG_WITH_DONOT}
</scope>
<constraints>Do NOT modify existing hooks at core/auth/handler.sh</constraints>"
output=$(echo "$LONG_WITH_DONOT" | bash "$VP_SCRIPT" 2>/dev/null) || true
assert_not_contains "structural: Do NOT present = no warning" "$output" "Do NOT.*boundaries"

# S3 edge: short prompt (<200 words) without "Do NOT" — no warning (below threshold)
output=$(echo "<scope>
Implement fix at core/auth/handler.sh
</scope>
<constraints>Follow conventions</constraints>" | bash "$VP_SCRIPT" 2>/dev/null) || true
assert_not_contains "structural: short prompt no Do NOT = no warning" "$output" "Do NOT.*boundaries"

# S5: Dangling "the following" without subsequent list
output=$(echo "<scope>
Update the following
</scope>
<constraints>Do NOT skip tests for core/auth/handler.sh</constraints>" | bash "$VP_SCRIPT" 2>/dev/null) || true
assert_contains "structural: dangling 'the following'" "$output" "dangling"

# S5 negative: "the following" with content on next line — no warning
output=$(echo "<scope>
Update the following
- core/auth/handler.sh
</scope>
<constraints>Do NOT skip tests</constraints>" | bash "$VP_SCRIPT" 2>/dev/null) || true
assert_not_contains "structural: 'the following' with list = no warning" "$output" "dangling"

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

# UTF-8 with table-drawing characters — must NOT be rejected as binary
output=$(echo "<scope>
| Column | Count |
|────────|───────|
Implement fix at core/auth/handler.sh
</scope>
<constraints>Do NOT skip tests</constraints>" | bash "$VP_SCRIPT" 2>/dev/null) || true
assert_contains "security: UTF-8 table chars pass binary guard" "$output" "Disclaimer"
assert_contains "security: UTF-8 produces warning count" "$output" "warning(s)"

# UTF-8 with Cyrillic/accented chars — must pass binary guard
output=$(echo "<scope>
Refactor módulo autentificación at core/auth/handler.sh
</scope>
<constraints>Do NOT skip</constraints>" | bash "$VP_SCRIPT" 2>/dev/null) || true
assert_contains "security: UTF-8 accented chars pass" "$output" "Disclaimer"

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

# =============================================================================
# Section 9: Layer 2 — Codebase grounding
# =============================================================================

# Create synthetic codebase fixture
L2_FIXTURE=$(mktemp -d)
mkdir -p "${L2_FIXTURE}/core/auth"
mkdir -p "${L2_FIXTURE}/core/agents"
mkdir -p "${L2_FIXTURE}/core/hooks"
touch "${L2_FIXTURE}/core/auth/handler.sh"
touch "${L2_FIXTURE}/core/hooks/validate-bash.sh"
touch "${L2_FIXTURE}/core/agents/code-standards-reviewer.md"
touch "${L2_FIXTURE}/core/agents/security-analyst.md"

# L2-1: CC_PROJECT_DIR unset → grounding skipped
output=$(echo "<scope>Fix core/auth/handler.sh</scope><constraints>Do NOT skip</constraints>" | bash "$VP_SCRIPT" 2>/dev/null) || true
assert_contains "L2: skipped when CC_PROJECT_DIR unset" "$output" "Grounding: skipped"

# L2-2: CC_PROJECT_DIR set → grounding runs
output=$(echo "<scope>Fix core/auth/handler.sh</scope><constraints>Do NOT skip</constraints>" | CC_PROJECT_DIR="$L2_FIXTURE" bash "$VP_SCRIPT" 2>/dev/null) || true
assert_contains "L2: runs when CC_PROJECT_DIR set" "$output" "Grounding:"
assert_not_contains "L2: not skipped when set" "$output" "skipped"

# L2-3: Resolved path
output=$(echo "<scope>Fix core/auth/handler.sh now</scope><constraints>Do NOT skip</constraints>" | CC_PROJECT_DIR="$L2_FIXTURE" bash "$VP_SCRIPT" 2>/dev/null) || true
assert_contains "L2: resolved path counted" "$output" "1/1 references resolved"

# L2-4: Unresolved path
output=$(echo "<scope>Fix core/nonexistent/phantom.sh</scope><constraints>Do NOT skip</constraints>" | CC_PROJECT_DIR="$L2_FIXTURE" bash "$VP_SCRIPT" 2>/dev/null) || true
assert_contains "L2: unresolved path" "$output" "0/1 references resolved"

# L2-5: Mixed ratio (2 resolved + 1 unresolved)
output=$(echo "<scope>
Fix core/auth/handler.sh and core/hooks/validate-bash.sh
Also fix core/nonexistent/phantom.sh
</scope><constraints>Do NOT skip</constraints>" | CC_PROJECT_DIR="$L2_FIXTURE" bash "$VP_SCRIPT" 2>/dev/null) || true
assert_contains "L2: mixed ratio" "$output" "2/3 references resolved"

# L2-6: @agent handle resolved
output=$(echo "<scope>
Assign to @code-standards-reviewer for core/auth/handler.sh
</scope><constraints>Do NOT skip</constraints>" | CC_PROJECT_DIR="$L2_FIXTURE" bash "$VP_SCRIPT" 2>/dev/null) || true
assert_contains "L2: agent resolved" "$output" "2/2 references resolved"

# L2-7: @agent handle unresolved
output=$(echo "<scope>
Assign to @nonexistent-agent for core/auth/handler.sh
</scope><constraints>Do NOT skip</constraints>" | CC_PROJECT_DIR="$L2_FIXTURE" bash "$VP_SCRIPT" 2>/dev/null) || true
assert_contains "L2: agent unresolved" "$output" "1/2 references resolved"

# L2-8: Path traversal rejected (Constraint C)
output=$(echo "<scope>Fix ../../etc/passwd</scope><constraints>Do NOT skip</constraints>" | CC_PROJECT_DIR="$L2_FIXTURE" bash "$VP_SCRIPT" 2>/dev/null) || true
assert_contains "L2: path traversal rejected" "$output" "0/1 references resolved"

# L2-9: Leading - rejected (Constraint C)
output=$(echo "<scope>Fix -exec rm core/auth/handler.sh</scope><constraints>Do NOT skip</constraints>" | CC_PROJECT_DIR="$L2_FIXTURE" bash "$VP_SCRIPT" 2>/dev/null) || true
# -exec is not path-like (no /), so only core/auth/handler.sh is extracted
assert_contains "L2: leading dash not in refs" "$output" "1/1 references resolved"

# L2-10: Context section excluded from grounding
output=$(echo "<scope>
Fix core/nonexistent/phantom.sh
</scope>
<constraints>Do NOT skip</constraints>
<context>
core/auth/handler.sh exists here but should not be counted
</context>" | CC_PROJECT_DIR="$L2_FIXTURE" bash "$VP_SCRIPT" 2>/dev/null) || true
assert_contains "L2: context excluded" "$output" "0/1 references resolved"

# L2-11: Term cap at 20 (Constraint D)
CAP_SCOPE="<scope>"
for i in $(seq 1 25); do CAP_SCOPE="${CAP_SCOPE}
Fix core/path${i}/file${i}.sh"; done
CAP_SCOPE="${CAP_SCOPE}
</scope><constraints>Do NOT skip</constraints>"
output=$(echo "$CAP_SCOPE" | CC_PROJECT_DIR="$L2_FIXTURE" bash "$VP_SCRIPT" 2>/dev/null) || true
# Total should be 25 but resolved capped evaluation
total=$(echo "$output" | grep -oE 'Grounding: [0-9]+/[0-9]+' | grep -oE '/[0-9]+' | tr -d '/')
if [ "${total:-0}" -eq 25 ]; then _pass "L2: total counts all 25 refs"; else _fail "L2: total counts all 25 refs (got ${total:-empty})"; fi

# L2-12: Exit 0 with grounding
if echo "<scope>Fix core/auth/handler.sh</scope><constraints>Do NOT skip</constraints>" | CC_PROJECT_DIR="$L2_FIXTURE" bash "$VP_SCRIPT" > /dev/null 2>&1; then _pass "L2: exit 0 with grounding"; else _fail "L2: exit 0 with grounding"; fi

# L2-13: No file paths leaked in output (Constraint E)
output=$(echo "<scope>Fix core/auth/handler.sh</scope><constraints>Do NOT skip</constraints>" | CC_PROJECT_DIR="$L2_FIXTURE" bash "$VP_SCRIPT" 2>/dev/null) || true
assert_not_contains "L2: no fixture path in output" "$output" "$L2_FIXTURE"

# L2-14: Non-absolute CC_PROJECT_DIR → skipped
output=$(echo "<scope>Fix core/auth/handler.sh</scope><constraints>Do NOT skip</constraints>" | CC_PROJECT_DIR="relative/path" bash "$VP_SCRIPT" 2>/dev/null) || true
assert_contains "L2: non-absolute root skipped" "$output" "Grounding: skipped"

# L2-15: Symlink escape rejected (Constraint H)
# Create a symlink inside the fixture pointing outside it
_SYMLINK_TARGET=$(mktemp -d)
touch "${_SYMLINK_TARGET}/secret.sh"
ln -s "$_SYMLINK_TARGET" "${L2_FIXTURE}/core/auth/escape-link" 2>/dev/null || true
if [ -L "${L2_FIXTURE}/core/auth/escape-link" ]; then
    output=$(echo "<scope>Fix core/auth/escape-link/secret.sh</scope><constraints>Do NOT skip</constraints>" | CC_PROJECT_DIR="$L2_FIXTURE" bash "$VP_SCRIPT" 2>/dev/null) || true
    assert_contains "L2: symlink escape rejected" "$output" "0/1 references resolved"
    _pass "L2: symlink test executed"
else
    _skip "L2: symlink creation not supported"
fi
rm -rf "$_SYMLINK_TARGET"

# L2-16: Sibling directory prefix-match rejected (Constraint H hardening)
_SIBLING="${L2_FIXTURE}-evil"
mkdir -p "$_SIBLING/core/auth"
touch "$_SIBLING/core/auth/handler.sh"
ln -s "${_SIBLING}/core/auth" "${L2_FIXTURE}/core/sibling-link" 2>/dev/null || true
if [ -L "${L2_FIXTURE}/core/sibling-link" ]; then
    output=$(echo "<scope>Fix core/sibling-link/handler.sh</scope><constraints>Do NOT skip</constraints>" | CC_PROJECT_DIR="$L2_FIXTURE" bash "$VP_SCRIPT" 2>/dev/null) || true
    assert_contains "L2: sibling prefix rejected" "$output" "0/1 references resolved"
else
    _skip "L2: sibling symlink creation not supported"
fi
rm -rf "$_SIBLING"

# Cleanup fixture
rm -rf "$L2_FIXTURE"

suite_end
