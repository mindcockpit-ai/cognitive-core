#!/bin/bash
# list-open-issues.sh — [D] List open smoke-test issues as JSON
# Usage: ./list-open-issues.sh
# Outputs: JSON array of {number, title, url}
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_smoke-lib.sh"

_st_load_config
_st_require_gh

REPO=$(_st_repo)
LABEL=$(_st_label)

gh issue list --repo "$REPO" --label "bug,$LABEL" --state open --json number,title,url --jq '.' 2>/dev/null || echo "[]"
