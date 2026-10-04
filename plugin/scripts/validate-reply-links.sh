#!/bin/bash
# cognitive-core hook: Stop
# Blocks the end of a turn while the final reply contains a bare GitHub
# issue/PR reference (#123, Repo#123, owner/repo#123) outside a Markdown link,
# and tells the model the exact links to use (#368).
#
# Hooks cannot rewrite text that is already displayed: the blocked reply stays
# visible and the corrected one follows. The gate guarantees that no turn ends
# with a bare reference. Quality gate, not a security gate: without jq the
# hook stays silent.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"
_cc_load_config

command -v jq &>/dev/null || exit 0

INPUT=$(cat)

# Second pass after a block: never loop.
ACTIVE=$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)
[ "$ACTIVE" = "true" ] && exit 0

MSG=$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // ""' 2>/dev/null || true)
[ -n "$MSG" ] || exit 0

# ---- Remove everything where a #N is not a reference to link ----
# Fenced code blocks, inline code, Markdown links (incl. [#N](url)), bare URLs,
# HTML numeric entities.
TEXT=$(printf '%s\n' "$MSG" \
    | awk '/^[[:space:]]*(```|~~~)/ { fence = !fence; next } !fence' \
    | sed -E \
        -e 's/`[^`]*`//g' \
        -e 's/\[[^]]*\]\([^)]*\)//g' \
        -e 's#https?://[^[:space:])>]*##g' \
        -e 's/&#[0-9]+;//g')

# ---- Candidate tokens: [owner/][repo]#digits plus adjacent word chars ----
# Adjacent letters/digits stay in the token, so colours (#1a1a1a) and words
# like abc#12x fail the exact pattern below.
REFS=$(printf '%s\n' "$TEXT" \
    | grep -oE '[A-Za-z0-9_./-]*#[0-9]+[A-Za-z0-9_]*' \
    | grep -E '^(([A-Za-z0-9_.-]+/)?[A-Za-z][A-Za-z0-9_.-]*)?#[0-9]+$' \
    | sort -u || true)
[ -n "$REFS" ] || exit 0

# ---- Repo of this project: conf first, then the origin remote ----
REPO="${CC_GITHUB_REPO:-}"
if [ -z "$REPO" ]; then
    REPO=$(git -C "${CC_PROJECT_DIR:-.}" remote get-url origin 2>/dev/null \
        | sed -nE 's#^(https://github\.com/|git@github\.com:)([^/]+/[^/]+)$#\2#p' \
        | sed -E 's/\.git$//' || true)
fi
REPO_NAME="${REPO##*/}"

LINES=""
while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    num="${ref##*#}"
    prefix="${ref%#*}"
    case "$prefix" in
        "" | "$REPO_NAME")
            if [ -n "$REPO" ]; then
                link="[${ref}](https://github.com/${REPO}/issues/${num})"
            else
                link="[${ref}](https://github.com/<owner>/<repo>/issues/${num})  (set CC_GITHUB_REPO)"
            fi ;;
        */*)
            link="[${ref}](https://github.com/${prefix}/issues/${num})" ;;
        *)
            link="[${ref}](https://github.com/<owner>/${prefix}/issues/${num})  (other repo: use its full URL)" ;;
    esac
    LINES="${LINES}
- ${ref} -> ${link}"
done <<EOF
$REFS
EOF

REASON="Your reply contains bare GitHub issue/PR references. Post the reply again, unchanged otherwise, with EVERY occurrence written as a Markdown link (/issues/N also opens PRs):${LINES}"

jq -n --arg r "$REASON" '{decision: "block", reason: $r}'
