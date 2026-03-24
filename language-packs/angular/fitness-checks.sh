#!/bin/bash
# cognitive-core language pack: Angular fitness checks
# Called by the fitness-check framework. Outputs: SCORE DESCRIPTION
# Checks Angular-specific quality patterns and legacy anti-patterns.
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
ANY_COUNT=$(_cc_rg -n ': any\b\|<any>\|as any' "$SRC_DIR" --include="*.ts" 2>/dev/null | grep -v 'node_modules' | grep -v '\.d\.ts' | grep -v '\.spec\.ts' | wc -l | tr -d ' ')
add_check "No 'any' type" "$( [ "$ANY_COUNT" -le 3 ] && echo 1 || echo 0 )" "${ANY_COUNT} any usages"

# --- Check 2: No @ts-ignore without explanation ---
TS_IGNORE=$(_cc_rg -n '@ts-ignore\|@ts-nocheck' "$SRC_DIR" --include="*.ts" 2>/dev/null | grep -v 'node_modules' | wc -l | tr -d ' ')
add_check "No @ts-ignore/@ts-nocheck" "$( [ "$TS_IGNORE" -eq 0 ] && echo 1 || echo 0 )" "${TS_IGNORE} suppressions"

# --- Check 3: TypeScript strict mode enabled ---
if [ -f "$PROJECT_DIR/tsconfig.json" ]; then
    STRICT=$(grep -c '"strict":[[:space:]]*true' "$PROJECT_DIR/tsconfig.json" 2>/dev/null || true)
    STRICT=${STRICT:-0}
    add_check "TypeScript strict mode" "$( [ "$STRICT" -gt 0 ] && echo 1 || echo 0 )" "$([ "$STRICT" -eq 0 ] && echo 'strict not enabled')"
else
    add_check "TypeScript strict mode" 0 "no tsconfig.json"
fi

# === ANGULAR PATTERN CHECKS ===

# --- Check 4: No NgModules in feature code ---
NGMODULE_COUNT=$(_cc_rg -n '@NgModule' "$SRC_DIR" --include="*.ts" 2>/dev/null | grep -v 'node_modules' | grep -v 'app\.module\.ts' | grep -v 'app\.config\.ts' | wc -l | tr -d ' ')
add_check "No NgModules in features" "$( [ "$NGMODULE_COUNT" -le 1 ] && echo 1 || echo 0 )" "${NGMODULE_COUNT} NgModule declarations"

# --- Check 5: Standalone components adopted ---
STANDALONE_COUNT=$(_cc_rg -n 'standalone:[[:space:]]*true' "$SRC_DIR" --include="*.ts" 2>/dev/null | grep -v 'node_modules' | wc -l | tr -d ' ')
COMPONENT_COUNT=$(_cc_rg -n '@Component' "$SRC_DIR" --include="*.ts" 2>/dev/null | grep -v 'node_modules' | wc -l | tr -d ' ')
if [ "$COMPONENT_COUNT" -gt 0 ]; then
    STANDALONE_PERCENT=$(( (STANDALONE_COUNT * 100) / COMPONENT_COUNT ))
else
    STANDALONE_PERCENT=100
fi
# v19+ components are standalone by default, so count is valid even without explicit flag
add_check "Standalone components >80%" "$( [ "$STANDALONE_PERCENT" -ge 80 ] || [ "$NGMODULE_COUNT" -eq 0 ] && echo 1 || echo 0 )" "${STANDALONE_PERCENT}% standalone (${STANDALONE_COUNT}/${COMPONENT_COUNT})"

# --- Check 6: Built-in control flow (no legacy structural directives) ---
LEGACY_DIRECTIVES=$(_cc_rg -n '\*ngIf\|\*ngFor\|\*ngSwitch' "$SRC_DIR" --include="*.ts" --include="*.html" 2>/dev/null | grep -v 'node_modules' | wc -l | tr -d ' ')
add_check "Built-in control flow (@if/@for)" "$( [ "$LEGACY_DIRECTIVES" -le 5 ] && echo 1 || echo 0 )" "${LEGACY_DIRECTIVES} legacy directives"

