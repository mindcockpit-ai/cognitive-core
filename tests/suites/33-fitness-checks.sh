#!/bin/bash
# Test suite: language-pack fitness-checks.sh print a score instead of
# aborting when a check finds nothing (#412)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "33 - Fitness Checks"

SCORE_RE='^[0-9]+ [0-9]+/[0-9]+ '

EMPTY=$(create_test_dir)
FULL=$(create_test_dir)
mkdir -p "${FULL}/src" "${FULL}/lib"
printf 'var x = 1;\nconsole.log(x);\nconst z = require("z");\n' > "${FULL}/src/a.ts"
printf 'import os\n\ndef f(x):\n    try:\n        return os.path.join(x)\n    except:\n        pass\n\ndef g(y) -> int:\n    return 1\n' > "${FULL}/src/a.py"
printf 'package A;\nuse strict;\nmy $c = "DBIx::Class::ResultClass::HashRefInflator";\nmy $t = now();\neval { die };\n1;\n' > "${FULL}/lib/A.pm"

# grep fallback always; rg mode only runs when bash finds a real rg binary,
# so _cc_bre_to_rg is unit-tested below as well. CI sets CC_TEST_REQUIRE_RG=1
# so a runner without rg fails instead of silently skipping rg mode (#416)
modes="0"
command -v rg &>/dev/null && modes="0 1"
if [ "${CC_TEST_REQUIRE_RG:-0}" = "1" ]; then
    assert_eq "rg on PATH (CC_TEST_REQUIRE_RG=1)" "0 1" "$modes"
fi

for mode in $modes; do
    engine="grep"
    [ "$mode" = "1" ] && engine="rg"

    for script in "${ROOT_DIR}"/language-packs/*/fitness-checks.sh; do
        pack=$(basename "$(dirname "$script")")
        rc=0
        out=$(_CC_HAS_RG=$mode bash "$script" "$EMPTY" 2>&1) || rc=$?
        assert_eq "${pack} (${engine}): empty project exits 0" "0" "$rc"
        assert_matches "${pack} (${engine}): empty project prints a score" "$out" "$SCORE_RE"
        rc=0
        out=$(_CC_HAS_RG=$mode bash "$script" "$FULL" 2>&1) || rc=$?
        assert_eq "${pack} (${engine}): project with matches exits 0" "0" "$rc"
        assert_matches "${pack} (${engine}): project with matches prints a score" "$out" "$SCORE_RE"
    done

    rc=0
    out=$(_CC_HAS_RG=$mode bash "${ROOT_DIR}/language-packs/node/fitness-checks.sh" "$FULL" 2>&1) || rc=$?
    assert_eq "node (${engine}): project with matches exits 0" "0" "$rc"
    assert_contains "node (${engine}): var count" "$out" "1 var declarations"
    assert_contains "node (${engine}): console count" "$out" "1 console statements"
    assert_contains "node (${engine}): require count" "$out" "1 require() calls"

    rc=0
    out=$(_CC_HAS_RG=$mode bash "${ROOT_DIR}/language-packs/python/fitness-checks.sh" "$FULL" 2>&1) || rc=$?
    assert_eq "python (${engine}): project with matches exits 0" "0" "$rc"
    assert_contains "python (${engine}): typed ratio" "$out" "1/2 typed (50%)"
    assert_contains "python (${engine}): bare except count" "$out" "1 bare except blocks"
    assert_contains "python (${engine}): os.path count" "$out" "1 os.path usages"

    out=$(_CC_HAS_RG=$mode bash "${ROOT_DIR}/language-packs/perl/fitness-checks.sh" "$FULL" 2>&1) || true
    assert_contains "perl (${engine}): HashRefInflator count" "$out" "1 files use HashRefInflator"
    assert_contains "perl (${engine}): now() count" "$out" "1 unsafe now() calls"
    assert_contains "perl (${engine}): bare eval count" "$out" "1 bare eval blocks"
done

rm -rf "$EMPTY" "$FULL"

# ---- _cc_bre_to_rg: grep BRE -> rg regex (runs without rg) ----
# shellcheck disable=SC1091
source "${ROOT_DIR}/language-packs/_common.sh"
assert_eq "bre->rg: bare ( is literal" '\.then\(' "$(_cc_bre_to_rg '\.then(')"
assert_eq "bre->rg: bare { is literal" 'eval\s*\{' "$(_cc_bre_to_rg 'eval\s*{')"
assert_eq "bre->rg: \\( \\| \\) are operators" 'a(b|c)' "$(_cc_bre_to_rg 'a\(b\|c\)')"
assert_eq "bre->rg: JSX style={{ is literal" 'style=\{\{' "$(_cc_bre_to_rg 'style={{')"
assert_eq "bre->rg: other escapes kept" '\bvar\s\.\[' "$(_cc_bre_to_rg '\bvar\s\.\[')"
assert_eq "bre->rg: bracket expression copied" 'x[[:space:]]\(\|y' "$(_cc_bre_to_rg 'x[[:space:]](|y')"
assert_eq "bre->rg: ] first in bracket is literal" 'a[](]+' "$(_cc_bre_to_rg 'a[](]\+')"

suite_end
