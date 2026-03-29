#!/bin/bash
# preflight.sh — [D] Verify server is reachable and config is valid
# Usage: ./preflight.sh
# Exit 0 = ready, Exit 1 = not ready
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_smoke-lib.sh"

_st_load_config
_st_require_var "CC_SMOKE_TEST_COMMAND"
_st_require_var "CC_SMOKE_TEST_URL"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$CC_SMOKE_TEST_URL" 2>/dev/null || echo "000")

if [[ "$HTTP_CODE" == "000" ]]; then
    _st_die "Server not reachable at ${CC_SMOKE_TEST_URL}. Start the server first."
fi

_st_info "Server reachable at ${CC_SMOKE_TEST_URL} (HTTP ${HTTP_CODE})"
echo "{\"status\":\"ok\",\"url\":\"${CC_SMOKE_TEST_URL}\",\"http_code\":\"${HTTP_CODE}\"}"
