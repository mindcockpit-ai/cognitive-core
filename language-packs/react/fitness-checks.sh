#!/bin/bash
# cognitive-core language pack: React/TypeScript fitness checks
# Called by the fitness-check framework. Outputs: SCORE DESCRIPTION
# Checks React-specific quality patterns and legacy anti-patterns.
set -u

# Source shared utilities for _cc_rg (ripgrep with grep fallback)
_CC_COMMON="$(cd "$(dirname "$0")/.." && pwd)/_common.sh"
# shellcheck disable=SC1090
[ -f "$_CC_COMMON" ] && source "$_CC_COMMON"

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

# === TYPE SAFETY CHECKS ===

# --- Check 1: No 'any' type usage ---
ANY_COUNT=$(_cc_rg -n ': any\b\|<any>\|as any' "$SRC_DIR" --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v '\.d\.ts' | wc -l | tr -d ' ')
add_check "No 'any' type" "$( [ "$ANY_COUNT" -le 3 ] && echo 1 || echo 0 )" "${ANY_COUNT} any usages"

# --- Check 2: No @ts-ignore without explanation ---
TS_IGNORE=$(_cc_rg -n '@ts-ignore\|@ts-nocheck' "$SRC_DIR" --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
add_check "No @ts-ignore/@ts-nocheck" "$( [ "$TS_IGNORE" -eq 0 ] && echo 1 || echo 0 )" "${TS_IGNORE} suppressions"

# --- Check 3: TypeScript adoption (% of .tsx/.ts vs .jsx/.js) ---
TS_FILES=$(find "$SRC_DIR" -type f \( -name "*.ts" -o -name "*.tsx" \) ! -path "*/node_modules/*" ! -name "*.d.ts" 2>/dev/null | wc -l | tr -d ' ')
JS_FILES=$(find "$SRC_DIR" -type f \( -name "*.js" -o -name "*.jsx" \) ! -path "*/node_modules/*" ! -name "*.config.*" ! -name "vite.config.*" ! -name "eslint.config.*" 2>/dev/null | wc -l | tr -d ' ')
TOTAL_FILES=$((TS_FILES + JS_FILES))
if [ "$TOTAL_FILES" -gt 0 ]; then
    TS_PERCENT=$(( (TS_FILES * 100) / TOTAL_FILES ))
else
    TS_PERCENT=100
fi
add_check "TypeScript adoption >80%" "$( [ "$TS_PERCENT" -ge 80 ] && echo 1 || echo 0 )" "${TS_PERCENT}% TypeScript (${TS_FILES}ts/${JS_FILES}js)"

# === REACT PATTERN CHECKS ===

# --- Check 4: No class components ---
CLASS_COMP=$(_cc_rg -n 'extends React\.Component\|extends Component\|extends PureComponent\|extends React\.PureComponent' "$SRC_DIR" --include="*.tsx" --include="*.jsx" --include="*.ts" --include="*.js" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
add_check "No class components" "$( [ "$CLASS_COMP" -eq 0 ] && echo 1 || echo 0 )" "${CLASS_COMP} class components"

# --- Check 5: No PropTypes (use TypeScript interfaces instead) ---
PROPTYPES=$(_cc_rg -n 'PropTypes\.\|\.propTypes\s*=' "$SRC_DIR" --include="*.tsx" --include="*.jsx" --include="*.ts" --include="*.js" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
add_check "No PropTypes (use TS types)" "$( [ "$PROPTYPES" -eq 0 ] && echo 1 || echo 0 )" "${PROPTYPES} PropTypes usages"

# --- Check 6: No manual memoization (React Compiler handles it) ---
MANUAL_MEMO=$(_cc_rg -n '\buseMemo\b\|\buseCallback\b\|React\.memo(' "$SRC_DIR" --include="*.tsx" --include="*.jsx" --include="*.ts" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v '\.test\.' | grep -v '\.spec\.' | wc -l | tr -d ' ')
add_check "No manual memoization" "$( [ "$MANUAL_MEMO" -le 5 ] && echo 1 || echo 0 )" "${MANUAL_MEMO} useMemo/useCallback/React.memo"

# --- Check 7: No useEffect for data fetching ---
USE_EFFECT_FETCH=$(_cc_rg -n 'useEffect.*fetch\|useEffect.*axios\|useEffect.*api\.' "$SRC_DIR" --include="*.tsx" --include="*.jsx" --include="*.ts" --include="*.js" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
add_check "No useEffect data fetching" "$( [ "$USE_EFFECT_FETCH" -eq 0 ] && echo 1 || echo 0 )" "${USE_EFFECT_FETCH} useEffect+fetch patterns"

# --- Check 8: No direct DOM manipulation ---
DIRECT_DOM=$(_cc_rg -n 'document\.getElementById\|document\.querySelector\|document\.getElementsBy\|\.innerHTML\s*=' "$SRC_DIR" --include="*.tsx" --include="*.jsx" --include="*.ts" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v '\.test\.' | wc -l | tr -d ' ')
add_check "No direct DOM manipulation" "$( [ "$DIRECT_DOM" -eq 0 ] && echo 1 || echo 0 )" "${DIRECT_DOM} document.* calls"

# === CODE QUALITY CHECKS ===

# --- Check 9: No var usage ---
VAR_COUNT=$(_cc_rg -n '\bvar\s' "$SRC_DIR" --include="*.ts" --include="*.js" --include="*.tsx" --include="*.jsx" 2>/dev/null | grep -v node_modules | grep -v '\.d\.ts' | wc -l | tr -d ' ')
add_check "No var usage" "$( [ "$VAR_COUNT" -eq 0 ] && echo 1 || echo 0 )" "${VAR_COUNT} var declarations"

# --- Check 10: No console.log in production ---
CONSOLE_COUNT=$(_cc_rg -n 'console\.\(log\|debug\|info\)' "$SRC_DIR" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" 2>/dev/null | grep -v node_modules | grep -v '\.test\.' | grep -v '\.spec\.' | wc -l | tr -d ' ')
add_check "No console.log in prod" "$( [ "$CONSOLE_COUNT" -eq 0 ] && echo 1 || echo 0 )" "${CONSOLE_COUNT} console statements"

# --- Check 11: No barrel files (index.ts re-exports) ---
BARREL_COUNT=$(find "$SRC_DIR" \( -name "index.ts" -o -name "index.tsx" -o -name "index.js" -o -name "index.jsx" \) ! -path "*/node_modules/*" -print0 2>/dev/null | xargs -0 grep -l 'export.*from\|export {' 2>/dev/null | wc -l | tr -d ' ')
add_check "No barrel files" "$( [ "$BARREL_COUNT" -le 1 ] && echo 1 || echo 0 )" "${BARREL_COUNT} barrel index files"

# --- Check 12: No inline styles ---
INLINE_STYLE=$(_cc_rg -n 'style={{' "$SRC_DIR" --include="*.tsx" --include="*.jsx" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
add_check "No inline styles" "$( [ "$INLINE_STYLE" -le 5 ] && echo 1 || echo 0 )" "${INLINE_STYLE} inline style objects"

# === TOOLING CHECKS ===

# --- Check 13: ESLint 9 flat config (not legacy) ---
if [ -f "$PROJECT_DIR/eslint.config.mjs" ] || [ -f "$PROJECT_DIR/eslint.config.js" ] || [ -f "$PROJECT_DIR/eslint.config.ts" ]; then
    add_check "ESLint 9 flat config" 1
else
    LEGACY_ESLINT=0
    [ -f "$PROJECT_DIR/.eslintrc.json" ] || [ -f "$PROJECT_DIR/.eslintrc.js" ] || [ -f "$PROJECT_DIR/.eslintrc.yml" ] && LEGACY_ESLINT=1
    add_check "ESLint 9 flat config" 0 "$([ "$LEGACY_ESLINT" -eq 1 ] && echo 'legacy .eslintrc found' || echo 'no ESLint config')"
fi

# --- Check 14: TypeScript strict mode enabled ---
if [ -f "$PROJECT_DIR/tsconfig.json" ]; then
    STRICT=$(grep -c '"strict":\s*true' "$PROJECT_DIR/tsconfig.json" 2>/dev/null || true)
    STRICT=${STRICT:-0}
    add_check "TypeScript strict mode" "$( [ "$STRICT" -gt 0 ] && echo 1 || echo 0 )" "$([ "$STRICT" -eq 0 ] && echo 'strict not enabled')"
else
    add_check "TypeScript strict mode" 0 "no tsconfig.json"
fi

# --- Check 15: Test files exist ---
TEST_COUNT=$(find "$SRC_DIR" -type f \( -name "*.test.*" -o -name "*.spec.*" \) ! -path "*/node_modules/*" 2>/dev/null | wc -l | tr -d ' ')
COMP_COUNT=$(find "$SRC_DIR" -type f \( -name "*.tsx" -o -name "*.jsx" \) ! -path "*/node_modules/*" ! -name "*.test.*" ! -name "*.spec.*" ! -name "*.d.ts" 2>/dev/null | wc -l | tr -d ' ')
if [ "$COMP_COUNT" -gt 0 ]; then
    TEST_RATIO=$(( (TEST_COUNT * 100) / COMP_COUNT ))
else
    TEST_RATIO=100
fi
add_check "Test coverage >50% files" "$( [ "$TEST_RATIO" -ge 50 ] && echo 1 || echo 0 )" "${TEST_COUNT} tests / ${COMP_COUNT} components (${TEST_RATIO}%)"

# --- Check 16: No Create React App (CRA) ---
CRA=$(grep -c 'react-scripts' "$PROJECT_DIR/package.json" 2>/dev/null || true)
CRA=${CRA:-0}
add_check "No CRA (use Vite/Next)" "$( [ "$CRA" -eq 0 ] && echo 1 || echo 0 )" "$([ "$CRA" -gt 0 ] && echo 'react-scripts found in package.json')"

# --- Check 17: No require() in TS/TSX ---
REQUIRE_COUNT=$(_cc_rg -n '\brequire(' "$SRC_DIR" --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v '\.d\.ts' | wc -l | tr -d ' ')
add_check "ES imports (no require)" "$( [ "$REQUIRE_COUNT" -eq 0 ] && echo 1 || echo 0 )" "${REQUIRE_COUNT} require() calls"

# --- Check 18: No jQuery ---
JQUERY=$(_cc_rg -n '\$(\|\bjQuery\b' "$SRC_DIR" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
add_check "No jQuery" "$( [ "$JQUERY" -eq 0 ] && echo 1 || echo 0 )" "${JQUERY} jQuery usages"

# Calculate score
if [ "$TOTAL_CHECKS" -gt 0 ]; then
    SCORE=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
else
    SCORE=50
fi

DETAILS="${DETAILS%; }"

echo "$SCORE ${PASSED_CHECKS}/${TOTAL_CHECKS} React checks passed${DETAILS:+. $DETAILS}"
