#!/bin/bash
# Test suite: CC_LOCAL_OVERRIDES + update.sh --prune (#328)
# Unit cases for the override matcher, update.sh argument handling, then a
# full install -> override -> update -> prune scenario for every adapter.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "26 - Local Override + Prune"

# Need python3 for update.sh JSON parsing
if ! command -v python3 &>/dev/null; then
    _skip "python3 not available (needed for update.sh)"
    suite_end || true
    exit 0
fi

# A developer's ~/.cognitive-core/defaults.conf must not leak into the tests
HOME="$(create_test_dir)"
export HOME
unset CC_LOCAL_OVERRIDES CC_AGENTS CC_SKILLS CC_HOOKS CLAUDE_PROJECT_DIR CC_INSTALL_DIR

sha256_of() {
    python3 -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$1"
}

# install.sh makes the conf read-only; tests edit it in place
set_conf() {
    local conf="$1" key="$2" value="$3"
    unset_conf "$conf" "$key"
    printf '%s="%s"\n' "$key" "$value" >> "$conf"
}

unset_conf() {
    local conf="$1" key="$2"
    chmod u+w "$conf"
    sed -i.bak -E "/^${key}=/d" "$conf" && rm -f "${conf}.bak"
}

file_contains() {
    local label="$1" file="$2" needle="$3"
    if grep -qF -- "$needle" "$file" 2>/dev/null; then _pass "$label"; else _fail "$label" "'${needle}' not in ${file##*/}"; fi
}

file_lacks() {
    local label="$1" file="$2" needle="$3"
    if grep -qF -- "$needle" "$file" 2>/dev/null; then _fail "$label" "'${needle}' still in ${file##*/}"; else _pass "$label"; fi
}

# ---- _cc_is_local_override unit cases ----
UNIT_DIR="$(create_test_dir)"
printf 'framework hook\n' > "${UNIT_DIR}/hook.sh"
UNIT_SHA="$(sha256_of "${UNIT_DIR}/hook.sh")"

