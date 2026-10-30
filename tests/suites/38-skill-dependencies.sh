#!/bin/bash
# Test suite 38 - Skill dependencies (requires-skills) and new skills in update.sh
#   - _cc_skill_requires / _cc_expand_skill_deps (adapters/_adapter-lib.sh)
#   - install.sh installs required skills for every adapter (#433)
#   - update.sh installs missing selected and required skills (#423, #433)
#   - update.sh --prune keeps required skills; --dry-run reports skills to add
#   - the plugin ships the grounding skill
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"
suite_start "38 - Skill Dependencies"

if ! command -v python3 &>/dev/null; then
    _skip "python3 not available (needed for update.sh)"
    suite_end || true
    exit 0
fi

HOME_DIR="$(create_test_dir)"
FAKE_FW="$(create_test_dir)"
PROJECTS="$(create_test_dir)"
trap 'rm -rf "$HOME_DIR" "$FAKE_FW" "$PROJECTS"' EXIT
HOME="$HOME_DIR"
export HOME
unset CC_LOCAL_OVERRIDES CC_AGENTS CC_SKILLS CC_HOOKS CLAUDE_PROJECT_DIR CC_INSTALL_DIR CC_LANGUAGE
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

# =============================================================================
# Section 1: Resolver
# =============================================================================

# shellcheck disable=SC1091
source "${ROOT_DIR}/adapters/_adapter-lib.sh"

assert_eq "requires: project-board needs grounding" "grounding" \
    "$(_cc_skill_requires "${ROOT_DIR}/core/skills/project-board/SKILL.md")"
assert_eq "requires: grounding needs nothing" "" \
    "$(_cc_skill_requires "${ROOT_DIR}/core/skills/grounding/SKILL.md")"
assert_eq "requires: missing SKILL.md is empty" "" \
    "$(_cc_skill_requires "${FAKE_FW}/nope/SKILL.md")"

# Fake framework: a -> b -> c -> a (cycle), d has an invalid name and a
# requires-skills line outside the frontmatter
mkdir -p "${FAKE_FW}/core/skills/"{a,b,c,d}
printf -- '---\nname: a\nrequires-skills: [b]\n---\n' > "${FAKE_FW}/core/skills/a/SKILL.md"
printf -- '---\nname: b\nrequires-skills: [c, a]\n---\n' > "${FAKE_FW}/core/skills/b/SKILL.md"
printf -- '---\nname: c\nrequires-skills: [a]\n---\n' > "${FAKE_FW}/core/skills/c/SKILL.md"
printf -- '---\nname: d\nrequires-skills: [Bad_Name, ../x]\n---\nrequires-skills: [a]\n' > "${FAKE_FW}/core/skills/d/SKILL.md"

assert_eq "expand: transitive, cycle terminates, selection first" "a b c" \
    "$(_cc_expand_skill_deps "a" "$FAKE_FW")"
assert_eq "expand: duplicates collapse" "c a b" \
    "$(_cc_expand_skill_deps "c a c" "$FAKE_FW")"
assert_eq "expand: invalid names and body lines ignored" "d" \
    "$(_cc_expand_skill_deps "d" "$FAKE_FW")"
assert_eq "expand: empty selection" "" "$(_cc_expand_skill_deps "" "$FAKE_FW")"
assert_eq "expand: unknown skill kept as given" "zzz" "$(_cc_expand_skill_deps "zzz" "$FAKE_FW")"

# =============================================================================
# Section 2: install.sh, every adapter
# =============================================================================

write_conf() {
    # write_conf <project dir> <platform> <skills>
    cat > "${1}/cognitive-core.conf" << EOF
CC_PROJECT_NAME="deps-test"
CC_PROJECT_DESCRIPTION="skill dependency test"
CC_ORG="test-org"
CC_PLATFORM="${2}"
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
CC_AGENTS="coordinator reviewer"
CC_COORDINATOR_MODEL="opus"
CC_SPECIALIST_MODEL="sonnet"
CC_SKILLS="${3}"
CC_HOOKS="setup-env validate-bash"
CC_MAIN_BRANCH="main"
CC_COMMIT_FORMAT="conventional"
CC_COMMIT_SCOPES="api core"
CC_ENABLE_CICD="false"
CC_RUNNER_TYPE="github-hosted"
CC_MONITORING="false"
CC_COMPACT_RULES="1. Follow standards"
EOF
}

new_project() {
    # new_project <name> <platform> <skills> -> prints the project dir
    local dir="${PROJECTS}/${1}"
    mkdir -p "$dir"
    git -C "$dir" init --quiet 2>/dev/null
    write_conf "$dir" "$2" "$3"
    printf '%s\n' "$dir"
}

