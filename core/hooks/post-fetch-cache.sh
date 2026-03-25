#!/bin/bash
# cognitive-core hook: PostToolUse (WebFetch)
# Caches the domain in session cache after a successful fetch.
# This enables the "don't ask again" behavior: once a user allows a domain,
# the PreToolUse hook (validate-fetch.sh) finds it cached and skips the prompt.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"
_cc_load_config

# Read stdin JSON
INPUT=$(cat)

URL=$(echo "$INPUT" | _cc_json_get ".tool_input.url")
if [ -z "$URL" ]; then
    exit 0
fi

# Extract domain from URL
DOMAIN=$(echo "$URL" | sed -E 's|^https?://||;s|/.*||;s|:.*||')

# Cache the domain so subsequent fetches are not re-prompted
_cc_session_cache_add "allowed-domains" "$DOMAIN"

exit 0