# override_rc <CC_LOCAL_OVERRIDES> <path> [file] -> prints the return code
override_rc() {
    (
        CLAUDE_PROJECT_DIR="$UNIT_DIR"
        # shellcheck disable=SC1091
        source "${ROOT_DIR}/core/hooks/_lib.sh"
        CC_LOCAL_OVERRIDES="$1"
        rc=0
        _cc_is_local_override "$2" "${3:-}" || rc=$?
        echo "$rc"
    )
}
assert_eq "override: empty list matches nothing" "1" "$(override_rc "" "hooks/post-edit-lint.sh")"
assert_eq "override: exact file matches" "0" "$(override_rc "hooks/post-edit-lint.sh" "hooks/post-edit-lint.sh")"
assert_eq "override: leading .claude/ is stripped" "0" "$(override_rc "hooks/post-edit-lint.sh" ".claude/hooks/post-edit-lint.sh")"
assert_eq "override: leading .cognitive-core/ is stripped" "0" "$(override_rc "hooks/post-edit-lint.sh" ".cognitive-core/hooks/post-edit-lint.sh")"
assert_eq "override: file entry is not a prefix" "1" "$(override_rc "hooks/post-edit-lint.sh" "hooks/post-edit-lint.sh.bak")"
assert_eq "override: directory entry matches files below it" "0" "$(override_rc "skills/foo/" "skills/foo/SKILL.md")"
assert_eq "override: directory entry needs the separator" "1" "$(override_rc "skills/foo/" "skills/foobar/SKILL.md")"
assert_eq "override: glob characters are literal" "1" "$(override_rc "hooks/*.sh" "hooks/post-edit-lint.sh")"
assert_eq "override: security hook without pin not honoured" "2" "$(override_rc "hooks/validate-bash.sh" "hooks/validate-bash.sh")"
assert_eq "override: dir-wide hooks/ not honoured for security hook" "2" "$(override_rc "hooks/" "hooks/setup-env.sh")"
assert_eq "override: dir-wide hooks/ honoured for other hooks" "0" "$(override_rc "hooks/" "hooks/post-edit-lint.sh")"
assert_eq "override: hook library needs a pin" "2" "$(override_rc "hooks/_lib.sh" "hooks/_lib.sh")"
assert_eq "override: matching pin honoured" "0" "$(override_rc "hooks/validate-bash.sh@${UNIT_SHA}" "hooks/validate-bash.sh" "${UNIT_DIR}/hook.sh")"
assert_eq "override: stale pin not honoured" "2" "$(override_rc "hooks/validate-bash.sh@${UNIT_SHA}0" "hooks/validate-bash.sh" "${UNIT_DIR}/hook.sh")"
assert_eq "override: pin without file to check is honoured" "0" "$(override_rc "hooks/validate-bash.sh@${UNIT_SHA}" "hooks/validate-bash.sh")"
env_rc=$(
    export CLAUDE_PROJECT_DIR="$UNIT_DIR"
    export CC_LOCAL_OVERRIDES="hooks/post-edit-lint.sh"
    # shellcheck disable=SC1091
    source "${ROOT_DIR}/core/hooks/_lib.sh"
    _cc_load_config
    rc=0
    _cc_is_local_override "hooks/post-edit-lint.sh" || rc=$?
    echo "$rc"
)
assert_eq "override: environment value is ignored" "1" "$env_rc"
(
    export CLAUDE_PROJECT_DIR="$UNIT_DIR"
    export CC_INSTALL_DIR="${UNIT_DIR}-elsewhere"
    # shellcheck disable=SC1091
    source "${ROOT_DIR}/core/hooks/_lib.sh"
    _cc_security_log "INFO" "test" "log location"
)
assert_file_exists "security log: inherited CC_INSTALL_DIR outside project ignored" "${UNIT_DIR}/.claude/cognitive-core/security.log"
if [ -e "${UNIT_DIR}-elsewhere" ]; then
    _fail "security log: nothing written outside the project"
    rm -rf "${UNIT_DIR}-elsewhere"
else
    _pass "security log: nothing written outside the project"
fi
rm -rf "$UNIT_DIR"

# ---- update.sh argument and platform handling ----
cli_dir=$(create_test_dir)
out=$(bash "${ROOT_DIR}/update.sh" --bogus "$cli_dir" 2>&1 && echo "rc=0" || echo "rc=1")
assert_contains "cli: unknown option rejected" "$out" "Unknown option: --bogus"
assert_contains "cli: unknown option exits nonzero" "$out" "rc=1"
out=$(bash "${ROOT_DIR}/update.sh" --dry-run "$cli_dir" 2>&1 && echo "rc=0" || echo "rc=1")
assert_contains "cli: --dry-run without --prune rejected" "$out" "rc=1"
printf 'CC_PLATFORM="../../tmp/x"\n' > "${cli_dir}/cognitive-core.conf"
out=$(bash "${ROOT_DIR}/update.sh" "$cli_dir" 2>&1 && echo "rc=0" || echo "rc=1")
assert_contains "cli: path-like CC_PLATFORM rejected" "$out" "Invalid CC_PLATFORM"
assert_contains "cli: path-like CC_PLATFORM exits nonzero" "$out" "rc=1"
rm -f "${cli_dir}/cognitive-core.conf"
mkdir -p "${cli_dir}/.claude"
printf 'CC_PLATFORM="nosuchplatform"\n' > "${cli_dir}/.claude/cognitive-core.conf"
out=$(bash "${ROOT_DIR}/update.sh" "$cli_dir" 2>&1 && echo "rc=0" || echo "rc=1")
assert_contains "cli: CC_PLATFORM read from .claude/cognitive-core.conf" "$out" "Unknown platform: nosuchplatform"
rm -rf "$cli_dir"

# run_scenario <platform> <install dir> [generated files referencing agents...]
# Drift at session start and settings.json hook wiring are Claude only.
# The claude conf omits CC_PLATFORM to cover the default.
run_scenario() {
    local platform="$1" inst="$2"
    shift 2
    local listfiles="$*"
    local p="[${platform}]"
    local test_dir conf root hooks out would_remove expected lf read_pin fetch_pin platform_line=""
    [ "$platform" = "claude" ] || platform_line="CC_PLATFORM=\"${platform}\""
    test_dir=$(create_test_dir)
    git -C "$test_dir" init --quiet 2>/dev/null
    conf="${test_dir}/cognitive-core.conf"
    root="${test_dir}/${inst}"
    hooks="${root}/hooks"

    cat > "$conf" << EOF
#!/bin/false
CC_PROJECT_NAME="override-test"
CC_PROJECT_DESCRIPTION="Override and prune test project"
CC_ORG="test-org"
${platform_line}
CC_LANGUAGE="python"
CC_LINT_EXTENSIONS=".py"
CC_LINT_COMMAND="ruff check \\\$1"
CC_FORMAT_COMMAND=""
CC_TEST_COMMAND="pytest"
CC_TEST_PATTERN="tests/**/*.py"
CC_DATABASE="none"
CC_ARCHITECTURE="ddd"
CC_SRC_ROOT="src"
CC_TEST_ROOT="tests"
CC_AGENTS="coordinator reviewer tester architect"
CC_COORDINATOR_MODEL="opus"
CC_SPECIALIST_MODEL="sonnet"
CC_SKILLS="session-resume code-review lint-debt batch-review fitness"
CC_HOOKS="setup-env compact-reminder validate-bash validate-read validate-write post-edit-lint notify-complete"
CC_MAIN_BRANCH="main"
CC_COMMIT_FORMAT="conventional"
CC_COMMIT_SCOPES="api core"
CC_ENABLE_CICD="false"
CC_RUNNER_TYPE="github-hosted"
CC_MONITORING="false"
CC_COMPACT_RULES="1. Follow standards"
CC_ENABLE_CLEANUP_CRON="false"
CC_SESSION_DOCS_DIR="docs"
CC_SESSION_MAX_AGE_DAYS="30"
CC_AGENT_TEAMS="false"
CC_MCP_SERVERS=""
EOF

    if ! bash "${ROOT_DIR}/install.sh" "$test_dir" >/dev/null 2>&1; then
        _fail "${p} install failed"
        rm -rf "$test_dir"
        return
    fi
    _pass "${p} install succeeds"

    # ---- Overrides ----
    # post-edit-lint: plain override, honoured without pin
    # validate-bash:  security hook listed without pin, not honoured
    # validate-read:  security hook pinned to its edited content, honoured
    # validate-write: modified but not listed
    # validate-fetch: newly selected, pinned, must not be installed
    # skills/fitness/SKILL.md: a file inside a skill keeps the whole skill
    for lf in post-edit-lint validate-bash validate-read validate-write; do
        echo "# local edit" >> "${hooks}/${lf}.sh"
    done
    read_pin="$(sha256_of "${hooks}/validate-read.sh")"
    fetch_pin="$(sha256_of "${ROOT_DIR}/core/hooks/validate-fetch.sh")"
    set_conf "$conf" CC_LOCAL_OVERRIDES "hooks/post-edit-lint.sh hooks/validate-bash.sh hooks/validate-read.sh@${read_pin} hooks/validate-fetch.sh@${fetch_pin} skills/batch-review/ skills/fitness/SKILL.md"
    set_conf "$conf" CC_HOOKS "setup-env compact-reminder validate-bash validate-read validate-write post-edit-lint notify-complete validate-fetch"

    if [ "$platform" = "claude" ]; then
        out=$(CLAUDE_PROJECT_DIR="$test_dir" bash "${hooks}/setup-env.sh" < /dev/null 2>/dev/null || true)
        assert_contains "${p} drift: unlisted modified hook reported" "$out" "validate-write.sh"
        assert_contains "${p} drift: unpinned security hook override reported" "$out" "validate-bash.sh"
        assert_not_contains "${p} drift: plain override not reported" "$out" "post-edit-lint.sh"
        assert_not_contains "${p} drift: pinned override not reported" "$out" "validate-read.sh"
        file_contains "${p} drift: honoured override logged" "${root}/cognitive-core/security.log" "Project-owned hook: post-edit-lint.sh"
        file_contains "${p} drift: ignored override logged" "${root}/cognitive-core/security.log" "Override not honoured (security hook needs a matching sha256 pin): validate-bash.sh"

        out=$(CC_LOCAL_OVERRIDES="hooks/validate-write.sh" CLAUDE_PROJECT_DIR="$test_dir" bash "${hooks}/setup-env.sh" < /dev/null 2>/dev/null || true)
        assert_contains "${p} drift: override from environment ignored" "$out" "validate-write.sh"

        # A pre-#328 installed _lib.sh lacks _cc_is_local_override
        cp "${hooks}/_lib.sh" "${test_dir}/lib.bak"
        python3 -c '
