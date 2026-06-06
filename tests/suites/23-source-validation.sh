#!/bin/bash
# Test suite: _cc_validate_framework_source — $SOURCE validation guard (#256)
#
# Purpose: lock in the attack-vector coverage for the framework-source
# validation helper added to core/hooks/_lib.sh. Every consumer in the
# framework calls this helper before invoking update.sh or git against
# a path that originates in version.json (an untrusted config file).
#
# Pattern: source _lib.sh in a subshell, call _cc_validate_framework_source
# directly, assert on exit code, CC_VALIDATED_SOURCE, and security.log entries.
#
# TOCTOU note: this helper validates at call time. An attacker who mutates
# the path between validation and use can still bypass the check. That class
# of race is out of scope for this helper — documented via _skip below.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "23 — Source Validation"

LIB="${ROOT_DIR}/core/hooks/_lib.sh"

if [ ! -f "$LIB" ]; then
    _fail "prerequisite: _lib.sh not found at ${LIB}"
    suite_end || true
    exit 1
fi

# ----------------------------------------------------------------------
# Fixture builder: create a valid framework root with an executable
# update.sh. Returns the root path.
# ----------------------------------------------------------------------
_make_valid_root() {
    local d
    d=$(mktemp -d "${TMPDIR:-/tmp}/cc-vsrc-XXXXXX")
    printf '#!/bin/bash\nexit 0\n' > "${d}/update.sh"
    chmod 0755 "${d}/update.sh"
    printf '%s' "$d"
}

# Run the validator in a clean subshell with a specific CC_FRAMEWORK_ROOT.
# Echoes the exit code.
_run_validate() {
    local root="$1" path="$2" project_dir="$3"
    (
        set +e
        # CLAUDE_PROJECT_DIR is the anchor read by _lib.sh on source
        export CLAUDE_PROJECT_DIR="$project_dir"
        export CC_PROJECT_DIR="$project_dir"
        export CC_FRAMEWORK_ROOT="$root"
        # shellcheck disable=SC1090
        source "$LIB"
        # _lib.sh resets CC_PROJECT_DIR from CLAUDE_PROJECT_DIR; reassert just in case
        CC_PROJECT_DIR="$project_dir"
        _cc_validate_framework_source "$path" >/dev/null 2>&1
        echo "exit=$?"
        printf 'validated=%s\n' "${CC_VALIDATED_SOURCE:-}"
    )
}

# Run with CC_FRAMEWORK_ROOT explicitly unset
_run_validate_no_root() {
    local path="$1" project_dir="$2"
    (
        set +e
        export CLAUDE_PROJECT_DIR="$project_dir"
        export CC_PROJECT_DIR="$project_dir"
        unset CC_FRAMEWORK_ROOT
        # shellcheck disable=SC1090
        source "$LIB"
        CC_PROJECT_DIR="$project_dir"
        _cc_validate_framework_source "$path" >/dev/null 2>&1
        echo "exit=$?"
    )
}

_exit_code() {
    printf '%s' "$1" | grep -o 'exit=[0-9]*' | head -1 | cut -d= -f2
}

_validated() {
    printf '%s' "$1" | grep '^validated=' | head -1 | cut -d= -f2-
}

# ----------------------------------------------------------------------
# Happy-path fixture used by most tests
# ----------------------------------------------------------------------
VALID_ROOT=$(_make_valid_root)
PROJECT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/cc-vsrc-proj-XXXXXX")

# ----------------------------------------------------------------------
# Happy path — valid path accepted, CC_VALIDATED_SOURCE set
# ----------------------------------------------------------------------
out=$(_run_validate "$VALID_ROOT" "$VALID_ROOT" "$PROJECT_DIR")
assert_eq "happy: valid root accepted (exit 0)" "0" "$(_exit_code "$out")"

canon_root=$(cd "$VALID_ROOT" && pwd -P)
assert_eq "happy: CC_VALIDATED_SOURCE = canonical path" "$canon_root" "$(_validated "$out")"

# ----------------------------------------------------------------------
# Path form rejections
# ----------------------------------------------------------------------
out=$(_run_validate "$VALID_ROOT" "relative/path" "$PROJECT_DIR")
assert_eq "path form: relative path rejected" "1" "$(_exit_code "$out")"

out=$(_run_validate "$VALID_ROOT" "" "$PROJECT_DIR")
assert_eq "path form: empty path rejected" "1" "$(_exit_code "$out")"

out=$(_run_validate "$VALID_ROOT" "${VALID_ROOT}/../etc" "$PROJECT_DIR")
assert_eq "path form: .. segment rejected" "1" "$(_exit_code "$out")"

