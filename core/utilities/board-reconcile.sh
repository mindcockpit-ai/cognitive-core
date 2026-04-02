#!/bin/bash
# =============================================================================
# board-reconcile.sh — Reconcile closed issues with stale board status
# =============================================================================
# Scans the project board for closed issues that are NOT in Done/Canceled
# and moves them to Done. Designed to run as a daily cron job from VPS.
#
# Usage:
#   GH_TOKEN=<pat> ./board-reconcile.sh [--dry-run]
#
# Environment:
#   GH_TOKEN          — GitHub PAT with repo + project scopes (required)
#   CC_PROJECT_ID     — GraphQL Project ID (reads from cognitive-core.conf if unset)
#   CC_STATUS_FIELD_ID — Status field ID (reads from cognitive-core.conf if unset)
#   CC_STATUS_DONE_ID — Done option ID (reads from cognitive-core.conf if unset)
#   CC_PROJECT_NUMBER — Project number (reads from cognitive-core.conf if unset)
#   CC_GITHUB_OWNER   — GitHub org/user (reads from cognitive-core.conf if unset)
#   CC_GITHUB_REPO    — GitHub repo (reads from cognitive-core.conf if unset)
#
# Cron setup (VPS):
#   0 5 * * * GH_TOKEN=$(cat /etc/secrets/github-project-pat) /path/to/board-reconcile.sh >> /var/log/board-reconcile.log 2>&1
# =============================================================================
set -euo pipefail

DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

# Load config if not already set via environment
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF=""
for candidate in \
    "${SCRIPT_DIR}/../../cognitive-core.conf" \
    "${SCRIPT_DIR}/../../.claude/cognitive-core.conf" \
    "./cognitive-core.conf" \
    "./.claude/cognitive-core.conf"; do
    if [ -f "$candidate" ]; then
        CONF="$candidate"
        break
    fi
done

if [ -n "$CONF" ]; then
    # shellcheck disable=SC1090
    source "$CONF"
fi

# Validate required vars
: "${GH_TOKEN:?GH_TOKEN required — set via environment or secrets file}"
: "${CC_PROJECT_ID:?CC_PROJECT_ID required}"
: "${CC_STATUS_FIELD_ID:?CC_STATUS_FIELD_ID required}"
: "${CC_STATUS_DONE_ID:?CC_STATUS_DONE_ID required}"
: "${CC_PROJECT_NUMBER:?CC_PROJECT_NUMBER required}"
: "${CC_GITHUB_OWNER:?CC_GITHUB_OWNER required}"
: "${CC_GITHUB_REPO:?CC_GITHUB_REPO required}"

export GH_TOKEN

TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
echo "[$TIMESTAMP] Board reconciliation started (dry_run=$DRY_RUN)"

# Get all board items, strip control chars that break jq
ITEMS=$(gh project item-list "$CC_PROJECT_NUMBER" --owner "$CC_GITHUB_OWNER" \
    --format json --limit 500 2>/dev/null | tr -d '\000-\037') || {
    echo "[$TIMESTAMP] ERROR: Cannot access project board"
    exit 1
}

# Find board items NOT in Done/Canceled
ACTIVE_NUMS=$(echo "$ITEMS" | jq -r '
    .items[] |
    select(.content.type == "Issue") |
    select(.status != "Done" and .status != "Canceled") |
    "\(.content.number)|\(.status // "NO_STATUS")"
' | sort -t'|' -k1 -n -u)

FIXED=0
CHECKED=0

while IFS='|' read -r NUM BSTATUS; do
    [ -z "$NUM" ] && continue
    CHECKED=$((CHECKED + 1))

    STATE=$(gh issue view "$NUM" --repo "$CC_GITHUB_REPO" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")

    if [ "$STATE" = "CLOSED" ]; then
        ITEM_ID=$(echo "$ITEMS" | jq -r --argjson n "$NUM" \
            '.items[] | select(.content.number == $n) | .id' | head -1)

        if [ -n "$ITEM_ID" ] && [ "$ITEM_ID" != "null" ]; then
            if [ "$DRY_RUN" = true ]; then
                echo "  [DRY-RUN] #$NUM: $BSTATUS → Done (closed but board stale)"
            else
                gh api graphql -f query='mutation {
                    updateProjectV2ItemFieldValue(input: {
                        projectId: "'"$CC_PROJECT_ID"'"
                        itemId: "'"$ITEM_ID"'"
                        fieldId: "'"$CC_STATUS_FIELD_ID"'"
                        value: { singleSelectOptionId: "'"$CC_STATUS_DONE_ID"'" }
                    }) { projectV2Item { id } }
                }' --silent 2>/dev/null
                echo "  FIXED #$NUM: $BSTATUS → Done"
            fi
            FIXED=$((FIXED + 1))
        fi
    fi
done <<< "$ACTIVE_NUMS"

TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
echo "[$TIMESTAMP] Reconciliation complete: checked=$CHECKED fixed=$FIXED"
