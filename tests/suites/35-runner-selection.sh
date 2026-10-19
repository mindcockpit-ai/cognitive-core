#!/bin/bash
# Test suite: CI workflow runner selection by trust level (#427)
#   A) templates: every job uses the PR / trusted expression, marker, no sudo without opt-in
#   B) the expression evaluated for each variable combination
#   C) update.sh / install.sh delivery of the managed CI workflows
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "35 - Runner Selection"

WFS="lint.yml evolutionary-cicd.yml"
# shellcheck disable=SC2016 # literal workflow expression
EXPR='${{ fromJSON(vars.CI_RUNNER_FAILOVER && '"'"'["ubuntu-latest"]'"'"' || github.event_name == '"'"'pull_request'"'"' && (vars.RUNNER_LABELS_PR || !vars.RUNNER_LABELS_TRUSTED && vars.RUNNER_LABEL && format('"'"'[{0}]'"'"', toJSON(vars.RUNNER_LABEL)) || '"'"'["ubuntu-latest"]'"'"') || (vars.RUNNER_LABELS_TRUSTED || !vars.RUNNER_LABELS_PR && vars.RUNNER_LABEL && format('"'"'[{0}]'"'"', toJSON(vars.RUNNER_LABEL)) || '"'"'["ubuntu-latest"]'"'"')) }}'

