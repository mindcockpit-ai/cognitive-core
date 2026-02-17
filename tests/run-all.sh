#!/bin/bash
# cognitive-core test runner
# Runs all test suites in order and reports aggregate results
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

printf "\n${BOLD}${CYAN}╔══════════════════════════════════════╗${RESET}\n"
printf "${BOLD}${CYAN}║   cognitive-core test suite runner    ║${RESET}\n"
printf "${BOLD}${CYAN}╚══════════════════════════════════════╝${RESET}\n"

TOTAL_PASS=0
TOTAL_FAIL=0
FAILED_SUITES=""

# Run each suite in order
for suite in "${SCRIPT_DIR}/suites/"*.sh; do
    if [ ! -f "$suite" ]; then
        continue
    fi
    suite_name=$(basename "$suite")

    if bash "$suite"; then
        TOTAL_PASS=$((TOTAL_PASS + 1))
    else
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
        FAILED_SUITES="${FAILED_SUITES} ${suite_name}"
    fi
done

# Summary
TOTAL=$((TOTAL_PASS + TOTAL_FAIL))
printf "\n${BOLD}${CYAN}═══════════════════════════════════════${RESET}\n"
printf "${BOLD}Aggregate: %d/%d suites passed${RESET}\n" "$TOTAL_PASS" "$TOTAL"

if [ "$TOTAL_FAIL" -gt 0 ]; then
    printf "${RED}Failed suites:${RESET}%s\n" "$FAILED_SUITES"
    exit 1
else
    printf "${GREEN}All suites passed.${RESET}\n"
    exit 0
fi
