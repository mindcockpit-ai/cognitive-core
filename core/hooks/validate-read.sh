#!/bin/bash
# cognitive-core hook: PreToolUse (Read)
# Prevents reading sensitive files that should never be accessed by the agent
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"
_cc_load_config

# Read stdin JSON
INPUT=$(cat)

# Extract file_path from tool input
FILE_PATH=$(echo "$INPUT" | _cc_json_get ".tool_input.file_path")

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# CTF exception: if CC_SKILLS contains "ctf-pentesting", skip checks
# CTF work legitimately needs to read sensitive files on target systems
if echo "${CC_SKILLS:-}" | grep -qw "ctf-pentesting"; then
    exit 0
fi

REASON=""

# Expand ~ to HOME for comparison
EXPANDED_PATH="${FILE_PATH/#\~/$HOME}"

# --- Sensitive file patterns (always blocked) ---

# System password/shadow files
if echo "$EXPANDED_PATH" | grep -qE '^/etc/shadow$'; then
    REASON="Blocked: reading /etc/shadow (system password hashes)"
fi

if [ -z "$REASON" ] && echo "$EXPANDED_PATH" | grep -qE '^/etc/master\.passwd$'; then
    REASON="Blocked: reading /etc/master.passwd (BSD password file)"
fi

# SSH private keys
if [ -z "$REASON" ] && echo "$EXPANDED_PATH" | grep -qE '(^|/)\.ssh/id_(rsa|ed25519|ecdsa|dsa)$'; then
    REASON="Blocked: reading SSH private key"
fi

# AWS credentials
if [ -z "$REASON" ] && echo "$EXPANDED_PATH" | grep -qE '(^|/)\.aws/credentials$'; then
    REASON="Blocked: reading AWS credentials file"
fi

# GnuPG private keys
if [ -z "$REASON" ] && echo "$EXPANDED_PATH" | grep -qE '(^|/)\.gnupg/'; then
    REASON="Blocked: reading GnuPG directory (may contain private keys)"
fi

# .env files outside the project directory
if [ -z "$REASON" ] && echo "$EXPANDED_PATH" | grep -qE '(^|/)\.env$'; then
    # Allow .env files within the project directory
    if [ -n "${CC_PROJECT_DIR:-}" ]; then
        case "$EXPANDED_PATH" in
            "${CC_PROJECT_DIR}"/*) ;; # within project — allow
            *) REASON="Blocked: reading .env file outside project directory" ;;
        esac
    fi
fi

# Output deny JSON if blocked, otherwise silent exit 0
if [ -n "$REASON" ]; then
    _cc_security_log "DENY" "read-blocked" "${REASON} | path=${FILE_PATH}"
    _cc_json_pretool_deny "$REASON"
fi

exit 0
