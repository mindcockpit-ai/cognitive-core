#!/bin/bash
# cognitive-core hook: PostToolUse (Write|Edit)
# Secret scanning — detects credentials in file writes
# Non-blocking: warns but does not prevent the write (PostToolUse)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"
_cc_load_config

# Read stdin JSON
INPUT=$(cat)

# Extract file path from tool input
FILE_PATH=$(echo "$INPUT" | _cc_json_get ".tool_input.file_path")

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Skip test files and documentation (high false-positive rate)
case "$FILE_PATH" in
    *_test.* | *_spec.* | *.test.* | *.spec.* | *.md | *.example | *.template)
        exit 0
        ;;
esac

# Skip if file doesn't exist (shouldn't happen in PostToolUse but be safe)
if [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

WARNINGS=""

# Secret detection patterns
# AWS access keys
if grep -qE 'AKIA[0-9A-Z]{16}' "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}\n- Possible AWS access key detected (AKIA...)"
fi

# PEM private keys
if grep -q -e '-----BEGIN.*PRIVATE.*KEY-----' "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}\n- Private key (PEM format) detected"
fi

# Generic API keys/tokens (high-entropy strings assigned to key-like variables)
if grep -qE -e '(api[_-]?key|api[_-]?secret|access[_-]?token)[[:space:]]*[:=]' "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}\n- Possible API key/secret/token assignment detected"
fi

# Hardcoded passwords/secrets (long string values)
if grep -qE -e '(password|secret|token)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{16,}' "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}\n- Possible hardcoded password/secret/token detected"
fi

# Output warning if secrets found
if [ -n "$WARNINGS" ]; then
    _cc_security_log "WARN" "secret-detected" "file=${FILE_PATH}${WARNINGS}"
    _cc_json_posttool_context "SECRET SCAN WARNING in ${FILE_PATH}:${WARNINGS}\nConsider using environment variables or a secrets manager instead of hardcoding credentials."
fi

exit 0
