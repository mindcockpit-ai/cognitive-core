#!/bin/bash
# cognitive-core language pack: Node.js fitness checks
# Called by the fitness-check framework. Outputs: SCORE DESCRIPTION
# Checks Node.js/TypeScript-specific quality patterns.
set -euo pipefail

# Source shared utilities for _cc_rg (ripgrep with grep fallback)
_CC_COMMON="$(cd "$(dirname "$0")/.." && pwd)/_common.sh"
# shellcheck disable=SC1090
[ -f "$_CC_COMMON" ] && source "$_CC_COMMON"

PROJECT_DIR="${1:-.}"
SRC_DIR="$PROJECT_DIR/src"
[ ! -d "$SRC_DIR" ] && SRC_DIR="$PROJECT_DIR"

_cc_fitness_init
add_check() { _cc_fitness_check "$@"; }

# --- Check 1: No var usage ---
VAR_COUNT=$(_cc_rg -n '\bvar\s' "$SRC_DIR" --include="*.ts" --include="*.js" --include="*.tsx" --include="*.jsx" 2>/dev/null | grep -v node_modules | grep -v '\.d\.ts' | wc -l | tr -d ' ')
add_check "No var usage" "$( [ "$VAR_COUNT" -eq 0 ] && echo 1 || echo 0 )" "${VAR_COUNT} var declarations"

# --- Check 2: No console.log in production code ---
CONSOLE_COUNT=$(_cc_rg -n 'console\.\(log\|debug\|info\)' "$SRC_DIR" --include="*.ts" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v '\.test\.' | grep -v '\.spec\.' | wc -l | tr -d ' ')
add_check "No console.log in prod" "$( [ "$CONSOLE_COUNT" -eq 0 ] && echo 1 || echo 0 )" "${CONSOLE_COUNT} console statements"

# --- Check 3: No any type ---
ANY_COUNT=$(_cc_rg -n ': any\b\|<any>' "$SRC_DIR" --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v '\.d\.ts' | wc -l | tr -d ' ')
add_check "No 'any' type" "$( [ "$ANY_COUNT" -le 3 ] && echo 1 || echo 0 )" "${ANY_COUNT} any usages"

# --- Check 4: Async error handling ---
UNHANDLED=$(_cc_rg -n '\.then(' "$SRC_DIR" --include="*.ts" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v '\.catch' | wc -l | tr -d ' ')
add_check "Promise error handling" "$( [ "$UNHANDLED" -le 2 ] && echo 1 || echo 0 )" "${UNHANDLED} unhandled .then() chains"

# --- Check 5: No require() in TS ---
REQUIRE_COUNT=$(_cc_rg -n '\brequire(' "$SRC_DIR" --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v '\.d\.ts' | wc -l | tr -d ' ')
add_check "ES imports (no require)" "$( [ "$REQUIRE_COUNT" -eq 0 ] && echo 1 || echo 0 )" "${REQUIRE_COUNT} require() calls"

# --- Check 6: Strict equality ---
LOOSE_EQ=$(_cc_rg -n '[^!=]=[^=]' "$SRC_DIR" --include="*.ts" --include="*.js" 2>/dev/null | grep -v node_modules | grep -c '==[^=]' || echo 0)
add_check "Strict equality (===)" "$( [ "$LOOSE_EQ" -le 2 ] && echo 1 || echo 0 )" "${LOOSE_EQ} loose equality checks"

_cc_fitness_result "js checks"
