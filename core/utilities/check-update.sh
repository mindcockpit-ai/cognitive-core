#!/bin/bash
# cognitive-core: Connected Projects — update check
# Checks if the framework source has updates available.
# Called by setup-env.sh at session start on a configurable interval.
#
# Output: one-line notice if update available, empty if up-to-date or disabled.
# Exit: always 0 (never fails the session)
set -euo pipefail

# Config defaults
CC_UPDATE_AUTO_CHECK="${CC_UPDATE_AUTO_CHECK:-true}"
CC_UPDATE_CHECK_INTERVAL="${CC_UPDATE_CHECK_INTERVAL:-7}"  # days

# Guard: skip if disabled
if [ "$CC_UPDATE_AUTO_CHECK" != "true" ]; then
    exit 0
fi

# Need version.json to find framework source
VERSION_FILE="${CC_PROJECT_DIR:-.}/.claude/cognitive-core/version.json"
if [ ! -f "$VERSION_FILE" ]; then
    exit 0
fi

# Extract source directory from version.json
if command -v jq &>/dev/null; then
    SOURCE_DIR=$(jq -r '.source // ""' "$VERSION_FILE" 2>/dev/null)
else
    SOURCE_DIR=$(grep -o '"source"[[:space:]]*:[[:space:]]*"[^"]*"' "$VERSION_FILE" | head -1 | sed 's/.*"source"[[:space:]]*:[[:space:]]*"//;s/"//')
fi

if [ -z "$SOURCE_DIR" ] || [ ! -d "$SOURCE_DIR" ]; then
    exit 0
fi

# Check interval: skip if checked recently
LAST_CHECK_FILE="${CC_PROJECT_DIR:-.}/.claude/cognitive-core/last-check"
if [ -f "$LAST_CHECK_FILE" ] && [ "$CC_UPDATE_CHECK_INTERVAL" -gt 0 ] 2>/dev/null; then
    last_ts=$(cat "$LAST_CHECK_FILE" 2>/dev/null || echo "0")
    now_ts=$(date +%s 2>/dev/null || echo "0")
    interval_secs=$((CC_UPDATE_CHECK_INTERVAL * 86400))
    if [ "$((now_ts - last_ts))" -lt "$interval_secs" ] 2>/dev/null; then
        exit 0
    fi
fi

# Fetch latest from remote (silent, with timeout)
if ! git -C "$SOURCE_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
    exit 0
fi

# Attempt fetch with 5s timeout (fail silently if offline)
timeout 5 git -C "$SOURCE_DIR" fetch --quiet 2>/dev/null || true

# Compare HEAD vs origin/main
LOCAL_HEAD=$(git -C "$SOURCE_DIR" rev-parse HEAD 2>/dev/null || echo "")
REMOTE_HEAD=$(git -C "$SOURCE_DIR" rev-parse origin/main 2>/dev/null || echo "")

if [ -z "$LOCAL_HEAD" ] || [ -z "$REMOTE_HEAD" ]; then
    # Can't compare, skip
    date +%s > "$LAST_CHECK_FILE" 2>/dev/null || true
    exit 0
fi

if [ "$LOCAL_HEAD" = "$REMOTE_HEAD" ]; then
    # Up to date
    date +%s > "$LAST_CHECK_FILE" 2>/dev/null || true
    exit 0
fi

# Count commits ahead on remote
BEHIND_COUNT=$(git -C "$SOURCE_DIR" rev-list HEAD..origin/main --count 2>/dev/null || echo "0")

if [ "$BEHIND_COUNT" -gt 0 ]; then
    # List changed areas (hooks, skills, agents)
    CHANGED_AREAS=""
    changed_files=$(git -C "$SOURCE_DIR" diff --name-only HEAD..origin/main 2>/dev/null || true)
    if echo "$changed_files" | grep -q "core/hooks/"; then
        CHANGED_AREAS="${CHANGED_AREAS} hooks"
    fi
    if echo "$changed_files" | grep -q "core/skills/"; then
        CHANGED_AREAS="${CHANGED_AREAS} skills"
    fi
    if echo "$changed_files" | grep -q "core/agents/"; then
        CHANGED_AREAS="${CHANGED_AREAS} agents"
    fi
    if echo "$changed_files" | grep -q "install.sh\|update.sh"; then
        CHANGED_AREAS="${CHANGED_AREAS} installer"
    fi

    NOTICE="cognitive-core update available: ${BEHIND_COUNT} new commit(s)"
    if [ -n "$CHANGED_AREAS" ]; then
        NOTICE="${NOTICE} affecting:${CHANGED_AREAS}"
    fi
    NOTICE="${NOTICE}. Run update.sh to apply."
    echo "$NOTICE"
fi

# Update last-check timestamp
date +%s > "$LAST_CHECK_FILE" 2>/dev/null || true

exit 0
