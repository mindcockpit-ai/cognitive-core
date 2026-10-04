#!/bin/bash
# Test suite: update.sh adds framework files missing from installed skills (#359)
# Simulates an install made before a skill gained files (project-board
# providers), then checks on disk that update.sh adds exactly those files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "27 - Update Adds Skill Files"

if ! command -v python3 &>/dev/null; then
    _skip "python3 not available (needed for update.sh)"
    suite_end || true
    exit 0
fi

# A developer's ~/.cognitive-core/defaults.conf or plugin cache must not leak in
HOME_DIR="$(create_test_dir)"
test_dir=$(create_test_dir)
out_link=$(create_test_dir)      # target of a symlinked skill subdir
out_dest=$(create_test_dir)      # target of a dangling symlinked dest file
out_skill=$(create_test_dir)     # target of a symlinked skill dir
trap 'rm -rf "$HOME_DIR" "$test_dir" "$out_link" "$out_dest" "$out_skill"' EXIT
HOME="$HOME_DIR"
export HOME
unset CC_LOCAL_OVERRIDES CC_AGENTS CC_SKILLS CC_HOOKS CLAUDE_PROJECT_DIR CC_INSTALL_DIR

git -C "$test_dir" init --quiet 2>/dev/null
conf="${test_dir}/cognitive-core.conf"
skills="${test_dir}/.claude/skills"
fw="${ROOT_DIR}/core/skills"

sha256_of() {
    python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"
}
# Every file, symlink and directory below a skills dir, relative, stable order
skill_tree() {
    (cd "${1:-$skills}" && find . -mindepth 1 \( -type f -o -type l -o -type d \) | sed 's|^\./||' | LC_ALL=C sort)
}

cat > "$conf" << 'EOF'
#!/bin/false
CC_PROJECT_NAME="skill-files-test"
CC_PROJECT_DESCRIPTION="update.sh skill file test"
CC_ORG="test-org"
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
CC_AGENTS="coordinator reviewer"
CC_COORDINATOR_MODEL="opus"
CC_SPECIALIST_MODEL="sonnet"
CC_SKILLS="session-resume project-board security-baseline workspace-monitor"
CC_HOOKS="setup-env compact-reminder validate-bash"
CC_MAIN_BRANCH="main"
CC_COMMIT_FORMAT="conventional"
CC_COMMIT_SCOPES="api core"
CC_ENABLE_CICD="false"
CC_RUNNER_TYPE="github-hosted"
CC_MONITORING="false"
CC_COMPACT_RULES="1. Follow standards"
EOF

if ! bash "${ROOT_DIR}/install.sh" "$test_dir" >/dev/null 2>&1; then
    _fail "install failed"
    suite_end || true
    exit 1
fi
_pass "install succeeded"

# ---- Simulate an install from before these files existed ----
# Files update.sh must add (relative to .claude/skills), LC_ALL=C order
expected_new="project-board/_provider-lib.sh
project-board/providers/github.sh
project-board/providers/jira.sh
project-board/providers/youtrack.sh
python-ddd/SKILL.md"
rm -rf "${skills}/project-board/providers"
rm -f "${skills}/project-board/_provider-lib.sh" "${skills}/python-ddd/SKILL.md"

# Must stay as they are
printf 'local edit\n' >> "${skills}/project-board/SKILL.md"
edited_sha=$(sha256_of "${skills}/project-board/SKILL.md")
printf 'project notes\n' > "${skills}/project-board/local-notes.md"
mkdir -p "${skills}/my-skill" && printf 'custom\n' > "${skills}/my-skill/SKILL.md"
# Overrides: a directory entry and a single-file entry
rm -f "${skills}/security-baseline/references/ssrf-config-registry.md" "${skills}/project-board/validate-prompt.sh"
chmod u+w "$conf"
printf 'CC_LOCAL_OVERRIDES="skills/security-baseline/ skills/project-board/validate-prompt.sh"\n' >> "$conf"
# Symlinked subdir: workspace-monitor/references points outside the project
rm -rf "${skills}/workspace-monitor/references"
ln -s "$out_link" "${skills}/workspace-monitor/references"
# Dangling symlink at a missing destination file
rm -f "${skills}/project-board/references/recipes.md"
ln -s "${out_dest}/missing.md" "${skills}/project-board/references/recipes.md"
# Symlinked skill dir
rm -rf "${skills}/session-resume"
ln -s "$out_skill" "${skills}/session-resume"
# Installed but unselected skill (prune candidate): gets nothing
mkdir -p "${skills}/smoke-test" && cp "${fw}/smoke-test/SKILL.md" "${skills}/smoke-test/"

