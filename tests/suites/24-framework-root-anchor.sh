#!/bin/bash
# Test suite: CC_FRAMEWORK_ROOT anchor (#260)
# Covers: install-time capture, conf hardening (0444 + owner), TOFU migration,
# idempotency, differing-value rejection, shadow-PATH owner-mismatch fail,
# sourcing the hardened conf from update.sh path.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "24 — Framework Root Anchor"

EXPECTED_ROOT="$(realpath "$ROOT_DIR" 2>/dev/null || (cd "$ROOT_DIR" && pwd))"

get_mode() {
    local m
    # GNU stat first (Linux); falls through to BSD (macOS)
    if m=$(stat -c '%a' "$1" 2>/dev/null) && [ -n "$m" ]; then
        printf '%s' "$m"
        return
    fi
    m=$(stat -f '%Mp%Lp' "$1" 2>/dev/null)
    printf '%s' "$m" | sed 's/^0*//'
}

get_uid() {
    local u
    if u=$(stat -c '%u' "$1" 2>/dev/null) && [ -n "$u" ]; then
        printf '%s' "$u"
        return
    fi
    stat -f '%u' "$1" 2>/dev/null
}

# Seeds a synthetic pre-upgrade project with a conf that has NO CC_FRAMEWORK_ROOT
# (suite 04 pattern — skips install.sh heredoc path, useful for TOFU tests).
seed_suite04_conf() {
    local d="$1"
    cat > "${d}/cognitive-core.conf" <<'EOF'
#!/bin/false
CC_PROJECT_NAME="test-project"
CC_PROJECT_DESCRIPTION="Test project"
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
CC_SKILLS="session-resume"
CC_HOOKS="setup-env validate-bash"
CC_MAIN_BRANCH="main"
CC_COMMIT_FORMAT="conventional"
CC_COMMIT_SCOPES="api core"
CC_ENABLE_CICD="false"
CC_RUNNER_TYPE="github-hosted"
CC_MONITORING="false"
CC_SECURITY_LEVEL="standard"
CC_BLOCKED_PATTERNS=""
CC_ALLOWED_DOMAINS=""
CC_KNOWN_SAFE_DOMAINS=""
CC_COMPACT_RULES="1. Follow standards"
CC_ENABLE_CLEANUP_CRON="false"
CC_SESSION_DOCS_DIR="docs"
CC_SESSION_MAX_AGE_DAYS="30"
CC_FITNESS_LINT="60"
CC_FITNESS_COMMIT="80"
CC_FITNESS_TEST="85"
CC_FITNESS_MERGE="90"
CC_FITNESS_DEPLOY="95"
CC_RUNNER_NODES="1"
CC_RUNNER_LABELS="self-hosted"
CC_AGENT_TEAMS="false"
CC_MCP_SERVERS=""
EOF
}

# =============================================================================
# Section A — Fresh install (no pre-existing conf) writes CC_FRAMEWORK_ROOT
# =============================================================================

test_dir=$(create_test_dir)
git -C "$test_dir" init --quiet 2>/dev/null

# Trigger interactive path by feeding empty answers (defaults accepted)
set +o pipefail
install_out=$(yes "" | bash "${ROOT_DIR}/install.sh" "$test_dir" 2>&1) && rc=0 || rc=$?
set -o pipefail
if [ "$rc" -eq 0 ]; then
    _pass "fresh install: install.sh exits 0"
else
    _fail "fresh install: install.sh exits 0" "$(echo "$install_out" | tail -15)"
    rm -rf "$test_dir"
    suite_end || true
    exit 1
fi

CONF="${test_dir}/cognitive-core.conf"
assert_file_exists "fresh install: conf exists" "$CONF"

if grep -qE '^CC_FRAMEWORK_ROOT=' "$CONF"; then
    _pass "fresh install: CC_FRAMEWORK_ROOT= line present"
else
    _fail "fresh install: CC_FRAMEWORK_ROOT= line present" "not found in conf"
fi

ACTUAL_ROOT=$(grep -E '^CC_FRAMEWORK_ROOT=' "$CONF" | head -1 | sed 's/^CC_FRAMEWORK_ROOT=//; s/^"//; s/"$//')
assert_eq "fresh install: CC_FRAMEWORK_ROOT value resolves to framework source" "$EXPECTED_ROOT" "$ACTUAL_ROOT"

if grep -qF '# ===== FRAMEWORK ANCHOR =====' "$CONF"; then
    _pass "fresh install: FRAMEWORK ANCHOR section header present"
