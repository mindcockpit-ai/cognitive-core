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

# ---- Lint debt detection: check for NEW suppression comments ----
if [ "${CC_LINT_DEBT_AUTO_ISSUE:-true}" = "true" ] && [ -n "${CC_LINT_SUPPRESS_PATTERN:-}" ]; then
    # Detect suppress pattern from language if not set
    SUPPRESS_PAT="${CC_LINT_SUPPRESS_PATTERN}"

    # Use git diff to find only NEWLY added suppression lines
    NEW_SUPPRESSIONS=""
    if git -C "$(dirname "$FILE_PATH")" rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
        NEW_SUPPRESSIONS=$(git diff HEAD -- "$FILE_PATH" 2>/dev/null \
            | grep -E '^\+[^+]' \
            | grep -E "$SUPPRESS_PAT" \
            || true)
    else
        # Not in git — check entire file (new file scenario)
        NEW_SUPPRESSIONS=$(grep -E "$SUPPRESS_PAT" "$FILE_PATH" 2>/dev/null || true)
    fi

    if [ -n "$NEW_SUPPRESSIONS" ]; then
        DEBT_CONTEXT="LINT DEBT DETECTED: New lint suppression(s) added in $(basename "$FILE_PATH"):
${NEW_SUPPRESSIONS}

Every lint suppression must have a tracking GitHub issue. Either:
1. Create a GitHub issue with label '${CC_LINT_DEBT_LABEL:-technical-debt}' referencing this suppression
2. Run /lint-debt sync to auto-create tracking issues for all untracked suppressions
3. Reference an existing issue in the suppression comment"

        _cc_json_posttool_context "$DEBT_CONTEXT"
    fi
fi

exit 0