# ---- A) Templates ----
for wf in $WFS; do
    t="${ROOT_DIR}/cicd/workflows/${wf}"
    assert_eq "${wf}: managed marker" "# cc-managed: ${wf%.yml} v1" "$(head -1 "$t")"
    jobs=$(sed -n '/^jobs:/,$p' "$t" | grep -cE '^  [a-z0-9-]+:$')
    runs=$(grep -cE '^    runs-on: ' "$t")
    assert_eq "${wf}: one runs-on per job" "$jobs" "$runs"
    assert_eq "${wf}: every runs-on is the trust-level expression" "$runs" \
        "$(grep -E '^    runs-on: ' "$t" | sed 's/^    runs-on: //' | grep -cxF "$EXPR" || true)"
    assert_eq "${wf}: no single-label form left" "" "$(grep -n 'vars.RUNNER_LABEL ||' "$t" || true)"
    # Every sudo sits in a step whose if is the explicit opt-in
    bad=$(awk '
        /^      - / { cond = "" }
        /^        if: / { cond = $0 }
        /sudo/ && !/^ *#/ && cond !~ /vars\.RUNNER_NEEDS_CHOWN == .true./ { print FILENAME ":" NR }
    ' "$t")
    assert_eq "${wf}: sudo only behind RUNNER_NEEDS_CHOWN" "" "$bad"
    assert_eq "${wf}: sudo never prompts" "" "$(grep -nE 'sudo ' "$t" | grep -v '^ *[0-9]*: *#' | grep -v 'sudo -n ' || true)"
done

# ---- B) Expression ----
# Translates the GitHub expression to Python: && / || return an operand and
# unset variables are '' in both, so the result is the label list GitHub uses.
# Repository variables are always strings, so 'false' and '0' are truthy in both
# (GitHub only treats false, 0, -0, null, NaN and '' as falsy). Syntax and types
# of the real expression are checked by actionlint where it is installed.
eval_expr() { # <expression> <event> [NAME=value ...]
    python3 -I - "$@" << 'PY'
import json, re, sys
expr, event, pairs = sys.argv[1], sys.argv[2], sys.argv[3:]
vars_ = dict(p.split("=", 1) for p in pairs)
body = expr.strip()
assert body.startswith("${{") and body.endswith("}}"), body
body = body[3:-2]
body = re.sub(r"vars\.([A-Z_]+)", r"v('\1')", body)
body = body.replace("github.event_name", "event").replace("&&", " and ").replace("||", " or ")
body = re.sub(r"!(?!=)", " not ", body)
body = body.replace("fromJSON(", "json.loads(").replace("toJSON(", "json.dumps(").replace("format(", "fmt(")
env = {"json": json, "event": event, "v": lambda n: vars_.get(n, ""),
       "fmt": lambda f, *a: re.sub(r"\{(\d+)\}", lambda m: str(a[int(m.group(1))]), f)}
print(json.dumps(eval(body, {"__builtins__": {}}, env)))
PY
}
if command -v python3 &>/dev/null; then
    actual=$(grep -hE '^    runs-on: ' "${ROOT_DIR}/cicd/workflows/lint.yml" | head -1 | sed 's/^    runs-on: //')
    H='["ubuntu-latest"]'
    PR='RUNNER_LABELS_PR=["self-hosted", "ci-pr"]'
    TR='RUNNER_LABELS_TRUSTED=["self-hosted", "ci-trusted"]'
    while IFS='|' read -r name event expected vars_list; do
        [ -n "$name" ] || continue
        # shellcheck disable=SC2086 # vars_list is a ;-list split below
        IFS=';' read -r -a args <<< "$vars_list"
        assert_eq "expression: ${name}" "$expected" "$(eval_expr "$actual" "$event" ${args[@]+"${args[@]}"})"
    done << EOF
nothing set, push|push|${H}|
nothing set, pull_request|pull_request|${H}|
RUNNER_LABEL only, push|push|["self-hosted"]|RUNNER_LABEL=self-hosted
RUNNER_LABEL only, pull_request|pull_request|["self-hosted"]|RUNNER_LABEL=self-hosted
RUNNER_LABEL only, schedule|schedule|["self-hosted"]|RUNNER_LABEL=self-hosted
split, pull_request|pull_request|["self-hosted", "ci-pr"]|${PR};${TR}
split, push|push|["self-hosted", "ci-trusted"]|${PR};${TR}
split, workflow_dispatch|workflow_dispatch|["self-hosted", "ci-trusted"]|${PR};${TR}
split + RUNNER_LABEL ignored, pull_request|pull_request|["self-hosted", "ci-pr"]|${PR};${TR};RUNNER_LABEL=old
trusted only + RUNNER_LABEL, pull_request stays hosted|pull_request|${H}|${TR};RUNNER_LABEL=old
trusted only + RUNNER_LABEL, push|push|["self-hosted", "ci-trusted"]|${TR};RUNNER_LABEL=old
PR only + RUNNER_LABEL, push stays hosted|push|${H}|${PR};RUNNER_LABEL=old
failover, pull_request|pull_request|${H}|${PR};${TR};CI_RUNNER_FAILOVER=1
failover, push|push|${H}|${PR};${TR};CI_RUNNER_FAILOVER=1
failover any value (false), push|push|${H}|${TR};CI_RUNNER_FAILOVER=false
failover beats RUNNER_LABEL|push|${H}|RUNNER_LABEL=self-hosted;CI_RUNNER_FAILOVER=yes
EOF
else
    _skip "python3 not available (expression evaluation)"
fi

# ---- C) update.sh / install.sh delivery ----
if command -v python3 &>/dev/null; then
    WORK=$(create_test_dir)
    FW="${WORK}/framework"
    mkdir -p "$FW"
    (cd "$ROOT_DIR" && git ls-files -z -co --exclude-standard | xargs -0 tar -cf - 2>/dev/null) | tar -xf - -C "$FW"
    # The shipped list is pinned here (CI checks out without history or tags):
    # 5 versions per template, the last one being the v1.8.1 template
    list="${FW}/cicd/legacy-workflows.sha256"
    for wf in $WFS; do
        assert_eq "legacy list: 5 shipped versions of ${wf}" "5" "$(grep -c "  ${wf}\$" "$list" || true)"
    done
    assert_contains "legacy list: v1.8.1 lint.yml" "$(cat "$list")" "13b3ad8a6475d1424da8c8ce3966799c137b6eb66ef2a46e001ce5d2195de712  lint.yml"
    assert_contains "legacy list: v1.8.1 evolutionary-cicd.yml" "$(cat "$list")" "8edcd6426848cf22aa8b2c1c4f19028eeb1ca42787b0eda09014d06563ee508d  evolutionary-cicd.yml"
    # With history: every pre-marker version of the templates is listed
    if [ "$(git -C "$ROOT_DIR" rev-list --count HEAD 2>/dev/null || echo 1)" -gt 1 ]; then
        for wf in $WFS; do
            for c in $(git -C "$ROOT_DIR" log --format=%H -- "cicd/workflows/${wf}"); do
                git -C "$ROOT_DIR" show "${c}:cicd/workflows/${wf}" | head -1 | grep -q '^# cc-managed: ' && continue
                s=$(git -C "$ROOT_DIR" show "${c}:cicd/workflows/${wf}" | shasum -a 256 | cut -d' ' -f1)
                if grep -qxF "${s}  ${wf}" "$list"; then
                    _pass "legacy list has ${wf}@${c:0:7}"
                else
                    _fail "legacy list has ${wf}@${c:0:7}" "missing ${s}"
                fi
            done
        done
    else
        _skip "shallow checkout (legacy list history check)"
    fi
    proj="${WORK}/install"
    mkdir -p "$proj" && git -C "$proj" init --quiet
    cat > "${proj}/cognitive-core.conf" << 'EOF'
#!/bin/false
CC_PROJECT_NAME="runner-test"
CC_PROJECT_DESCRIPTION="CI workflow delivery test"
CC_ORG="acme"
CC_LANGUAGE="python"
CC_LINT_EXTENSIONS=".py"
CC_LINT_COMMAND="ruff check \$1"
CC_FORMAT_COMMAND=""
CC_TEST_COMMAND="pytest"
CC_TEST_PATTERN="tests/**/*.py"
CC_DATABASE="none"
CC_ARCHITECTURE="ddd"
CC_SRC_ROOT="src"
CC_TEST_ROOT="tests"
CC_AGENTS="reviewer"
CC_COORDINATOR_MODEL="opus"
CC_SPECIALIST_MODEL="sonnet"
CC_SKILLS="session-resume"
CC_HOOKS="setup-env"
CC_MAIN_BRANCH="main"
CC_COMMIT_FORMAT="conventional"
CC_COMMIT_SCOPES="api"
CC_ENABLE_CICD="true"
CC_RUNNER_TYPE="github-hosted"
CC_MONITORING="true"
CC_COMPACT_RULES="1. Follow standards"
EOF
    lint="${proj}/.github/workflows/lint.yml"
    evo="${proj}/.github/workflows/evolutionary-cicd.yml"
    tpl_lint="${FW}/cicd/workflows/lint.yml"
    tpl_evo="${FW}/cicd/workflows/evolutionary-cicd.yml"
    manifest="${proj}/.claude/cognitive-core/version.json"
    upd() { env -i PATH="$PATH" HOME="$WORK" bash "${FW}/update.sh" "$proj" < /dev/null 2>&1; echo "UPDATE_RC=$?"; }
    n_upd=0
    upd_ok() { n_upd=$((n_upd + 1)); assert_contains "update run ${n_upd} exits 0" "$1" "UPDATE_RC=0"; }
    sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
    recorded() { python3 -c 'import json,sys;print(" ".join(sorted(e["path"] for e in json.load(open(sys.argv[1]))["files"] if e["path"].startswith(".github/"))))' "$manifest"; }
    old_form() { # <template> -> the pre-#427 single-label form of it, without marker
        sed -e '1d' -e 's/^    runs-on: .*/    runs-on: ${{ vars.RUNNER_LABEL || '"'"'ubuntu-latest'"'"' }}/' \
            -e 's/vars\.RUNNER_NEEDS_CHOWN == '"'"'true'"'"'/vars.RUNNER_LABEL != '"'"''"'"'/' "$1"
    }
    if env -i PATH="$PATH" HOME="$WORK" bash "${FW}/install.sh" "$proj" >/dev/null 2>&1; then
        _pass "install with CI/CD"
        assert_contains "install records the managed CI workflows" "$(recorded)" \
            ".github/workflows/evolutionary-cicd.yml .github/workflows/lint.yml"
        out=$(upd); upd_ok "$out"
        assert_eq "unchanged update: no CI workflow action" "0" "$(grep -cE '(UPDATED|REPLACED|LEGACY|MODIFIED).*(lint|evolutionary-cicd)\.yml' <<< "$out" || true)"
        # Template change reaches an unmodified marked copy
        printf '# template change\n' >> "$tpl_lint"
        out=$(upd); upd_ok "$out"
        assert_contains "unmodified CI workflow updated" "$out" "UPDATED (workflow): .github/workflows/lint.yml"
        if cmp -s "$tpl_lint" "$lint"; then _pass "updated copy equals the template"; else _fail "updated copy equals the template" "differs"; fi
        # Local edit of a marked copy survives template changes
        printf '# local\n' >> "$lint"
        local_sha=$(sha "$lint")
        printf '# template change 2\n' >> "$tpl_lint"
        out=$(upd); upd_ok "$out"
        assert_contains "edited CI workflow preserved" "$out" "MODIFIED (preserved): .github/workflows/lint.yml"
        assert_eq "edited CI workflow untouched" "$local_sha" "$(sha "$lint")"
        # Unedited legacy copy (in the shipped list): replaced and recorded
        old_form "$tpl_evo" > "$evo"
        printf '%s  evolutionary-cicd.yml\n' "$(sha "$evo")" >> "${FW}/cicd/legacy-workflows.sha256"
        out=$(upd); upd_ok "$out"
        assert_contains "unedited legacy replaced" "$out" "REPLACED (unedited legacy workflow): .github/workflows/evolutionary-cicd.yml"
        assert_contains "replaced legacy: chown opt-in announced" "$out" "set the repository variable RUNNER_NEEDS_CHOWN=true"
        assert_contains "replaced legacy: shared runner announced" "$out" "a set RUNNER_LABEL still runs PR and trusted jobs on one runner"
        if cmp -s "$tpl_evo" "$evo"; then _pass "replaced copy equals the template"; else _fail "replaced copy equals the template" "differs"; fi
        assert_contains "replaced legacy recorded" "$(recorded)" ".github/workflows/evolutionary-cicd.yml"
        # Locally edited legacy copy of the single-label form: kept and reported
        old_form "$tpl_evo" > "$evo" && printf '# local\n' >> "$evo"
        legacy_sha=$(sha "$evo")
        out=$(upd); upd_ok "$out"
        assert_contains "edited legacy reported" "$out" "LEGACY: .github/workflows/evolutionary-cicd.yml"
        assert_contains "edited legacy: single-label form named" "$out" "same runner as trusted jobs (single RUNNER_LABEL)"
        assert_contains "edited legacy: remedy shown" "$out" "To take the framework copy (runner variables: docs/CICD_GUIDE.md): cp "
        assert_eq "edited legacy untouched" "$legacy_sha" "$(sha "$evo")"
        assert_not_contains "edited legacy not recorded" "$(recorded)" "evolutionary-cicd.yml"
        # Local trust-level edit without marker: kept, no single-label warning
        sed '1d' "$tpl_evo" > "$evo"
        out=$(upd); upd_ok "$out"
        assert_contains "unmarked local edit reported" "$out" "LEGACY: .github/workflows/evolutionary-cicd.yml"
        assert_not_contains "unmarked trust-level edit: no single-label warning" "$out" "single RUNNER_LABEL"
        # Taking the framework copy makes it managed again
        cp "$tpl_evo" "$evo"
        out=$(upd); upd_ok "$out"
        assert_contains "framework copy recorded again" "$(recorded)" ".github/workflows/evolutionary-cicd.yml"
        # Override: never touched, never reported
        chmod u+w "${proj}/cognitive-core.conf"
        printf 'CC_LOCAL_OVERRIDES=".github/workflows/evolutionary-cicd.yml"\n' >> "${proj}/cognitive-core.conf"
        old_form "$tpl_evo" > "$evo"
        out=$(upd); upd_ok "$out"
        assert_contains "override honoured" "$out" "OVERRIDE (project owned): .github/workflows/evolutionary-cicd.yml"
        assert_not_contains "override: no legacy warning" "$out" "LEGACY: .github/workflows/evolutionary-cicd.yml"
        # A removed CI workflow is not added back
        rm -f "$lint"
        out=$(upd); upd_ok "$out"
        if [ -e "$lint" ]; then _fail "removed CI workflow not recreated" "recreated"; else _pass "removed CI workflow not recreated"; fi
    else
        _fail "install with CI/CD" "install.sh failed"
    fi
else
    _skip "python3 not available (needed for update.sh)"
fi

suite_end
