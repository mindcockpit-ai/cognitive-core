#!/bin/bash
# Test suite: validate-reply-links.sh - Stop hook blocks bare issue/PR refs (#368)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "28 - Reply Links (Stop hook)"

HOOK="${ROOT_DIR}/core/hooks/validate-reply-links.sh"

if ! command -v jq &>/dev/null; then
    _skip "validate-reply-links needs jq" "jq not installed"
    suite_end
    exit 0
fi

# Isolated project: own conf, no git remote.
PROJ=$(create_test_dir)
printf 'CC_GITHUB_REPO="acme/widgets"\n' > "${PROJ}/cognitive-core.conf"
NOCONF=$(create_test_dir)

stop_json() {
    jq -n --arg m "$1" --argjson a "${2:-false}" \
        '{hook_event_name: "Stop", stop_hook_active: $a, last_assistant_message: $m}'
}
run_stop() {
    stop_json "$1" "${2:-false}" | CLAUDE_PROJECT_DIR="${3:-$PROJ}" bash "$HOOK" 2>/dev/null
}

# ---- blocks ----
out=$(run_stop 'Merge #302, then #274 (blocked by #196).')
assert_json_field "bare refs: decision block" "$out" ".decision" "block"
assert_contains "bare ref gets the project link" "$out" "[#302](https://github.com/acme/widgets/issues/302)"
assert_contains "ref in parentheses is caught" "$out" "[#196](https://github.com/acme/widgets/issues/196)"

out=$(run_stop 'Done.
#42')
assert_json_field "ref at line start: block" "$out" ".decision" "block"

out=$(run_stop 'Fixed in wolaschka/TIMS#485.')
assert_contains "owner/repo#N gets a direct link" "$out" "[wolaschka/TIMS#485](https://github.com/wolaschka/TIMS/issues/485)"

out=$(run_stop 'See TIMS#486.')
assert_contains "Repo#N of another repo: hint" "$out" "other repo: use its full URL"

out=$(run_stop 'See widgets#7.')
assert_contains "Repo#N of this repo: project link" "$out" "[widgets#7](https://github.com/acme/widgets/issues/7)"

out=$(run_stop 'Linked [#1](https://github.com/acme/widgets/issues/1) but bare #1 again.')
assert_json_field "repeat of a linked ref: block" "$out" ".decision" "block"

out=$(run_stop 'Merge #9.' false "$NOCONF")
assert_json_field "no CC_GITHUB_REPO: still blocks" "$out" ".decision" "block"
assert_contains "no CC_GITHUB_REPO: generic hint" "$out" "set CC_GITHUB_REPO"

# ---- passes ----
assert_eq "linked refs pass" "" \
    "$(run_stop 'Merged [#302](https://github.com/acme/widgets/pull/302) and [TIMS#486](https://github.com/wolaschka/TIMS/pull/486).')"
assert_eq "inline code passes" "" "$(run_stop 'Run `git log --grep=#12` first.')"
assert_eq "fenced code passes" "" "$(run_stop 'Example:
```bash
echo "#77"
```
Done.')"
assert_eq "URL fragment passes" "" "$(run_stop 'See https://example.com/page#12 for details.')"
assert_eq "colour passes" "" "$(run_stop 'Background #1a1a1a and #fff.')"
assert_eq "heading passes" "" "$(run_stop '## Step 2
Text.')"
assert_eq "HTML entity passes" "" "$(run_stop 'Escaped &#123; brace.')"
assert_eq "no refs passes" "" "$(run_stop 'All checks green.')"
assert_eq "stop_hook_active passes (no loop)" "" "$(run_stop 'Bare #5 again.' true)"
assert_eq "empty message passes" "" "$(run_stop '')"
assert_eq "malformed stdin passes" "" \
    "$(printf 'not json' | CLAUDE_PROJECT_DIR="$PROJ" bash "$HOOK" 2>/dev/null)"

# ---- wiring ----
assert_contains "wired as Stop hook in the settings template" \
    "$(jq -c '.hooks.Stop' "${ROOT_DIR}/core/templates/settings.json.tmpl")" \
    "validate-reply-links.sh"

suite_end
