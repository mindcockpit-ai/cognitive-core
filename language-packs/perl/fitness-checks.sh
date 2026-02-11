#!/bin/bash
# cognitive-core language pack: Perl fitness checks
# Called by the fitness-check framework. Outputs: SCORE DESCRIPTION
# Checks Perl-specific quality patterns.
set -euo pipefail

PROJECT_DIR="${1:-.}"
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

# --- Check 1: Moose usage in lib/ modules ---
MOOSE_MISSING=0
while IFS= read -r pm_file; do
    # Skip non-OO utility files
    if grep -q 'sub new\|has ' "$pm_file" 2>/dev/null || grep -q 'extends\|with ' "$pm_file" 2>/dev/null; then
        if ! grep -q 'use Moose\|use Moo\b' "$pm_file" 2>/dev/null; then
            MOOSE_MISSING=$((MOOSE_MISSING + 1))
        fi
    fi
done < <(find "$PROJECT_DIR/lib" -name "*.pm" -type f 2>/dev/null)
add_check "Moose/Moo for OO modules" "$( [ "$MOOSE_MISSING" -eq 0 ] && echo 1 || echo 0 )" "${MOOSE_MISSING} modules missing Moose/Moo"

# --- Check 2: namespace::autoclean ---
AUTOCLEAN_MISSING=0
while IFS= read -r pm_file; do
    if grep -q 'use Moose' "$pm_file" 2>/dev/null; then
        if ! grep -q 'namespace::autoclean\|namespace::clean' "$pm_file" 2>/dev/null; then
            AUTOCLEAN_MISSING=$((AUTOCLEAN_MISSING + 1))
        fi
    fi
done < <(find "$PROJECT_DIR/lib" -name "*.pm" -type f 2>/dev/null)
add_check "namespace::autoclean" "$( [ "$AUTOCLEAN_MISSING" -eq 0 ] && echo 1 || echo 0 )" "${AUTOCLEAN_MISSING} Moose modules missing autoclean"

# --- Check 3: No HashRefInflator ---
HRI_COUNT=$(grep -rl 'HashRefInflator' "$PROJECT_DIR/lib" 2>/dev/null | wc -l | tr -d ' ')
add_check "No HashRefInflator" "$( [ "$HRI_COUNT" -eq 0 ] && echo 1 || echo 0 )" "${HRI_COUNT} files use HashRefInflator"

# --- Check 4: Safe DateTime usage ---
NOW_STRING_COUNT=$(grep -rn "now()" "$PROJECT_DIR/lib" --include="*.pm" 2>/dev/null | grep -v 'DateTime->now' | grep -c 'now()' || echo 0)
add_check "Safe DateTime (no now() strings)" "$( [ "$NOW_STRING_COUNT" -eq 0 ] && echo 1 || echo 0 )" "${NOW_STRING_COUNT} unsafe now() calls"

# --- Check 5: No bare eval ---
EVAL_COUNT=$(grep -rn '\beval\s*{' "$PROJECT_DIR/lib" --include="*.pm" 2>/dev/null | grep -v 'Try::Tiny' | wc -l | tr -d ' ')
add_check "No bare eval (use Try::Tiny)" "$( [ "$EVAL_COUNT" -eq 0 ] && echo 1 || echo 0 )" "${EVAL_COUNT} bare eval blocks"

# --- Check 6: strict/warnings ---
STRICT_MISSING=0
while IFS= read -r pm_file; do
    if ! grep -q 'use strict' "$pm_file" 2>/dev/null; then
        STRICT_MISSING=$((STRICT_MISSING + 1))
    fi
done < <(find "$PROJECT_DIR/lib" -name "*.pm" -type f 2>/dev/null)
add_check "use strict in all modules" "$( [ "$STRICT_MISSING" -eq 0 ] && echo 1 || echo 0 )" "${STRICT_MISSING} modules missing strict"

# Calculate score
if [ "$TOTAL_CHECKS" -gt 0 ]; then
    SCORE=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
else
    SCORE=50
fi

# Trim trailing separator from details
DETAILS="${DETAILS%; }"

echo "$SCORE ${PASSED_CHECKS}/${TOTAL_CHECKS} Perl checks passed${DETAILS:+. $DETAILS}"