else
    _fail "fresh install: FRAMEWORK ANCHOR section header present" "header missing"
fi

FILE_MODE=$(get_mode "$CONF")
assert_eq "fresh install: conf mode is 0444" "444" "$FILE_MODE"

EXPECTED_UID=$(id -u)
FILE_UID=$(get_uid "$CONF")
assert_eq "fresh install: conf owner matches current user" "$EXPECTED_UID" "$FILE_UID"

# 0444 conf sources cleanly (emulates update.sh reading the hardened file)
sourced_out=$(bash -c "source '$CONF' && echo \"\${CC_FRAMEWORK_ROOT}|\${CC_PROJECT_NAME}\"" 2>&1)
if [ "${sourced_out%%|*}" = "$EXPECTED_ROOT" ]; then
    _pass "fresh install: 0444 conf sources cleanly (update.sh path)"
else
    _fail "fresh install: 0444 conf sources cleanly (update.sh path)" "got: $sourced_out"
fi

# Rollback safety: an older tool ignorant of CC_FRAMEWORK_ROOT just gets an extra var
# shellcheck disable=SC1090
if ( source "$CONF" && [ -n "${CC_PROJECT_NAME:-}" ] && [ -n "${CC_LANGUAGE:-}" ] ) >/dev/null 2>&1; then
    _pass "fresh install: legacy consumers see normal conf variables (rollback safe)"
else
    _fail "fresh install: legacy consumers see normal conf variables (rollback safe)" "source failed"
fi

rm -rf "$test_dir"

# =============================================================================
# Section B — install --force against fresh conf: stays 0444, line unchanged
# =============================================================================

test_dir=$(create_test_dir)
git -C "$test_dir" init --quiet 2>/dev/null
set +o pipefail
yes "" | bash "${ROOT_DIR}/install.sh" "$test_dir" >/dev/null 2>&1 || true
CONF="${test_dir}/cognitive-core.conf"

# --force from same framework source: must succeed (CC_FRAMEWORK_ROOT matches)
force_out=$(yes "" | bash "${ROOT_DIR}/install.sh" --force "$test_dir" 2>&1) && force_rc=0 || force_rc=$?
set -o pipefail
if [ "$force_rc" -eq 0 ]; then
    _pass "install --force: same framework path exits 0"
else
    _fail "install --force: same framework path exits 0" "$(echo "$force_out" | tail -10)"
fi

FILE_MODE=$(get_mode "$CONF")
assert_eq "install --force: conf mode 0444 preserved" "444" "$FILE_MODE"

COUNT=$(grep -cE '^CC_FRAMEWORK_ROOT=' "$CONF")
assert_eq "install --force: CC_FRAMEWORK_ROOT appears exactly once" "1" "$COUNT"

rm -rf "$test_dir"

# =============================================================================
# Section C — install refuses when pre-existing CC_FRAMEWORK_ROOT differs
# =============================================================================

test_dir=$(create_test_dir)
git -C "$test_dir" init --quiet 2>/dev/null
seed_suite04_conf "$test_dir"
# Inject a differing CC_FRAMEWORK_ROOT to simulate a wrong anchor
printf '\nCC_FRAMEWORK_ROOT="/nonexistent/wrong/path"\n' >> "${test_dir}/cognitive-core.conf"

mismatch_out=$(bash "${ROOT_DIR}/install.sh" --force "$test_dir" 2>&1) && mm_rc=0 || mm_rc=$?
if [ "$mm_rc" -ne 0 ]; then
    _pass "mismatch: install fails when CC_FRAMEWORK_ROOT differs"
else
    _fail "mismatch: install fails when CC_FRAMEWORK_ROOT differs" "install succeeded unexpectedly"
fi
assert_contains "mismatch: error message mentions refusal" "$mismatch_out" "Refusing to overwrite"

rm -rf "$test_dir"

# =============================================================================
# Section D — TOFU migration (synthetic pre-#260 install)
# =============================================================================

test_dir=$(create_test_dir)
git -C "$test_dir" init --quiet 2>/dev/null

# Pre-#260 conf: no CC_FRAMEWORK_ROOT line
cat > "${test_dir}/cognitive-core.conf" <<'EOF'
#!/bin/false
CC_PROJECT_NAME="tofu-project"
CC_LANGUAGE="python"
CC_ENV_VARS=""
EOF

