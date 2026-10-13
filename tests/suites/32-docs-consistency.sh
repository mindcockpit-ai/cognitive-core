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
# (mention a deliberately old version without the @vN form)
refs=$(git ls-files -z '*.md' ':!CHANGELOG.md' \
    | xargs -0 grep -HoE '[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@v[0-9]+' 2>/dev/null \
    | LC_ALL=C sort -u || true)

checked=0
while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    file="${ref%%:*}"
    action="${ref#*:}"
    # Only actions the workflows use; others have no version to compare with
    printf '%s\n' "$used" | grep -qF "${action%@*}@" || continue
    checked=$((checked + 1))
    if printf '%s\n' "$used" | grep -qxF "$action"; then
        _pass "action version in ${file}: ${action}"
    else
        _fail "action version in ${file}: ${action}" \
            "workflows use $(printf '%s\n' "$used" | grep -F "${action%@*}@" | tr '\n' ' ')"
    fi
done <<EOF
$refs
EOF

if [ "$checked" -gt 0 ]; then
    _pass "action versions: ${checked} doc references compared"
else
    _fail "action versions: doc references compared" "none found, the pattern no longer matches"
fi

# ---- Docs-touch rule (tests/lib/docs-touch.sh) ----
repo=$(create_test_dir)
git -C "$repo" init --quiet
git -C "$repo" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m base
base=$(git -C "$repo" rev-parse HEAD)
_touch_case() {  # <files to add, space separated> -> head sha
    local f
    git -C "$repo" checkout --quiet "$base"
    for f in $1; do mkdir -p "$repo/$(dirname "$f")"; echo x >> "$repo/$f"; done
    git -C "$repo" add -A
    git -C "$repo" -c user.name=t -c user.email=t@t commit --quiet -m case
    git -C "$repo" rev-parse HEAD
}
_touch_rc() {  # <head> <body>
    (cd "$repo" && BODY="$2" bash "${ROOT_DIR}/tests/lib/docs-touch.sh" "$base" "$1" >/dev/null 2>&1) && echo 0 || echo 1
}
hook_only=$(_touch_case "core/hooks/x.sh")
assert_eq "docs-touch: hook change without docs fails" "1" "$(_touch_rc "$hook_only" "")"
assert_eq "docs-touch: 'docs: n/a' line passes" "0" "$(_touch_rc "$hook_only" "Fix.
docs: n/a, internal")"
assert_eq "docs-touch: checkbox mention does not count" "1" "$(_touch_rc "$hook_only" "- [ ] docs: n/a")"
assert_eq "docs-touch: hook change with docs/ passes" "0" "$(_touch_rc "$(_touch_case "core/hooks/x.sh docs/x.md")" "")"
assert_eq "docs-touch: helper (_lib.sh) is not behaviour" "0" "$(_touch_rc "$(_touch_case "core/hooks/_lib.sh")" "")"
assert_eq "docs-touch: utility change without docs fails" "1" "$(_touch_rc "$(_touch_case "core/utilities/x.sh")" "")"
rm -rf "$repo"

suite_end
