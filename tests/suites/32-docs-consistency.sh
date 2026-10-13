#!/bin/bash
# Test suite: docs state facts that match the code (#402)
#   - every hook in core/hooks has a row in the README hook table
#   - action versions shown in docs are versions the workflows use
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "32 - Docs Consistency"

cd "$ROOT_DIR"

# ---- Hook table ----
# Helpers (_lib.sh, _session-hygiene.sh) are sourced, not hooks
for hook in core/hooks/*.sh; do
    name="$(basename "$hook")"
    case "$name" in _*) continue ;; esac
    if grep -qF "| \`${name}\` |" README.md; then
        _pass "README hook table: ${name}"
    else
        _fail "README hook table: ${name}" "no row starting with | \`${name}\` |"
    fi
done

# ---- Action versions ----
# owner/repo -> majors used by the workflows, one "owner/repo@vN" per line
used=$(git ls-files '.github/workflows/*.yml' 'cicd/workflows/*.yml' '.github/actions/*/action.yml' \
    | xargs grep -hoE 'uses: *[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@v[0-9]+' \
    | sed -E 's/^uses: *//' | LC_ALL=C sort -u)

# Every versioned action reference in tracked docs, as "file:owner/repo@vN"
refs=$(git ls-files '*.md' | grep -v '^CHANGELOG\.md$' \
    | xargs grep -oE '[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@v[0-9]+' 2>/dev/null \
    | LC_ALL=C sort -u || true)

checked=0
while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    file="${ref%%:*}"
    action="${ref#*:}"
    # Only actions the workflows use; others have no version to compare with
    printf '%s\n' "$used" | grep -q "^${action%@*}@" || continue
    checked=$((checked + 1))
    if printf '%s\n' "$used" | grep -qxF "$action"; then
        _pass "action version in ${file}: ${action}"
    else
        _fail "action version in ${file}: ${action}" \
            "workflows use $(printf '%s\n' "$used" | grep "^${action%@*}@" | tr '\n' ' ')"
    fi
done <<EOF
$refs
EOF

if [ "$checked" -gt 0 ]; then
    _pass "action versions: ${checked} doc references compared"
else
    _fail "action versions: doc references compared" "none found, the pattern no longer matches"
fi

suite_end
