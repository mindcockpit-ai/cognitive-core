#!/bin/bash
# cognitive-core language pack: Python fitness checks (3.12+)
# Called by the fitness-check framework. Outputs: SCORE DESCRIPTION
# Checks Python-specific quality patterns.
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

# --- Check 1: Type hints in function definitions ---
FUNC_COUNT=$(grep -rn 'def ' "$SRC_DIR" --include="*.py" 2>/dev/null | grep -v '__pycache__' | wc -l | tr -d ' ')
TYPED_COUNT=$(grep -rn 'def .*->.*:' "$SRC_DIR" --include="*.py" 2>/dev/null | grep -v '__pycache__' | wc -l | tr -d ' ')
if [ "$FUNC_COUNT" -gt 0 ]; then
    RATIO=$(( (TYPED_COUNT * 100) / FUNC_COUNT ))
    add_check "Type hints on functions" "$( [ "$RATIO" -ge 70 ] && echo 1 || echo 0 )" "${TYPED_COUNT}/${FUNC_COUNT} typed (${RATIO}%)"
else
    add_check "Type hints on functions" 1 "no functions found"
fi

# --- Check 2: No bare except ---
BARE_EXCEPT=$(grep -rn 'except:' "$SRC_DIR" --include="*.py" 2>/dev/null | grep -v '__pycache__' | wc -l | tr -d ' ')
add_check "No bare except" "$( [ "$BARE_EXCEPT" -eq 0 ] && echo 1 || echo 0 )" "${BARE_EXCEPT} bare except blocks"

# --- Check 3: No os.path usage (prefer pathlib) ---
OSPATH_COUNT=$(grep -rn 'os\.path\.' "$SRC_DIR" --include="*.py" 2>/dev/null | grep -v '__pycache__' | wc -l | tr -d ' ')
add_check "Pathlib over os.path" "$( [ "$OSPATH_COUNT" -eq 0 ] && echo 1 || echo 0 )" "${OSPATH_COUNT} os.path usages"

# --- Check 4: No mutable default arguments ---
MUTABLE_DEFAULTS=$(grep -rn 'def .*=\s*\[\]\|def .*=\s*{}\|def .*=\s*set()' "$SRC_DIR" --include="*.py" 2>/dev/null | grep -v '__pycache__' | wc -l | tr -d ' ')
add_check "No mutable default args" "$( [ "$MUTABLE_DEFAULTS" -eq 0 ] && echo 1 || echo 0 )" "${MUTABLE_DEFAULTS} mutable defaults"

# --- Check 5: Import ordering (ruff isort) ---
IMPORT_ISSUES=0
if command -v ruff &>/dev/null; then
    IMPORT_ISSUES=$(ruff check --select I "$SRC_DIR" 2>/dev/null | wc -l | tr -d ' ')
fi
add_check "Import ordering (isort)" "$( [ "$IMPORT_ISSUES" -eq 0 ] && echo 1 || echo 0 )" "${IMPORT_ISSUES} import issues"

# --- Check 6: Pydantic v2 style (no class Config:) ---
OLD_PYDANTIC=$(grep -rn 'class Config:' "$SRC_DIR" --include="*.py" 2>/dev/null | grep -v '__pycache__' | grep -v 'pydantic_settings\|BaseSettings' | wc -l | tr -d ' ')
add_check "Pydantic v2 ConfigDict" "$( [ "$OLD_PYDANTIC" -eq 0 ] && echo 1 || echo 0 )" "${OLD_PYDANTIC} old-style class Config"

# --- Check 7: No sync I/O in async functions ---
# Detects common sync calls inside async defs (requests.get, open(), time.sleep)
SYNC_IN_ASYNC=0
if [ "$FUNC_COUNT" -gt 0 ]; then
    # Look for requests.get/post, time.sleep, open() near async def
    SYNC_IN_ASYNC=$(grep -rn 'requests\.\(get\|post\|put\|delete\|patch\)\|time\.sleep\b' "$SRC_DIR" --include="*.py" 2>/dev/null | grep -v '__pycache__' | grep -v '^.*#' | wc -l | tr -d ' ')
fi
add_check "No sync I/O patterns" "$( [ "$SYNC_IN_ASYNC" -eq 0 ] && echo 1 || echo 0 )" "${SYNC_IN_ASYNC} sync I/O calls"

# --- Check 8: No Optional[] (prefer X | None) ---
OLD_OPTIONAL=$(grep -rn 'Optional\[' "$SRC_DIR" --include="*.py" 2>/dev/null | grep -v '__pycache__' | grep -v 'TYPE_CHECKING' | wc -l | tr -d ' ')
add_check "Modern union syntax (X | None)" "$( [ "$OLD_OPTIONAL" -le 3 ] && echo 1 || echo 0 )" "${OLD_OPTIONAL} Optional[] usages"

# --- Check 9: Async context managers for DB sessions ---
# Check for proper 'async with' usage (good sign of resource management)
ASYNC_WITH=$(grep -rn 'async with' "$SRC_DIR" --include="*.py" 2>/dev/null | grep -v '__pycache__' | wc -l | tr -d ' ')
ASYNC_FUNCS=$(grep -rn 'async def' "$SRC_DIR" --include="*.py" 2>/dev/null | grep -v '__pycache__' | wc -l | tr -d ' ')
if [ "$ASYNC_FUNCS" -gt 5 ]; then
    add_check "Async context managers" "$( [ "$ASYNC_WITH" -gt 0 ] && echo 1 || echo 0 )" "${ASYNC_WITH} async with blocks"
else
    add_check "Async context managers" 1 "few async functions"
fi

# Calculate score
if [ "$TOTAL_CHECKS" -gt 0 ]; then
    SCORE=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
else
    SCORE=50
fi

DETAILS="${DETAILS%; }"

echo "$SCORE ${PASSED_CHECKS}/${TOTAL_CHECKS} Python checks passed${DETAILS:+. $DETAILS}"