# --- Check 7: Signals over decorators ---
SIGNAL_API=$(_cc_rg -n 'signal(\|computed(\|input(\|input\.required(\|output(\|model(' "$SRC_DIR" --include="*.ts" 2>/dev/null | grep -v 'node_modules' | grep -v '\.spec\.ts' | wc -l | tr -d ' ')
DECORATOR_API=$(_cc_rg -n '@Input(\|@Output(' "$SRC_DIR" --include="*.ts" 2>/dev/null | grep -v 'node_modules' | grep -v '\.spec\.ts' | wc -l | tr -d ' ')
TOTAL_IO=$((SIGNAL_API + DECORATOR_API))
if [ "$TOTAL_IO" -gt 0 ]; then
    SIGNAL_PERCENT=$(( (SIGNAL_API * 100) / TOTAL_IO ))
else
    SIGNAL_PERCENT=100
fi
add_check "Signals over decorators >50%" "$( [ "$SIGNAL_PERCENT" -ge 50 ] && echo 1 || echo 0 )" "${SIGNAL_PERCENT}% signals (${SIGNAL_API} signal/${DECORATOR_API} decorator)"

# --- Check 8: inject() over constructor DI ---
INJECT_COUNT=$(_cc_rg -n 'inject(' "$SRC_DIR" --include="*.ts" 2>/dev/null | grep -v 'node_modules' | grep -v '\.spec\.ts' | grep -v 'TestBed' | wc -l | tr -d ' ')
CONSTRUCTOR_DI=$(_cc_rg -n 'constructor(' "$SRC_DIR" --include="*.ts" 2>/dev/null | grep -v 'node_modules' | grep -v '\.spec\.ts' | grep -v '\.d\.ts' | wc -l | tr -d ' ')
TOTAL_DI=$((INJECT_COUNT + CONSTRUCTOR_DI))
if [ "$TOTAL_DI" -gt 0 ]; then
    INJECT_PERCENT=$(( (INJECT_COUNT * 100) / TOTAL_DI ))
else
    INJECT_PERCENT=100
fi
add_check "inject() over constructor DI >50%" "$( [ "$INJECT_PERCENT" -ge 50 ] && echo 1 || echo 0 )" "${INJECT_PERCENT}% inject() (${INJECT_COUNT}/${TOTAL_DI})"

# --- Check 9: OnPush change detection ---
ONPUSH_COUNT=$(_cc_rg -n 'ChangeDetectionStrategy.OnPush' "$SRC_DIR" --include="*.ts" 2>/dev/null | grep -v 'node_modules' | wc -l | tr -d ' ')
if [ "$COMPONENT_COUNT" -gt 0 ]; then
    ONPUSH_PERCENT=$(( (ONPUSH_COUNT * 100) / COMPONENT_COUNT ))
else
    ONPUSH_PERCENT=100
fi
add_check "OnPush change detection >80%" "$( [ "$ONPUSH_PERCENT" -ge 80 ] && echo 1 || echo 0 )" "${ONPUSH_PERCENT}% OnPush (${ONPUSH_COUNT}/${COMPONENT_COUNT})"

# --- Check 10: No manual subscribe leaks ---
SUBSCRIBE_RAW=$(_cc_rg -n '\.subscribe(' "$SRC_DIR" --include="*.ts" 2>/dev/null | grep -v 'node_modules' | grep -v '\.spec\.ts' | wc -l | tr -d ' ')
SUBSCRIBE_SAFE=$(_cc_rg -n 'takeUntilDestroyed\|takeUntil\|firstValueFrom\|lastValueFrom\|toSignal(' "$SRC_DIR" --include="*.ts" 2>/dev/null | grep -v 'node_modules' | grep -v '\.spec\.ts' | wc -l | tr -d ' ')
SUBSCRIBE_UNSAFE=$((SUBSCRIBE_RAW - SUBSCRIBE_SAFE))
[ "$SUBSCRIBE_UNSAFE" -lt 0 ] && SUBSCRIBE_UNSAFE=0
add_check "No unmanaged subscribes" "$( [ "$SUBSCRIBE_UNSAFE" -le 5 ] && echo 1 || echo 0 )" "${SUBSCRIBE_UNSAFE} unmanaged subscribes"

# === CODE QUALITY CHECKS ===

# --- Check 11: No var usage ---
VAR_COUNT=$(_cc_rg -n '\bvar\s' "$SRC_DIR" --include="*.ts" 2>/dev/null | grep -v 'node_modules' | grep -v '\.d\.ts' | wc -l | tr -d ' ')
add_check "No var usage" "$( [ "$VAR_COUNT" -eq 0 ] && echo 1 || echo 0 )" "${VAR_COUNT} var declarations"