# Interior control char (newline). Command substitution strips trailing
# newlines, so construct a path with a newline in the middle.
NL_PATH=$(printf '%s\n%s' "$VALID_ROOT" "extra")
out=$(_run_validate "$VALID_ROOT" "$NL_PATH" "$PROJECT_DIR")
assert_eq "path form: control char (newline) rejected" "1" "$(_exit_code "$out")"

# Path with spaces — accepted as long as it resolves under the root
SPACE_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/cc vsrc space XXXXXX")
printf '#!/bin/bash\nexit 0\n' > "${SPACE_ROOT}/update.sh"
chmod 0755 "${SPACE_ROOT}/update.sh"
out=$(_run_validate "$SPACE_ROOT" "$SPACE_ROOT" "$PROJECT_DIR")
assert_eq "path form: path with spaces accepted" "0" "$(_exit_code "$out")"

# ----------------------------------------------------------------------
# Config rejections
# ----------------------------------------------------------------------
out=$(_run_validate_no_root "$VALID_ROOT" "$PROJECT_DIR")
assert_eq "config: CC_FRAMEWORK_ROOT unset rejected" "1" "$(_exit_code "$out")"

out=$(_run_validate "" "$VALID_ROOT" "$PROJECT_DIR")
assert_eq "config: CC_FRAMEWORK_ROOT empty rejected" "1" "$(_exit_code "$out")"

# ----------------------------------------------------------------------
# Boundary checks
# ----------------------------------------------------------------------
# Simple outside-root: different top-level directory
OUTSIDE=$(_make_valid_root)
out=$(_run_validate "$VALID_ROOT" "$OUTSIDE" "$PROJECT_DIR")
assert_eq "boundary: unrelated path outside root rejected" "1" "$(_exit_code "$out")"

# Sibling-prefix attack: root=/tmp/foo, path=/tmp/foobar
SIBLING_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/cc-sibXXXXXX")
SIBLING_TWIN="${SIBLING_ROOT}x"
mkdir -p "$SIBLING_TWIN"
printf '#!/bin/bash\nexit 0\n' > "${SIBLING_ROOT}/update.sh"
printf '#!/bin/bash\nexit 0\n' > "${SIBLING_TWIN}/update.sh"
chmod 0755 "${SIBLING_ROOT}/update.sh" "${SIBLING_TWIN}/update.sh"
out=$(_run_validate "$SIBLING_ROOT" "$SIBLING_TWIN" "$PROJECT_DIR")
assert_eq "boundary: sibling-prefix (root=X, path=Xtwin) rejected" "1" "$(_exit_code "$out")"

# Nested path inside root is accepted
NESTED_ROOT=$(_make_valid_root)
mkdir -p "${NESTED_ROOT}/subdir"
printf '#!/bin/bash\nexit 0\n' > "${NESTED_ROOT}/subdir/update.sh"
chmod 0755 "${NESTED_ROOT}/subdir/update.sh"
out=$(_run_validate "$NESTED_ROOT" "${NESTED_ROOT}/subdir" "$PROJECT_DIR")
assert_eq "boundary: nested path inside root accepted" "0" "$(_exit_code "$out")"

# ----------------------------------------------------------------------
# Symlink attacks
# ----------------------------------------------------------------------
# Symlink $SOURCE to a directory outside root
SYMLINK_OUTSIDE=$(mktemp -d "${TMPDIR:-/tmp}/cc-syXXXXXX")
printf '#!/bin/bash\nexit 0\n' > "${SYMLINK_OUTSIDE}/update.sh"
chmod 0755 "${SYMLINK_OUTSIDE}/update.sh"
LINK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/cc-linkXXXXXX")
rmdir "$LINK_DIR"
ln -s "$SYMLINK_OUTSIDE" "$LINK_DIR"
out=$(_run_validate "$VALID_ROOT" "$LINK_DIR" "$PROJECT_DIR")
assert_eq "symlink: SOURCE → outside-root rejected (after resolution)" "1" "$(_exit_code "$out")"

# Nested symlink chain: L1 → L2 → outside
CHAIN_TARGET=$(mktemp -d "${TMPDIR:-/tmp}/cc-chXXXXXX")
printf '#!/bin/bash\nexit 0\n' > "${CHAIN_TARGET}/update.sh"
chmod 0755 "${CHAIN_TARGET}/update.sh"
CHAIN_MID=$(mktemp -d "${TMPDIR:-/tmp}/cc-chm-dirXXXXXX")
rmdir "$CHAIN_MID"
ln -s "$CHAIN_TARGET" "$CHAIN_MID"
CHAIN_HEAD=$(mktemp -d "${TMPDIR:-/tmp}/cc-chh-dirXXXXXX")
rmdir "$CHAIN_HEAD"
ln -s "$CHAIN_MID" "$CHAIN_HEAD"
out=$(_run_validate "$VALID_ROOT" "$CHAIN_HEAD" "$PROJECT_DIR")
assert_eq "symlink: nested chain → outside-root rejected" "1" "$(_exit_code "$out")"