# Pre-#260 version.json pointing at real framework source
mkdir -p "${test_dir}/.claude/cognitive-core"
cat > "${test_dir}/.claude/cognitive-core/version.json" <<JSON
{
  "version": "1.4.0",
  "source": "${ROOT_DIR}",
  "platform": "claude"
}
JSON

# Drop the framework's current _lib.sh + setup-env.sh into the project
mkdir -p "${test_dir}/.claude/hooks"
cp "${ROOT_DIR}/core/hooks/_lib.sh" "${test_dir}/.claude/hooks/_lib.sh"
cp "${ROOT_DIR}/core/hooks/setup-env.sh" "${test_dir}/.claude/hooks/setup-env.sh"
chmod +x "${test_dir}/.claude/hooks/setup-env.sh"

CLAUDE_PROJECT_DIR="$test_dir" bash "${test_dir}/.claude/hooks/setup-env.sh" >/dev/null 2>&1 || true

TOFU_CONF="${test_dir}/cognitive-core.conf"

if grep -qE '^CC_FRAMEWORK_ROOT=' "$TOFU_CONF"; then
    _pass "TOFU: CC_FRAMEWORK_ROOT appended after first setup-env run"
else
    _fail "TOFU: CC_FRAMEWORK_ROOT appended after first setup-env run" "line missing"
fi

TOFU_VAL=$(grep -E '^CC_FRAMEWORK_ROOT=' "$TOFU_CONF" | head -1 | sed 's/^CC_FRAMEWORK_ROOT=//; s/^"//; s/"$//')
assert_eq "TOFU: CC_FRAMEWORK_ROOT matches version.json.source (resolved)" "$EXPECTED_ROOT" "$TOFU_VAL"

FILE_MODE=$(get_mode "$TOFU_CONF")
assert_eq "TOFU: conf mode 0444 after migration" "444" "$FILE_MODE"

TOFU_LOG="${test_dir}/.claude/cognitive-core/security.log"
if [ -f "$TOFU_LOG" ] && grep -q "tofu-migration" "$TOFU_LOG"; then
    _pass "TOFU: security.log records tofu-migration"
else
    _fail "TOFU: security.log records tofu-migration" "log missing or entry absent"
fi

if grep -qF '# ===== FRAMEWORK ANCHOR (TOFU-migrated) =====' "$TOFU_CONF"; then
    _pass "TOFU: FRAMEWORK ANCHOR (TOFU-migrated) header present"
else
    _fail "TOFU: FRAMEWORK ANCHOR (TOFU-migrated) header present" "header missing"
fi

if [ ! -d "${test_dir}/.claude/cognitive-core/anchor.lock.d" ]; then
    _pass "TOFU: anchor.lock.d cleaned up after migration"
else
    _fail "TOFU: anchor.lock.d cleaned up after migration" "lock dir still present"
fi

# Idempotency
md5_first=$(_portable_md5 "$TOFU_CONF" 2>/dev/null | awk '{print $1}')
CLAUDE_PROJECT_DIR="$test_dir" bash "${test_dir}/.claude/hooks/setup-env.sh" >/dev/null 2>&1 || true
md5_second=$(_portable_md5 "$TOFU_CONF" 2>/dev/null | awk '{print $1}')
assert_eq "TOFU idempotency: md5 unchanged on second run" "$md5_first" "$md5_second"

COUNT=$(grep -cE '^CC_FRAMEWORK_ROOT=' "$TOFU_CONF")
assert_eq "TOFU idempotency: CC_FRAMEWORK_ROOT appears exactly once" "1" "$COUNT"

rm -rf "$test_dir"

# =============================================================================
# Section E — TOFU no-op when CC_FRAMEWORK_ROOT already present
# =============================================================================

test_dir=$(create_test_dir)
git -C "$test_dir" init --quiet 2>/dev/null
cat > "${test_dir}/cognitive-core.conf" <<EOF
#!/bin/false
CC_PROJECT_NAME="preset-project"
CC_FRAMEWORK_ROOT="/preset/anchor/path"
CC_ENV_VARS=""
EOF
chmod 0444 "${test_dir}/cognitive-core.conf"
mkdir -p "${test_dir}/.claude/cognitive-core"
cat > "${test_dir}/.claude/cognitive-core/version.json" <<JSON
{
  "version": "1.5.0",
  "source": "${ROOT_DIR}"
}
JSON
mkdir -p "${test_dir}/.claude/hooks"
cp "${ROOT_DIR}/core/hooks/_lib.sh" "${test_dir}/.claude/hooks/_lib.sh"
cp "${ROOT_DIR}/core/hooks/setup-env.sh" "${test_dir}/.claude/hooks/setup-env.sh"
chmod +x "${test_dir}/.claude/hooks/setup-env.sh"