import re, sys
path = sys.argv[1]
src = open(path).read()
open(path, "w").write(re.sub(r"\n_cc_is_local_override\(\) \{.*?\n\}\n", "\n", src, flags=re.S))
' "${hooks}/_lib.sh"
        out=$(CLAUDE_PROJECT_DIR="$test_dir" bash "${hooks}/setup-env.sh" < /dev/null 2>&1 || true)
        assert_not_contains "${p} drift: old _lib.sh does not break setup-env" "$out" "command not found"
        assert_contains "${p} drift: old _lib.sh still reports drift" "$out" "validate-write.sh"
        cp "${test_dir}/lib.bak" "${hooks}/_lib.sh"
        rm -f "${test_dir}/lib.bak"
    fi

    if ! out=$(bash "${ROOT_DIR}/update.sh" "$test_dir" 2>&1); then
        _fail "${p} update 1 failed" "$(tail -5 <<< "$out")"
        rm -rf "$test_dir"
        return
    fi
    assert_contains "${p} update: plain override owned" "$out" "OVERRIDE (project owned): ${inst}/hooks/post-edit-lint.sh"
    assert_contains "${p} update: pinned override owned" "$out" "OVERRIDE (project owned): ${inst}/hooks/validate-read.sh"
    assert_contains "${p} update: unpinned security override not honoured" "$out" "OVERRIDE NOT HONOURED: ${inst}/hooks/validate-bash.sh"
    assert_contains "${p} update: pin hint printed" "$out" "hooks/validate-bash.sh@"
    assert_contains "${p} update: unlisted modified hook preserved" "$out" "MODIFIED (preserved): ${inst}/hooks/validate-write.sh"
    if [ -e "${hooks}/validate-fetch.sh" ]; then
        _fail "${p} update: selected hook listed as override is not installed"
    else
        _pass "${p} update: selected hook listed as override is not installed"
    fi

    # Change the pinned hook again: the pin no longer holds
    echo "# edited after pinning" >> "${hooks}/validate-read.sh"
    if [ "$platform" = "claude" ]; then
        out=$(CLAUDE_PROJECT_DIR="$test_dir" bash "${hooks}/setup-env.sh" < /dev/null 2>/dev/null || true)
        assert_contains "${p} drift: change after pinning reported" "$out" "validate-read.sh"
    fi

    if ! out=$(bash "${ROOT_DIR}/update.sh" "$test_dir" 2>&1); then
        _fail "${p} update 2 failed" "$(tail -5 <<< "$out")"
        rm -rf "$test_dir"
        return
    fi
    assert_contains "${p} update 2: stale pin not honoured" "$out" "OVERRIDE NOT HONOURED: ${inst}/hooks/validate-read.sh"
    assert_contains "${p} update 2: modified hook still preserved (baseline kept)" "$out" "MODIFIED (preserved): ${inst}/hooks/validate-write.sh"
    for lf in post-edit-lint validate-bash validate-read validate-write; do
        file_contains "${p} local edit in ${lf}.sh survives two updates" "${hooks}/${lf}.sh" "# local edit"
    done

    # ---- Prune ----
    # Deselect: tester, architect (modified), lint-debt, batch-review and
    # fitness (overridden), compact-reminder, notify-complete, validate-fetch.
    set_conf "$conf" CC_AGENTS "coordinator reviewer"
    set_conf "$conf" CC_SKILLS "session-resume code-review"
    set_conf "$conf" CC_HOOKS "setup-env validate-bash validate-read validate-write post-edit-lint"
    echo "# local agent" > "${root}/agents/my-local-agent.md"
    echo "# local edit" >> "${root}/agents/solution-architect.md"

    if [ "$platform" = "claude" ]; then
        # notify-complete unwired, compact-reminder wired only in settings.local.json
        python3 -c '
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
for event, groups in data.get("hooks", {}).items():
    for group in groups:
        group["hooks"] = [h for h in group.get("hooks", [])
                          if "notify-complete.sh" not in h.get("command", "")
                          and "compact-reminder.sh" not in h.get("command", "")]
    data["hooks"][event] = [g for g in groups if g["hooks"]]
