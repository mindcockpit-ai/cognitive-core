#!/bin/bash
# Docs-touch rule (#402): behaviour changes need a docs change or "docs: n/a".
# Usage: docs-touch.sh <base> <head>   (PR description in $BODY)
set -euo pipefail

changed=$(git diff --name-only "$1...$2")
code=$(printf '%s\n' "$changed" \
    | grep -E '^(core/hooks/[^_/][^/]*\.sh|install\.sh|update\.sh|adapters/[^/]+/adapter\.sh|adapters/_adapter-lib\.sh)$' || true)

if [ -z "$code" ]; then
    echo "No behaviour files changed."
elif printf '%s\n' "$changed" | grep -qE '^(README\.md|docs/)'; then
    echo "Behaviour files changed, docs updated."
elif printf '%s' "${BODY:-}" | grep -qiE '(^|[^a-z])docs: *n/a'; then
    echo "Behaviour files changed, PR says docs: n/a."
else
    echo "::error::Behaviour changed without docs:"
    printf '  %s\n' $code
    echo "Update README.md or docs/, or add 'docs: n/a' (with a reason) to the PR description."
    exit 1
fi