md5_noop_before=$(_portable_md5 "${test_dir}/cognitive-core.conf" 2>/dev/null | awk '{print $1}')
CLAUDE_PROJECT_DIR="$test_dir" bash "${test_dir}/.claude/hooks/setup-env.sh" >/dev/null 2>&1 || true
md5_noop_after=$(_portable_md5 "${test_dir}/cognitive-core.conf" 2>/dev/null | awk '{print $1}')
assert_eq "TOFU no-op: md5 unchanged when CC_FRAMEWORK_ROOT preset" "$md5_noop_before" "$md5_noop_after"

PRESET_VAL=$(grep -E '^CC_FRAMEWORK_ROOT=' "${test_dir}/cognitive-core.conf" | head -1 | sed 's/^CC_FRAMEWORK_ROOT=//; s/^"//; s/"$//')
assert_eq "TOFU no-op: existing value not overwritten" "/preset/anchor/path" "$PRESET_VAL"

rm -rf "$test_dir"

# =============================================================================
# Section F — Owner mismatch fails install (shadow-PATH stat mock)
# =============================================================================

STAT_PATH=$(command -v stat 2>/dev/null || true)
if [ -z "$STAT_PATH" ]; then
    _skip "owner-mismatch shadow-PATH (stat not available)"
else
    SHADOW_DIR=$(create_test_dir)
    for src_dir in /usr/bin /bin; do
        [ -d "$src_dir" ] || continue
        for src_bin in "$src_dir"/*; do
            [ -x "$src_bin" ] || continue
            name=$(basename "$src_bin")
            [ "$name" = "stat" ] && continue
            [ -e "${SHADOW_DIR}/${name}" ] && continue
            ln -s "$src_bin" "${SHADOW_DIR}/${name}" 2>/dev/null || true
        done
    done
    # Fake stat always reports uid 99999
    cat > "${SHADOW_DIR}/stat" <<'STATEOF'
#!/bin/bash
echo 99999
STATEOF
    chmod +x "${SHADOW_DIR}/stat"

    SANITY=$(PATH="$SHADOW_DIR" stat -f %u /tmp 2>/dev/null || true)
    if [ "$SANITY" = "99999" ]; then
        shadow_test_dir=$(create_test_dir)
        git -C "$shadow_test_dir" init --quiet 2>/dev/null
        set +o pipefail
        owner_out=$(yes "" | PATH="${SHADOW_DIR}:$PATH" bash "${ROOT_DIR}/install.sh" "$shadow_test_dir" 2>&1) && own_rc=0 || own_rc=$?
        set -o pipefail
        if [ "$own_rc" -ne 0 ]; then
            _pass "owner-mismatch: install fails when file_uid != id -u"
        else
            _fail "owner-mismatch: install fails when file_uid != id -u" "install succeeded unexpectedly"
        fi
        assert_contains "owner-mismatch: error mentions owner mismatch" "$owner_out" "owner mismatch"

        skip_test_dir=$(create_test_dir)
        git -C "$skip_test_dir" init --quiet 2>/dev/null
        set +o pipefail
        skip_out=$(yes "" | PATH="${SHADOW_DIR}:$PATH" CC_CONF_OWNER_SKIP=1 \
            bash "${ROOT_DIR}/install.sh" "$skip_test_dir" 2>&1) && skip_rc=0 || skip_rc=$?
        set -o pipefail
        if [ "$skip_rc" -eq 0 ]; then
            _pass "owner-mismatch: CC_CONF_OWNER_SKIP=1 downgrades failure to WARN"
        else
            _fail "owner-mismatch: CC_CONF_OWNER_SKIP=1 downgrades failure to WARN" \
                "install still failed: $(echo "$skip_out" | tail -10)"
        fi
        skip_log="${skip_test_dir}/.claude/cognitive-core/security.log"
        if [ -f "$skip_log" ] && grep -q "owner-check-skipped" "$skip_log"; then
            _pass "owner-mismatch: security.log records owner-check-skipped"
        else
            _fail "owner-mismatch: security.log records owner-check-skipped" "log missing or entry absent"
        fi

        rm -rf "$shadow_test_dir" "$skip_test_dir"
    else
        _skip "owner-mismatch shadow-PATH (could not shadow stat — sanity=${SANITY})"
    fi
    rm -rf "$SHADOW_DIR"
fi

suite_end