with open(path, "w") as f:
    json.dump(data, f, indent=2)
' "${root}/settings.json"
        printf '{"hooks": {"PreCompact": [{"hooks": [{"type": "command", "command": "%s/hooks/compact-reminder.sh"}]}]}}\n' "$inst" > "${root}/settings.local.json"
        expected="agents/test-specialist.md hooks/notify-complete.sh skills/lint-debt/ "
    else
        # No hook wiring outside Claude: compact-reminder is pruned too
        expected="agents/test-specialist.md hooks/compact-reminder.sh hooks/notify-complete.sh skills/lint-debt/ "
    fi
    for lf in $listfiles; do
        file_contains "${p} setup: ${lf} references tester agent" "${test_dir}/${lf}" "${inst}/agents/test-specialist.md"
    done

    out=$(bash "${ROOT_DIR}/update.sh" --prune --dry-run "$test_dir" 2>&1) || _fail "${p} prune dry run failed" "$(tail -5 <<< "$out")"
    would_remove=$(grep -F "WOULD REMOVE:" <<< "$out" | sed 's/.*WOULD REMOVE: //' | sort | tr '\n' ' ')
    assert_eq "${p} dry run lists exactly the unselected components" "$expected" "$would_remove"
    assert_contains "${p} dry run keeps modified component" "$out" "KEPT (modified since install): agents/solution-architect.md"
    if [ "$platform" = "claude" ]; then
        assert_contains "${p} dry run keeps hook wired in settings.local.json" "$out" "KEPT (still wired): hooks/compact-reminder.sh"
    fi
    assert_file_exists "${p} dry run changes nothing (agent)" "${root}/agents/test-specialist.md"
    assert_dir_exists "${p} dry run changes nothing (skill)" "${root}/skills/lint-debt"
    assert_file_exists "${p} dry run changes nothing (hook)" "${hooks}/notify-complete.sh"

    if ! out=$(bash "${ROOT_DIR}/update.sh" --prune "$test_dir" 2>&1); then
        _fail "${p} prune failed" "$(tail -5 <<< "$out")"
        rm -rf "$test_dir"
        return
    fi
    assert_contains "${p} prune reports removal" "$out" "REMOVED: agents/test-specialist.md"
    if [ ! -e "${root}/agents/test-specialist.md" ] \
            && [ ! -e "${root}/skills/lint-debt" ] \
            && [ ! -e "${hooks}/notify-complete.sh" ]; then
        _pass "${p} prune removes unselected components"
    else
        _fail "${p} prune removes unselected components"
    fi
    if [ "$platform" = "claude" ]; then
        assert_file_exists "${p} prune keeps wired hook" "${hooks}/compact-reminder.sh"
    fi
    for lf in $listfiles; do
        file_lacks "${p} prune drops tester reference from ${lf}" "${test_dir}/${lf}" "${inst}/agents/test-specialist.md"
        file_contains "${p} prune keeps reviewer reference in ${lf}" "${test_dir}/${lf}" "${inst}/agents/code-standards-reviewer.md"
    done
    assert_file_exists "${p} prune keeps modified component" "${root}/agents/solution-architect.md"
    assert_dir_exists "${p} prune keeps listed override skill" "${root}/skills/batch-review"
    assert_dir_exists "${p} prune keeps skill with an overridden file" "${root}/skills/fitness"
    assert_file_exists "${p} prune keeps local agent" "${root}/agents/my-local-agent.md"
    assert_file_exists "${p} prune keeps hook library" "${hooks}/_lib.sh"
    assert_file_exists "${p} prune keeps selected agent" "${root}/agents/code-standards-reviewer.md"
    file_contains "${p} prune leaves override content in place" "${hooks}/post-edit-lint.sh" "# local edit"
    file_lacks "${p} manifest drops pruned files" "${root}/cognitive-core/version.json" "lint-debt/"
    file_contains "${p} manifest keeps remaining files" "${root}/cognitive-core/version.json" "${inst}/agents/code-standards-reviewer.md"
    if [ -d "${test_dir}/.claude" ] && [ "$inst" != ".claude" ]; then
        _fail "${p} no stray .claude/ directory in a ${inst} install"
    else
        _pass "${p} no stray .claude/ directory in a ${inst} install"
    fi

    out=$(bash "${ROOT_DIR}/update.sh" --prune --dry-run "$test_dir" 2>&1) || _fail "${p} second dry run failed" "$(tail -5 <<< "$out")"
    assert_contains "${p} dry run with nothing left to prune" "$out" "Nothing to prune."

    # ---- Prune preflight (platform independent, claude only) ----
    if [ "$platform" = "claude" ]; then
        unset_conf "$conf" CC_SKILLS
        out=$(bash "${ROOT_DIR}/update.sh" --prune --dry-run "$test_dir" 2>&1 && echo "rc=0" || echo "rc=1")
        assert_contains "${p} preflight: missing selection list refused" "$out" "CC_AGENTS, CC_SKILLS and CC_HOOKS must all be set"
        assert_contains "${p} preflight: missing selection list exits nonzero" "$out" "rc=1"
        set_conf "$conf" CC_SKILLS "session-resume code-review"

        for lf in skills agents hooks; do
            mv "${root}/${lf}" "${root}/${lf}.real"
            ln -s "${root}/${lf}.real" "${root}/${lf}"
            out=$(bash "${ROOT_DIR}/update.sh" --prune --dry-run "$test_dir" 2>&1 && echo "rc=0" || echo "rc=1")
            assert_contains "${p} preflight: symlinked ${lf} dir refused" "$out" "/${inst}/${lf} is a symlink"
            rm "${root}/${lf}"
            mv "${root}/${lf}.real" "${root}/${lf}"
        done

        # The conf cannot move the install dir through the adapter constant.
        # The decoy holds an unselected agent that a redirected prune would plan on.
        mkdir -p "${test_dir}/decoy/agents"
        cp "${ROOT_DIR}/core/agents/test-specialist.md" "${test_dir}/decoy/agents/"
        set_conf "$conf" _ADAPTER_INSTALL_DIR "decoy"
        out=$(bash "${ROOT_DIR}/update.sh" --prune --dry-run "$test_dir" 2>&1) || _fail "${p} decoy dry run failed" "$(tail -5 <<< "$out")"
        assert_contains "${p} preflight: conf cannot redirect the install dir (plans real dir)" "$out" "Nothing to prune."
        assert_not_contains "${p} preflight: conf cannot redirect the install dir (decoy ignored)" "$out" "agents/test-specialist.md"
        unset_conf "$conf" _ADAPTER_INSTALL_DIR
        rm -rf "${test_dir}/decoy"

        mv "$conf" "${test_dir}/conf.bak"
        out=$(bash "${ROOT_DIR}/update.sh" --prune --dry-run "$test_dir" 2>&1 && echo "rc=0" || echo "rc=1")
        assert_contains "${p} preflight: missing conf refused" "$out" "Refusing to prune: no cognitive-core.conf"
        mv "${test_dir}/conf.bak" "$conf"
    fi

    rm -rf "$test_dir"
}

run_scenario claude .claude
run_scenario aider .cognitive-core .aider.conf.yml CONVENTIONS.md
run_scenario intellij .cognitive-core .devoxxgenie.yaml DEVOXXGENIE.md
run_scenario vscode .cognitive-core .github/copilot-instructions.md

rm -rf "$HOME"

suite_end