for platform in claude aider intellij vscode; do
    case "$platform" in
        claude) idir=".claude" ;;
        *) idir=".cognitive-core" ;;
    esac
    proj=$(new_project "install-${platform}" "$platform" "project-board")
    out=$(bash "${ROOT_DIR}/install.sh" "$proj" 2>&1) && rc=0 || rc=$?
    assert_eq "[${platform}] install exits 0" "0" "$rc"
    engine="${proj}/${idir}/skills/grounding/scripts/check.sh"
    assert_file_exists "[${platform}] grounding engine installed with project-board only" "$engine"
    if [ -x "$engine" ]; then _pass "[${platform}] engine is executable"; else _fail "[${platform}] engine is executable"; fi
    assert_contains "[${platform}] install names the required skill" "$out" \
        "Installed skill: grounding (required by a selected skill)"
    assert_contains "[${platform}] engine answers --version" \
        "$(bash "$engine" --version 2>&1)" "grounding "
    assert_contains "[${platform}] conf keeps the user's selection" \
        "$(grep '^CC_SKILLS=' "${proj}/cognitive-core.conf")" 'CC_SKILLS="project-board"'
done

# =============================================================================
# Section 3: update.sh adds missing skills (claude adapter)
# =============================================================================

proj=$(new_project "update" "claude" "project-board")
bash "${ROOT_DIR}/install.sh" "$proj" >/dev/null 2>&1 || _fail "update fixture: install"
skills="${proj}/.claude/skills"

# Older install: no grounding yet. Also select a skill that is not installed
# (#423) and leave one unselected skill uninstalled.
rm -rf "${skills}/grounding"
chmod u+w "${proj}/cognitive-core.conf"
sed -i.bak 's/^CC_SKILLS=.*/CC_SKILLS="project-board lint-debt"/' "${proj}/cognitive-core.conf"
rm -f "${proj}/cognitive-core.conf.bak"
[ ! -d "${skills}/lint-debt" ] || _fail "update fixture: lint-debt not installed yet"

out=$(bash "${ROOT_DIR}/update.sh" --prune --dry-run "$proj" 2>&1) && rc=0 || rc=$?
assert_eq "dry run exits 0" "0" "$rc"
assert_contains "dry run reports the required skill" "$out" "WOULD ADD (skill): grounding"
assert_contains "dry run reports the newly selected skill" "$out" "WOULD ADD (skill): lint-debt"
assert_not_contains "dry run never removes the required skill" "$out" "WOULD REMOVE: skills/grounding/"
[ ! -d "${skills}/grounding" ] && _pass "dry run changes nothing" || _fail "dry run changes nothing"

out=$(bash "${ROOT_DIR}/update.sh" "$proj" 2>&1) && rc=0 || rc=$?
assert_eq "update exits 0" "0" "$rc"
assert_contains "update reports the required skill as NEW" "$out" "NEW (skill): grounding"
assert_contains "update reports the selected skill as NEW (#423)" "$out" "NEW (skill): lint-debt"
assert_file_exists "update installs the required skill" "${skills}/grounding/scripts/check.sh"
if [ -x "${skills}/grounding/scripts/check.sh" ]; then _pass "update keeps exec bits"; else _fail "update keeps exec bits"; fi
assert_file_exists "update installs the selected skill (#423)" "${skills}/lint-debt/SKILL.md"
[ ! -d "${skills}/smoke-test" ] && _pass "unselected skill stays uninstalled" || _fail "unselected skill stays uninstalled"
diff -rq "${ROOT_DIR}/core/skills/grounding" "${skills}/grounding" >/dev/null \
    && _pass "installed grounding matches the framework" || _fail "installed grounding matches the framework"
assert_contains "manifest records the new skill" \
    "$(cat "${proj}/.claude/cognitive-core/version.json")" "skills/grounding/scripts/check.sh"

out=$(bash "${ROOT_DIR}/update.sh" "$proj" 2>&1) && rc=0 || rc=$?
assert_not_contains "second update adds nothing" "$out" "NEW (skill)"

out=$(bash "${ROOT_DIR}/update.sh" --prune --dry-run "$proj" 2>&1) || true
assert_not_contains "prune keeps the required skill" "$out" "WOULD REMOVE: skills/grounding/"

# A local override keeps a removed skill removed
rm -rf "${skills}/grounding"
printf 'CC_LOCAL_OVERRIDES="skills/grounding/"\n' >> "${proj}/cognitive-core.conf"
out=$(bash "${ROOT_DIR}/update.sh" "$proj" 2>&1) || true
assert_not_contains "override: skill is not reinstalled" "$out" "NEW (skill): grounding"

# =============================================================================
# Section 4: conf without CC_SKILLS (installed skills count as selected)
# =============================================================================

