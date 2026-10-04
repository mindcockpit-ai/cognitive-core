#!/bin/bash
# Test suite: ShellCheck every shell script in the repository (#375)
# Options come from .shellcheckrc; severity warning is the blocking level.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "01 - ShellCheck"

# ---- Post-edit lint wrapper (tests/lib/lint-file.sh) ----
lint="${ROOT_DIR}/tests/lib/lint-file.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# A user's SHELLCHECK_OPTS must not change the results
unset SHELLCHECK_OPTS
printf '#!/bin/bash\necho "$undefined_zz"\n' > "${tmp}/warn.sh"
printf '#!/bin/bash\nif true; then\n' > "${tmp}/broken.sh"
printf '#!/bin/bash\necho ok\n' > "${tmp}/clean.sh"
printf '#!/bin/bash\nx=1\necho $x\n' > "${tmp}/style.sh"
printf 'not shell\n' > "${tmp}/notes.txt"
printf 'def f(:\n    pass\n' > "${tmp}/broken.py"
printf 'print("ok")\n' > "${tmp}/clean.py"

assert_eq "lint .py: clean file is silent" "" "$(bash "$lint" "${tmp}/clean.py")"
assert_matches "lint .py: syntax error reported as file:line: message" "$(bash "$lint" "${tmp}/broken.py")" "^${tmp//./\\.}/broken\\.py:1: .+"
assert_eq "lint .py: no bytecode written" "" "$(find "$tmp" -name '__pycache__')"

# Without ShellCheck: bash -n (PATH holds only bash, as the wrapper's dependency)
nosc="${tmp}/nosc"
mkdir -p "$nosc"
ln -s "$BASH" "${nosc}/bash"
out=$(LC_ALL=C PATH="$nosc" "$BASH" "$lint" "${tmp}/broken.sh" 2>&1 || true)
assert_contains "lint .sh without shellcheck: file named" "$out" "${tmp}/broken.sh"
assert_contains "lint .sh without shellcheck: syntax error reported" "$out" "syntax error"
assert_eq "lint .sh without shellcheck: clean file is silent" "" "$(PATH="$nosc" "$BASH" "$lint" "${tmp}/clean.sh" 2>&1)"
assert_eq "lint: other extensions are silent" "" "$(bash "$lint" "${tmp}/notes.txt" 2>&1)"

# Repo conf wires the wrapper into the post-edit hook for .sh and .py
conf_cmd=$(env -i HOME="$HOME" PATH="$PATH" "$BASH" -c 'set -u; CC_PROJECT_DIR="$1"; source "$1/cognitive-core.conf"; printf "%s|%s" "$CC_LINT_COMMAND" "$CC_LINT_EXTENSIONS"' -- "$ROOT_DIR" || true)
assert_eq "conf: CC_LINT_COMMAND runs the wrapper" "bash tests/lib/lint-file.sh \$1|.py .sh" "$conf_cmd"
hook_out=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "${tmp}/broken.py" \
    | (cd "$ROOT_DIR" && CC_PROJECT_DIR="$ROOT_DIR" bash core/hooks/post-edit-lint.sh) || true)
assert_contains "hook: .py edit gets the compile result" "$hook_out" "broken.py:1: "

if command -v shellcheck &>/dev/null; then
    assert_matches "lint .sh: warning reported as file:line:col" "$(bash "$lint" "${tmp}/warn.sh")" "/warn\\.sh:2:[0-9]+: warning: undefined_zz"
    assert_contains "lint .sh: warning code reported" "$(bash "$lint" "${tmp}/warn.sh")" "[SC2154]"
    assert_eq "lint .sh: clean file is silent" "" "$(bash "$lint" "${tmp}/clean.sh")"
    assert_eq "lint .sh: style-only finding is silent (severity warning)" "" "$(bash "$lint" "${tmp}/style.sh")"
    hook_out=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "${tmp}/warn.sh" \
        | (cd "$ROOT_DIR" && CC_PROJECT_DIR="$ROOT_DIR" bash core/hooks/post-edit-lint.sh) || true)
    assert_contains "hook: .sh edit gets ShellCheck findings" "$hook_out" "[SC2154]"
fi

# ---- ShellCheck over the repository ----
if ! command -v shellcheck &>/dev/null; then
    _skip "shellcheck not installed"
    suite_end || true
    exit 0
fi

echo "  $(shellcheck --version | grep '^version:')"

if ! git -C "$ROOT_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
    _skip "not a git checkout: no file list"
    suite_end || true
    exit 0
fi

# Tracked and new (not ignored) scripts; deleted ones are skipped
files=()
while IFS= read -r rel; do
    [ -f "${ROOT_DIR}/${rel}" ] && files+=("$rel")
done < <(git -C "$ROOT_DIR" ls-files -co --exclude-standard '*.sh' | sort -u)

# Floor guards against a broken file list (the repository has ~150 scripts)
if [ "${#files[@]}" -lt 100 ]; then
    _fail "file list: expected at least 100 scripts, got ${#files[@]}"
    suite_end || true
    exit 1
fi

# One run for all files; findings are attributed per file (gcc format: path:line:col: ...)
sc_rc=0
output=$(cd "$ROOT_DIR" && shellcheck -S warning -f gcc "${files[@]}" 2>&1) || sc_rc=$?
# 0 = clean, 1 = findings; anything else is a ShellCheck failure
case "$sc_rc" in
    0) assert_eq "shellcheck: exit 0 means no output" "" "$output" ;;
    1) assert_matches "shellcheck: exit 1 comes with findings" "$output" ":[0-9]+:[0-9]+: " ;;
    *) _fail "shellcheck: exit ${sc_rc}" ;;
esac

for rel in "${files[@]}"; do
    findings=$(grep -E "^${rel//./\\.}:[0-9]+:" <<< "$output" || true)
    if [ -z "$findings" ]; then
        _pass "shellcheck: ${rel}"
    else
        _fail "shellcheck: ${rel} ($(wc -l <<< "$findings" | tr -d ' ') finding(s))"
        head -20 <<< "$findings"
    fi
done

# Output not attributed to any file (e.g. a crash or an unknown option) fails the suite
unattributed="$output"
for rel in "${files[@]}"; do
    unattributed=$(grep -vE "^${rel//./\\.}:[0-9]+:" <<< "$unattributed" || true)
done
assert_eq "shellcheck: no unattributed output" "" "$unattributed"

suite_end
