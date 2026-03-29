#!/bin/bash
# create-issue.sh — [D/S] Create GitHub issue for a smoke test failure
# The title and body are pre-composed (by LLM or template). This script
# handles dedup checking and the gh issue create mechanics.
#
# Usage: ./create-issue.sh --title "TITLE" --body "BODY" [--add-to-project NUMBER]
# Outputs: JSON with created issue URL or skip reason
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_smoke-lib.sh"

_st_load_config
_st_require_gh

REPO=$(_st_repo)
LABEL=$(_st_label)

TITLE="" BODY="" PROJECT_NUMBER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --title) TITLE="$2"; shift 2 ;;
        --body) BODY="$2"; shift 2 ;;
        --add-to-project) PROJECT_NUMBER="$2"; shift 2 ;;
        *) shift ;;
    esac
done

if [[ -z "$TITLE" ]]; then
    _st_die "Usage: create-issue.sh --title TITLE --body BODY"
fi

# Dedup guard: check if issue already exists (race condition protection)
SEARCH_TERM=$(echo "$TITLE" | sed 's/\[smoke-test\] //')
EXISTING=$(gh issue list --repo "$REPO" --label "bug,$LABEL" --state open --search "$SEARCH_TERM" --json number --jq '.[0].number // empty' 2>/dev/null || echo "")

if [[ -n "$EXISTING" ]]; then
    _st_info "Issue already exists: #${EXISTING} — skipping"
    echo "{\"action\":\"skipped\",\"reason\":\"duplicate\",\"existing_issue\":${EXISTING}}"
    exit 0
fi

# Create the issue
ISSUE_URL=$(gh issue create --repo "$REPO" --title "$TITLE" --body "$BODY" --label "bug,$LABEL" 2>&1)

if [[ "$ISSUE_URL" != http* ]]; then
    _st_die "Failed to create issue: ${ISSUE_URL}"
fi

_st_info "Created: ${ISSUE_URL}"

# Optionally add to project board
if [[ -n "$PROJECT_NUMBER" ]]; then
    gh project item-add "$PROJECT_NUMBER" --owner "$CC_ORG" --url "$ISSUE_URL" 2>/dev/null || \
        _st_info "Warning: could not add to project board"
fi

echo "{\"action\":\"created\",\"url\":\"${ISSUE_URL}\"}"