proj=$(new_project "noselection" "claude" "project-board")
bash "${ROOT_DIR}/install.sh" "$proj" >/dev/null 2>&1 || _fail "noselection fixture: install"
rm -rf "${proj}/.claude/skills/grounding"
chmod u+w "${proj}/cognitive-core.conf"
sed -i.bak '/^CC_SKILLS=/d' "${proj}/cognitive-core.conf"
rm -f "${proj}/cognitive-core.conf.bak"
out=$(bash "${ROOT_DIR}/update.sh" "$proj" 2>&1) && rc=0 || rc=$?
assert_eq "no CC_SKILLS: update exits 0" "0" "$rc"
assert_file_exists "no CC_SKILLS: required skill of an installed skill is added" \
    "${proj}/.claude/skills/grounding/scripts/check.sh"
[ ! -d "${proj}/.claude/skills/lint-debt" ] && _pass "no CC_SKILLS: nothing else is added" \
    || _fail "no CC_SKILLS: nothing else is added"

# =============================================================================
# Section 4b: plugin installs, symlinks, and invalid names
# =============================================================================

# Plugin install: core skills come from the plugin, update.sh adds no copy
proj=$(new_project "plugin" "claude" "project-board")
bash "${ROOT_DIR}/install.sh" "$proj" >/dev/null 2>&1 || _fail "plugin fixture: install"
rm -rf "${proj}/.claude/skills/grounding"
mkdir -p "${HOME}/.claude/plugins/cache/cognitive-core"   # same signal install.sh uses
out=$(bash "${ROOT_DIR}/update.sh" "$proj" 2>&1) || true
rm -rf "${HOME}/.claude/plugins"
assert_not_contains "plugin: update adds no core skill" "$out" "NEW (skill)"
[ ! -e "${proj}/.claude/skills/grounding" ] && _pass "plugin: no duplicate grounding in .claude" \
    || _fail "plugin: no duplicate grounding in .claude"

# Symlinked skills dir: nothing is written through it
proj=$(new_project "symlink" "claude" "project-board")
bash "${ROOT_DIR}/install.sh" "$proj" >/dev/null 2>&1 || _fail "symlink fixture: install"
outside="${PROJECTS}/outside-skills"
mv "${proj}/.claude/skills" "$outside"
rm -rf "${outside}/grounding"
ln -s "$outside" "${proj}/.claude/skills"
out=$(bash "${ROOT_DIR}/update.sh" "$proj" 2>&1) || true
[ ! -e "${outside}/grounding" ] && _pass "symlink: no skill written through a symlinked skills dir" \
    || _fail "symlink: no skill written through a symlinked skills dir"

# Invalid names in CC_SKILLS never reach a path
proj=$(new_project "badnames" "claude" ".. * project-board")
out=$(bash "${ROOT_DIR}/install.sh" "$proj" 2>&1) && rc=0 || rc=$?
assert_eq "bad names: install exits 0" "0" "$rc"
assert_contains "bad names: '..' reported" "$out" "Ignored invalid skill name: .."
assert_contains "bad names: '*' reported" "$out" "Ignored invalid skill name: *"
assert_not_contains "bad names: '..' never installed" "$out" "Installed skill: .."
assert_file_exists "bad names: valid skill still installed" "${proj}/.claude/skills/project-board/SKILL.md"
[ ! -e "${proj}/.claude/SKILL.md" ] && [ ! -e "${proj}/.claude/project-board" ] \
    && _pass "bad names: nothing copied outside skills/" || _fail "bad names: nothing copied outside skills/"
rm -rf "${proj}/.claude/skills/grounding"
out=$(bash "${ROOT_DIR}/update.sh" "$proj" 2>&1) && rc=0 || rc=$?
assert_eq "bad names: update exits 0" "0" "$rc"
assert_file_exists "bad names: update still adds the required skill" "${proj}/.claude/skills/grounding/scripts/check.sh"
[ ! -e "${proj}/.claude/SKILL.md" ] && _pass "bad names: update copies nothing outside skills/" \
    || _fail "bad names: update copies nothing outside skills/"

# =============================================================================
# Section 5: Plugin
# =============================================================================

diff -rq "${ROOT_DIR}/core/skills/grounding" "${ROOT_DIR}/plugin/skills/grounding" >/dev/null \
    && _pass "plugin ships grounding identical to core" || _fail "plugin ships grounding identical to core"
if grep -qF 'cp -R "${CORE_DIR}/skills/"* "${PLUGIN_DIR}/skills/"' "${ROOT_DIR}/build-plugin.sh"; then
    _pass "build-plugin.sh copies every core skill"
else
    _fail "build-plugin.sh copies every core skill" "core/skills copy line changed"
fi

suite_end
