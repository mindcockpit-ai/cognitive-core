#!/bin/bash
# cognitive-core language pack: Node.js fitness checks
# Called by the fitness-check framework. Outputs: SCORE DESCRIPTION
# Checks Node.js/TypeScript-specific quality patterns.
set -euo pipefail

PROJECT_DIR="${1:-.}"
SRC_DIR="$PROJECT_DIR/src"
[ ! -d "$SRC_DIR" ] && SRC_DIR="$PROJECT_DIR"

TOTAL_CHECKS=0
PASSED_CHECKS=0
DETAILS=""

add_check() {
    local name="$1" passed="$2" detail="${3:-}"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [ "$passed" -eq 1 ]; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        DETAILS="${DETAILS}FAIL: ${name}${detail:+ ($detail)}; "
    fi
}

# --- Check 1: No var usage ---
VAR_COUNT=$(grep -rn '\bvar\s' "$SRC_DIR" --include="*.ts" --include="*.js" --include="*.tsx" --include="*.jsx" 2>/dev/null | grep -v 'node_modules' | grep -v '\.d\.ts' | wc -l | tr -d ' ')
add_check "No var usage" "$( [ "$VAR_COUNT" -eq 0 ] && echo 1 || echo 0 )" "${VAR_COUNT} var declarations"

# --- Check 2: No console.log in production code ---
CONSOLE_COUNT=$(grep -rn 'console\.\(log\|debug\|info\)' "$SRC_DIR" --include="*.ts" --include="*.js" 2>/dev/null | grep -v 'node_modules' | grep -v '\.test\.' | grep -v '\.spec\.' | wc -l | tr -d ' ')
add_check "No console.log in prod" "$( [ "$CONSOLE_COUNT" -eq 0 ] && echo 1 || echo 0 )" "${CONSOLE_COUNT} console statements"

# --- Check 3: No any type ---
ANY_COUNT=$(grep -rn ': any\b\|<any>' "$SRC_DIR" --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v 'node_modules' | grep -v '\.d\.ts' | wc -l | tr -d ' ')
add_check "No 'any' type" "$( [ "$ANY_COUNT" -le 3 ] && echo 1 || echo 0 )" "${ANY_COUNT} any usages"

# --- Check 4: Async error handling ---
UNHANDLED=$(grep -rn '\.then(' "$SRC_DIR" --include="*.ts" --include="*.js" 2>/dev/null | grep -v 'node_modules' | grep -v '\.catch' | wc -l | tr -d ' ')
add_check "Promise error handling" "$( [ "$UNHANDLED" -le 2 ] && echo 1 || echo 0 )" "${UNHANDLED} unhandled .then() chains"

# --- Check 5: No require() in TS ---
REQUIRE_COUNT=$(grep -rn '\brequire(' "$SRC_DIR" --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v 'node_modules' | grep -v '\.d\.ts' | wc -l | tr -d ' ')
add_check "ES imports (no require)" "$( [ "$REQUIRE_COUNT" -eq 0 ] && echo 1 || echo 0 )" "${REQUIRE_COUNT} require() calls"

# --- Check 6: Strict equality ---
LOOSE_EQ=$(grep -rn '[^!=]=[^=]' "$SRC_DIR" --include="*.ts" --include="*.js" 2>/dev/null | grep -v 'node_modules' | grep -c '==[^=]' || echo 0)
add_check "Strict equality (===)" "$( [ "$LOOSE_EQ" -le 2 ] && echo 1 || echo 0 )" "${LOOSE_EQ} loose equality checks"

# Calculate score
if [ "$TOTAL_CHECKS" -gt 0 ]; then
    SCORE=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
else
    SCORE=50
fi

DETAILS="${DETAILS%; }"

echo "$SCORE ${PASSED_CHECKS}/${TOTAL_CHECKS} Node.js checks passed${DETAILS:+. $DETAILS}"