# --- Check 12: No console.log in production ---
CONSOLE_COUNT=$(_cc_rg -n 'console\.\(log\|debug\|info\)' "$SRC_DIR" --include="*.ts" 2>/dev/null | grep -v 'node_modules' | grep -v '\.spec\.ts' | wc -l | tr -d ' ')
add_check "No console.log in prod" "$( [ "$CONSOLE_COUNT" -eq 0 ] && echo 1 || echo 0 )" "${CONSOLE_COUNT} console statements"

# --- Check 13: No jQuery ---
JQUERY=$(_cc_rg -n '\$(\|\bjQuery\b' "$SRC_DIR" --include="*.ts" --include="*.html" 2>/dev/null | grep -v 'node_modules' | wc -l | tr -d ' ')
add_check "No jQuery" "$( [ "$JQUERY" -eq 0 ] && echo 1 || echo 0 )" "${JQUERY} jQuery usages"

# === TOOLING CHECKS ===

# --- Check 14: ESLint config exists ---
if [ -f "$PROJECT_DIR/eslint.config.mjs" ] || [ -f "$PROJECT_DIR/eslint.config.js" ] || [ -f "$PROJECT_DIR/eslint.config.ts" ]; then
    add_check "ESLint config exists" 1
elif grep -q 'angular-eslint' "$PROJECT_DIR/package.json" 2>/dev/null; then
    add_check "ESLint config exists" 1 "angular-eslint in package.json"
else
    add_check "ESLint config exists" 0 "no ESLint or angular-eslint found"
fi

# --- Check 15: Test files exist (>50% coverage) ---
TEST_COUNT=$(find "$SRC_DIR" -type f -name "*.spec.ts" ! -path "*/node_modules/*" 2>/dev/null | wc -l | tr -d ' ')
SOURCE_COUNT=$(find "$SRC_DIR" -type f -name "*.ts" ! -name "*.spec.ts" ! -name "*.d.ts" ! -path "*/node_modules/*" ! -name "*.config.*" ! -name "*.module.ts" 2>/dev/null | wc -l | tr -d ' ')
if [ "$SOURCE_COUNT" -gt 0 ]; then
    TEST_RATIO=$(( (TEST_COUNT * 100) / SOURCE_COUNT ))
else
    TEST_RATIO=100
fi
add_check "Test coverage >50% files" "$( [ "$TEST_RATIO" -ge 50 ] && echo 1 || echo 0 )" "${TEST_COUNT} specs / ${SOURCE_COUNT} sources (${TEST_RATIO}%)"

# --- Check 16: No Protractor (deprecated) ---
PROTRACTOR=$(grep -c 'protractor' "$PROJECT_DIR/package.json" 2>/dev/null || true)
PROTRACTOR=${PROTRACTOR:-0}
add_check "No Protractor (use Playwright)" "$( [ "$PROTRACTOR" -eq 0 ] && echo 1 || echo 0 )" "$([ "$PROTRACTOR" -gt 0 ] && echo 'protractor found in package.json')"

# --- Check 17: No require() in TS ---
REQUIRE_COUNT=$(_cc_rg -n '\brequire(' "$SRC_DIR" --include="*.ts" 2>/dev/null | grep -v 'node_modules' | grep -v '\.d\.ts' | wc -l | tr -d ' ')
add_check "ES imports (no require)" "$( [ "$REQUIRE_COUNT" -eq 0 ] && echo 1 || echo 0 )" "${REQUIRE_COUNT} require() calls"

# --- Check 18: Angular version >= 18 ---
if [ -f "$PROJECT_DIR/package.json" ]; then
    NG_VERSION=$(grep '"@angular/core"' "$PROJECT_DIR/package.json" 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)
    NG_VERSION=${NG_VERSION:-0}
    add_check "Angular version >=18" "$( [ "$NG_VERSION" -ge 18 ] && echo 1 || echo 0 )" "v${NG_VERSION}"
else
    add_check "Angular version >=18" 0 "no package.json"
fi

# Calculate score
if [ "$TOTAL_CHECKS" -gt 0 ]; then
    SCORE=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
else
    SCORE=50
fi

DETAILS="${DETAILS%; }"

echo "$SCORE ${PASSED_CHECKS}/${TOTAL_CHECKS} Angular checks passed${DETAILS:+. $DETAILS}"
