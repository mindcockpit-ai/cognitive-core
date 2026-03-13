#!/bin/bash
# cognitive-core hook: PreToolUse (WebFetch|WebSearch)
# Audit logging for external URL access + domain filtering in strict mode
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"
_cc_load_config

# Read stdin JSON
INPUT=$(cat)

# Extract URL from tool input (WebFetch uses "url", WebSearch uses "query")
URL=$(echo "$INPUT" | _cc_json_get ".tool_input.url")
QUERY=$(echo "$INPUT" | _cc_json_get ".tool_input.query")

# For WebSearch, just log and allow — no domain filtering on search queries
if [ -n "$QUERY" ] && [ -z "$URL" ]; then
    _cc_security_log "INFO" "web-search" "query=${QUERY}"
    exit 0
fi

if [ -z "$URL" ]; then
    exit 0
fi

# Extract domain from URL
DOMAIN=$(echo "$URL" | sed -E 's|^https?://||;s|/.*||;s|:.*||')

# Always log the fetch for audit trail
_cc_security_log "INFO" "web-fetch" "url=${URL} domain=${DOMAIN}"

_SECURITY_LEVEL="${CC_SECURITY_LEVEL:-standard}"

# Known-safe domains (never blocked, never escalated)
_KNOWN_SAFE="github.com,raw.githubusercontent.com,stackoverflow.com,docs.python.org,docs.rs,pkg.go.dev,developer.mozilla.org,nodejs.org,crates.io,pypi.org,npmjs.com,maven.org,rubygems.org,learn.microsoft.com,man7.org,wiki.archlinux.org"

is_known_safe() {
    local d="$1"
    echo "${_KNOWN_SAFE},${CC_KNOWN_SAFE_DOMAINS:-}" | tr ',' '\n' | grep -qxF "$d"
}

# Strict mode: only allow explicitly allowlisted domains
if [ "$_SECURITY_LEVEL" = "strict" ] && [ -n "${CC_ALLOWED_DOMAINS:-}" ]; then
    allowed=false
    for d in $(echo "$CC_ALLOWED_DOMAINS" | tr ',' ' '); do
        if [ "$d" = "$DOMAIN" ]; then
            allowed=true
            break
        fi
    done
    if ! $allowed; then
        REASON="Blocked: domain '${DOMAIN}' not in CC_ALLOWED_DOMAINS (strict mode)"
        _cc_security_log "DENY" "fetch-blocked" "${REASON}"
        _cc_json_pretool_deny "$REASON"
        exit 0
    fi
fi

# Standard mode: escalate unknown domains to human (ask)
if [ "$_SECURITY_LEVEL" = "standard" ]; then
    if ! is_known_safe "$DOMAIN"; then
        _cc_security_log "ASK" "fetch-unknown-domain" "domain=${DOMAIN} url=${URL}"
        _cc_json_pretool_ask "WebFetch to unknown domain '${DOMAIN}'. Allow this request?"
        exit 0
    fi
fi

exit 0