# update.sh is a symlink escaping the root
ESCAPE_SRC=$(mktemp -d "${TMPDIR:-/tmp}/cc-esXXXXXX")
ESCAPE_TGT=$(mktemp -d "${TMPDIR:-/tmp}/cc-esTgtXXXXXX")
printf '#!/bin/bash\nexit 0\n' > "${ESCAPE_TGT}/evil-update.sh"
chmod 0755 "${ESCAPE_TGT}/evil-update.sh"
ln -s "${ESCAPE_TGT}/evil-update.sh" "${ESCAPE_SRC}/update.sh"
out=$(_run_validate "$ESCAPE_SRC" "$ESCAPE_SRC" "$PROJECT_DIR")
assert_eq "symlink: update.sh as escaping symlink rejected" "1" "$(_exit_code "$out")"

# ----------------------------------------------------------------------
# File attribute checks
# ----------------------------------------------------------------------
# Missing update.sh
NO_UPDATER=$(mktemp -d "${TMPDIR:-/tmp}/cc-noupXXXXXX")
out=$(_run_validate "$NO_UPDATER" "$NO_UPDATER" "$PROJECT_DIR")
assert_eq "file: missing update.sh rejected" "1" "$(_exit_code "$out")"

# Non-executable update.sh
NOEX_ROOT=$(_make_valid_root)
chmod 0644 "${NOEX_ROOT}/update.sh"
out=$(_run_validate "$NOEX_ROOT" "$NOEX_ROOT" "$PROJECT_DIR")
assert_eq "file: non-executable update.sh rejected" "1" "$(_exit_code "$out")"

# SUID update.sh — may fail on some filesystems that strip suid bits
SUID_ROOT=$(_make_valid_root)
if chmod 4755 "${SUID_ROOT}/update.sh" 2>/dev/null; then
    perms=$(stat -f %p "${SUID_ROOT}/update.sh" 2>/dev/null || stat -c %a "${SUID_ROOT}/update.sh")
    # Check the setuid bit actually stuck (digit at position length-3 is 4/5/6/7)
    plen=${#perms}
    if [ "$plen" -ge 4 ]; then
        spc=$(printf '%s' "$perms" | cut -c$((plen - 3)))
    else
        spc=0
    fi
    case "$spc" in
        4|5|6|7)
            out=$(_run_validate "$SUID_ROOT" "$SUID_ROOT" "$PROJECT_DIR")
            assert_eq "file: setuid update.sh rejected" "1" "$(_exit_code "$out")"
            ;;
        *)
            _skip "file: setuid rejection (bit did not stick on this filesystem)"
            ;;
    esac
else
    _skip "file: setuid rejection (chmod 4755 not permitted)"
fi

# SETGID update.sh
SGID_ROOT=$(_make_valid_root)
if chmod 2755 "${SGID_ROOT}/update.sh" 2>/dev/null; then
    perms=$(stat -f %p "${SGID_ROOT}/update.sh" 2>/dev/null || stat -c %a "${SGID_ROOT}/update.sh")
    plen=${#perms}
    if [ "$plen" -ge 4 ]; then
        spc=$(printf '%s' "$perms" | cut -c$((plen - 3)))
    else
        spc=0
    fi
    case "$spc" in
        2|3|6|7)
            out=$(_run_validate "$SGID_ROOT" "$SGID_ROOT" "$PROJECT_DIR")
            assert_eq "file: setgid update.sh rejected" "1" "$(_exit_code "$out")"
            ;;
        *)
            _skip "file: setgid rejection (bit did not stick on this filesystem)"
            ;;
    esac
else
    _skip "file: setgid rejection (chmod 2755 not permitted)"
fi

# update.sh is a directory, not a regular file
DIR_UP=$(mktemp -d "${TMPDIR:-/tmp}/cc-dirupXXXXXX")
mkdir -p "${DIR_UP}/update.sh"
out=$(_run_validate "$DIR_UP" "$DIR_UP" "$PROJECT_DIR")
assert_eq "file: update.sh as directory rejected" "1" "$(_exit_code "$out")"

