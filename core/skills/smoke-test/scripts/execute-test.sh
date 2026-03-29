#!/bin/bash
# execute-test.sh — [D] Run smoke test command and validate JSON output
# Usage: ./execute-test.sh
# Outputs: validated JSON to stdout
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_smoke-lib.sh"

_st_load_config
_st_require_var "CC_SMOKE_TEST_COMMAND"

OUTPUT=$(eval "$CC_SMOKE_TEST_COMMAND" 2>/dev/null) || {
    _st_die "Smoke test command failed: ${CC_SMOKE_TEST_COMMAND}"
}

if [[ -z "$OUTPUT" ]]; then
    _st_die "Smoke test command produced no output"
fi

# Validate JSON
if command -v jq &>/dev/null; then
    if ! echo "$OUTPUT" | jq . >/dev/null 2>&1; then
        _st_die "Smoke test command did not produce valid JSON. Raw output: ${OUTPUT:0:200}"
    fi
    # Validate required fields
    TOTAL=$(echo "$OUTPUT" | jq -r '.summary.total // empty')
    if [[ -z "$TOTAL" ]]; then
        _st_die "JSON missing required field: summary.total"
    fi
else
    # Fallback: basic JSON check
    if [[ "$OUTPUT" != "{"* ]]; then
        _st_die "Output does not look like JSON (no jq available for validation)"
    fi
fi

echo "$OUTPUT"