# Sanity: the fixtures really are missing framework files
for rel in $expected_new project-board/validate-prompt.sh security-baseline/references/ssrf-config-registry.md smoke-test/scripts/preflight.sh; do
    case "$rel" in python-ddd/*) src="${ROOT_DIR}/language-packs/python/skills/${rel}" ;; *) src="${fw}/${rel}" ;; esac
    [ -f "$src" ] || _fail "fixture: framework source exists" "$src"
done

before=$(skill_tree)

# ---- First update ----
out=$(bash "${ROOT_DIR}/update.sh" "$test_dir" 2>&1) && rc=0 || rc=$?
assert_eq "update exits 0" "0" "$rc"

after=$(skill_tree)
added=$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after"))
removed=$(comm -23 <(printf '%s\n' "$before") <(printf '%s\n' "$after"))
# On disk the recreated providers/ directory shows up as well
expected_disk=$(printf '%s\nproject-board/providers\n' "$expected_new" | LC_ALL=C sort)
assert_eq "files added on disk are exactly the missing ones" "$expected_disk" "$added"
assert_eq "no file removed" "" "$removed"

reported=$(printf '%s\n' "$out" | sed -n 's/.*NEW (skill file): skills\///p' | LC_ALL=C sort)
assert_eq "report matches what was added" "$expected_new" "$reported"
assert_contains "summary counts the new files" "$out" "New:       5 file(s)"

verified=0
while IFS= read -r rel; do
    case "$rel" in
        python-ddd/*) src="${ROOT_DIR}/language-packs/python/skills/${rel}" ;;
        *) src="${fw}/${rel}" ;;
    esac
    if cmp -s "$src" "${skills}/${rel}"; then
        _pass "identical to framework: ${rel}"
    else
        _fail "identical to framework: ${rel}" "missing or different"
    fi
    case "$rel" in
        project-board/providers/*.sh) assert_file_executable "exec bit kept: ${rel}" "${skills}/${rel}" ;;
    esac
    verified=$((verified + 1))
done <<< "$expected_new"
assert_eq "all expected files verified" "5" "$verified"

assert_eq "user-edited SKILL.md kept" "$edited_sha" "$(sha256_of "${skills}/project-board/SKILL.md")"
assert_eq "project-local file kept" "project notes" "$(cat "${skills}/project-board/local-notes.md")"
assert_eq "skill without framework source untouched" "SKILL.md" "$(ls "${skills}/my-skill")"
if [ -e "${skills}/security-baseline/references/ssrf-config-registry.md" ]; then
    _fail "directory override honoured" "ssrf-config-registry.md restored"
else
    _pass "directory override honoured"
fi
if [ -e "${skills}/project-board/validate-prompt.sh" ]; then
    _fail "file override honoured" "validate-prompt.sh restored"
else
    _pass "file override honoured"
fi
assert_eq "unselected skill gets nothing" "SKILL.md" "$(ls "${skills}/smoke-test")"
if [ -L "${skills}/project-board/references/recipes.md" ]; then
    _pass "dangling symlink dest left alone"
else
    _fail "dangling symlink dest left alone" "replaced"
fi
assert_eq "nothing written through a symlinked subdir" "" "$(ls -A "$out_link")"
assert_eq "nothing written through a dangling symlink" "" "$(ls -A "$out_dest")"
assert_eq "nothing written into a symlinked skill dir" "" "$(ls -A "$out_skill")"
assert_contains "symlinked path reported" "$out" "SKIP (symlink in path): skills/workspace-monitor/references/error-patterns.md"
assert_eq "symlinked skill dir skipped quietly" "0" "$(printf '%s\n' "$out" | grep -c 'SKIP (symlink in path): skills/session-resume/' || true)"

manifest_missing=$(python3 - "${test_dir}/.claude/cognitive-core/version.json" "$expected_new" << 'PY'
import json, sys
paths = {f["path"] for f in json.load(open(sys.argv[1]))["files"]}
need = [".claude/skills/" + r for r in sys.argv[2].split("\n") if r]
print(" ".join(p for p in need if p not in paths))
PY
)
assert_eq "every added file is in the manifest" "" "$manifest_missing"

# ---- Second update changes nothing on disk ----
out2=$(bash "${ROOT_DIR}/update.sh" "$test_dir" 2>&1) && rc2=0 || rc2=$?
assert_eq "second update exits 0" "0" "$rc2"
assert_eq "second update leaves the skill tree unchanged" "$after" "$(skill_tree)"
assert_eq "second update reports no skill files" "0" "$(printf '%s\n' "$out2" | grep -c 'NEW (skill file)' || true)"

# ---- skills/ itself a symlink: nothing added ----
real_skills="${HOME_DIR}/real-skills"
mv "$skills" "$real_skills"
ln -s "$real_skills" "$skills"
rm -f "${real_skills}/project-board/providers/github.sh"
tree_before=$(skill_tree "$real_skills")
out3=$(bash "${ROOT_DIR}/update.sh" "$test_dir" 2>&1) && rc3=0 || rc3=$?
assert_eq "update with symlinked skills/ exits 0" "0" "$rc3"
if [ -e "${real_skills}/project-board/providers/github.sh" ]; then
    _fail "nothing added through a symlinked skills/" "github.sh restored"
else
    _pass "nothing added through a symlinked skills/"
fi
assert_contains "symlinked skills/ reported" "$out3" "SKIP (symlink): .claude/skills"
assert_eq "symlinked skills/ tree unchanged" "$tree_before" "$(skill_tree "$real_skills")"

suite_end
