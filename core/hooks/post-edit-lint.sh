#!/bin/bash
# cognitive-core hook: PostToolUse (Write|Edit)
# Auto-lints files after edits based on project language config
# Always exits 0 (non-blocking feedback only)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"
_cc_load_config

# Read stdin JSON
INPUT=$(cat)

# Extract file path
FILE_PATH=$(echo "$INPUT" | _cc_json_get ".tool_input.file_path")

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Check if lint is configured
if [ -z "${CC_LINT_COMMAND:-}" ]; then
    exit 0
fi

# Check if file extension matches configured lint extensions
EXT=".${FILE_PATH##*.}"
MATCH=false
for lint_ext in ${CC_LINT_EXTENSIONS:-}; do
    if [ "$EXT" = "$lint_ext" ]; then
        MATCH=true
        break
    fi
done

if [ "$MATCH" = false ]; then
    exit 0
fi

# Check if file exists
if [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

# Run configured lint command (substitute $1 with file path)
LINT_CMD="${CC_LINT_COMMAND//\$1/$FILE_PATH}"
LINT_OUTPUT=$(eval "$LINT_CMD" 2>&1 || true)

if [ -z "$LINT_OUTPUT" ]; then
    exit 0
fi

CONTEXT="Auto-lint results for $(basename "$FILE_PATH"):
${LINT_OUTPUT}"

_cc_json_posttool_context "$CONTEXT"

exit 0
