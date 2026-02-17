#!/bin/bash
# Test suite: ShellCheck all .sh files
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "01 — ShellCheck"

if ! command -v shellcheck &>/dev/null; then
    _skip "shellcheck not installed"
    suite_end || true
    exit 0
fi

# Find all .sh files in core/ and tests/ (exclude node_modules, .git, landing)
while IFS= read -r script; do
    rel="${script#${ROOT_DIR}/}"
    output=$(shellcheck -S warning "$script" 2>&1) || true
    if [ -z "$output" ]; then
        _pass "shellcheck: ${rel}"
    else
        error_count=$(echo "$output" | grep -c "^In " || echo "0")
        _fail "shellcheck: ${rel} (${error_count} issue(s))"
        echo "$output" | head -20
    fi
done < <(find "${ROOT_DIR}/core" "${ROOT_DIR}/tests" "${ROOT_DIR}/install.sh" "${ROOT_DIR}/update.sh" \
    -name "*.sh" -type f 2>/dev/null | sort)

suite_end