# ----------------------------------------------------------------------
# Ownership check — only meaningful when we can chown to a different uid
# ----------------------------------------------------------------------
if [ "$(id -u)" = "0" ]; then
    OWN_ROOT=$(_make_valid_root)
    chown 65534:65534 "${OWN_ROOT}/update.sh" 2>/dev/null || true
    out=$(_run_validate "$OWN_ROOT" "$OWN_ROOT" "$PROJECT_DIR")
    assert_eq "ownership: wrong-owner update.sh rejected" "1" "$(_exit_code "$out")"
else
    _skip "ownership: wrong-owner test (requires root to chown)"
fi

# ----------------------------------------------------------------------
# Logging — DENY paths write to security.log
# ----------------------------------------------------------------------
LOG_PROJECT=$(mktemp -d "${TMPDIR:-/tmp}/cc-vsrc-logXXXXXX")
_run_validate "$VALID_ROOT" "relative/path" "$LOG_PROJECT" >/dev/null
LOGFILE="${LOG_PROJECT}/.claude/cognitive-core/security.log"
if [ -f "$LOGFILE" ] && grep -q 'DENY.*source-validation' "$LOGFILE" 2>/dev/null; then
    _pass "logging: DENY writes to security.log with source-validation tag"
else
    _fail "logging: DENY should write source-validation entry" "log=$LOGFILE"
fi

# Log entry includes the caller function name
if [ -f "$LOGFILE" ] && grep -q 'caller=' "$LOGFILE" 2>/dev/null; then
    _pass "logging: DENY entries include caller field"
else
    _fail "logging: DENY should include caller= field"
fi

# ----------------------------------------------------------------------
# Multiple DENY variants land in the same log file with distinct reasons
# ----------------------------------------------------------------------
_run_validate "$VALID_ROOT" "relative/path" "$LOG_PROJECT" >/dev/null
_run_validate "$VALID_ROOT" "" "$LOG_PROJECT" >/dev/null
_run_validate "$VALID_ROOT" "${VALID_ROOT}/../etc" "$LOG_PROJECT" >/dev/null

if [ -f "$LOGFILE" ] && grep -q 'not absolute\|empty path\|\.\. segment' "$LOGFILE" 2>/dev/null; then
    _pass "logging: distinct DENY reasons are recorded"
else
    _fail "logging: distinct DENY reasons should be recorded"
fi

# Log line count grows by at least 3 after three DENYs
log_lines_after=$(wc -l < "$LOGFILE" 2>/dev/null | tr -d ' ' || echo 0)
if [ "${log_lines_after:-0}" -ge 3 ]; then
    _pass "logging: multiple DENYs append (>=3 lines)"
else
    _fail "logging: expected >=3 lines, got ${log_lines_after}"
fi

# Control character other than newline (tab) also rejected
TAB_PATH=$(printf '%s\t%s' "$VALID_ROOT" "tabbed")
out=$(_run_validate "$VALID_ROOT" "$TAB_PATH" "$PROJECT_DIR")
assert_eq "path form: control char (tab) rejected" "1" "$(_exit_code "$out")"

# Canonicalization: path with trailing /./ still resolves and is accepted
DOT_PATH="${VALID_ROOT}/./"
out=$(_run_validate "$VALID_ROOT" "$DOT_PATH" "$PROJECT_DIR")
assert_eq "boundary: trailing /./ in path accepted" "0" "$(_exit_code "$out")"

# Canonicalization strips trailing slash
canon_check=$(_validated "$out")
if [ "$canon_check" = "$canon_root" ] || [ "$canon_check" = "${canon_root}" ]; then
    _pass "canonicalization: trailing slash stripped"
else
    _fail "canonicalization: expected ${canon_root}, got ${canon_check}"
fi

# ----------------------------------------------------------------------
# TOCTOU — known limitation, documented, not deterministically testable
# ----------------------------------------------------------------------
_skip "TOCTOU: validation is single-call; attacker replacing path between validate and exec is out of scope (documented)"

# ----------------------------------------------------------------------
# Cleanup fixtures (best-effort; tmp is auto-swept)
# ----------------------------------------------------------------------
rm -rf "$VALID_ROOT" "$PROJECT_DIR" "$SPACE_ROOT" "$OUTSIDE" \
       "$SIBLING_ROOT" "$SIBLING_TWIN" "$NESTED_ROOT" \
       "$SYMLINK_OUTSIDE" "$LINK_DIR" \
       "$CHAIN_TARGET" "$CHAIN_MID" "$CHAIN_HEAD" \
       "$ESCAPE_SRC" "$ESCAPE_TGT" \
       "$NO_UPDATER" "$NOEX_ROOT" "$SUID_ROOT" "$SGID_ROOT" \
       "$DIR_UP" "$LOG_PROJECT" 2>/dev/null || true

suite_end
