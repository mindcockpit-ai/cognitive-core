#!/bin/bash
# Test suite 25 — Anchored State References (#265)
#
# Regression + structural invariant for the manifest-regeneration bug where
# `find ... -not -path "*/cognitive-core/*"` excluded every file whenever the
# project path contained the substring `cognitive-core`. Fixed by anchoring
# the exclusion to ${CLAUDE_DIR}/cognitive-core/* (update.sh) and
# ${CC_INSTALL_DIR}/cognitive-core/* (install.sh).
#
# Section 1: Lint scan — fails if any path-filter flag is followed by the
#            unanchored glob `*/cognitive-core/*`. Converts the one-off fix
#            into a structural invariant.
# Section 2: Self-host runtime fixture — installs into a tempdir whose name
#            literally contains `cognitive-core` (the substring that triggers
#            the original bug) and asserts the regenerated manifest is
#            non-empty and contains known-present hook entries.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SUITE_SELF_NAME="$(basename "${BASH_SOURCE[0]}")"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "25 — Anchored State References"

# =============================================================================
# Section 1: Lint scan — no unanchored `*/cognitive-core/*` in path-filter flags
# =============================================================================
# Pattern: one of the path-filter flags (-path, -not -path, -iname, --include,
# --exclude) followed by an optional opening quote and then the unanchored glob.
# Excludes this suite's own file so the regex literal in the comment above does
# not self-flag the scan.

LINT_REGEX='(-path|-not[[:space:]]+-path|-iname|--include|--exclude)[[:space:]]+["'\'']?\*/cognitive-core/\*'

# Enumerate tracked files via git ls-files (run from ROOT_DIR for correct paths).
# Exclude the suite file itself so the regex literal above does not trigger.
mapfile -t LINT_HITS < <(
    cd "$ROOT_DIR" && git ls-files -z 2>/dev/null \
        | xargs -0 grep -HnE "$LINT_REGEX" 2>/dev/null \
        | grep -vE "^tests/suites/${SUITE_SELF_NAME}(:|$)" \
        || true
)

if [ "${#LINT_HITS[@]}" -eq 0 ]; then
    _pass "lint: no unanchored '*/cognitive-core/*' path-filter matches found"
else
    _fail "lint: unanchored '*/cognitive-core/*' path-filter matches found" \
          "$(printf '%s\n' "${LINT_HITS[@]}")"
fi

# =============================================================================
# Section 2: Self-host fixture — install + update into a cognitive-core-named
# project and assert the manifest is populated.
# =============================================================================
# The tempdir name MUST contain `cognitive-core` — that substring is exactly
# what triggered the original unanchored-glob bug (see issue #265).

if ! command -v python3 >/dev/null 2>&1; then
    _skip "self-host fixture: python3 not available"
    suite_end
    exit $?
fi

# mktemp -d -t on macOS yields /var/folders/.../cognitive-core-test.XXXX.SUFFIX
# On Linux it yields /tmp/cognitive-core-test.XXXX.SUFFIX. Both paths contain
# the trigger substring.
FIXTURE_DIR=$(mktemp -d -t cognitive-core-test.XXXX) || FIXTURE_DIR=""
if [ -z "$FIXTURE_DIR" ] || [ ! -d "$FIXTURE_DIR" ]; then
    _skip "self-host fixture: mktemp failed to create cognitive-core-named dir"
    suite_end
    exit $?
fi

cleanup() {
    [ -n "${FIXTURE_DIR:-}" ] && [ -d "${FIXTURE_DIR}" ] && rm -rf "${FIXTURE_DIR}"
}
trap cleanup EXIT

# Confirm the substring is present — if the platform's mktemp stripped the
# template prefix the fixture is not meaningful.
case "$FIXTURE_DIR" in
    *cognitive-core*) _pass "self-host fixture: tempdir contains 'cognitive-core' trigger substring" ;;
    *)
        _fail "self-host fixture: tempdir missing 'cognitive-core' substring" \
              "got: ${FIXTURE_DIR}"
        suite_end
        exit $?
        ;;
esac

# Initialize a minimal git repo (install.sh requires this).
git -C "$FIXTURE_DIR" init --quiet 2>/dev/null

# Seed a conf so install.sh takes the non-interactive branch (same pattern as
# suite 04). Keep CC_HOOKS set to a subset we assert on later.
cat > "${FIXTURE_DIR}/cognitive-core.conf" <<'EOF'
#!/bin/false
CC_PROJECT_NAME="cognitive-core-test"
CC_PROJECT_DESCRIPTION="Self-host fixture for #265"
CC_ORG="test-org"
CC_LANGUAGE="python"
CC_LINT_EXTENSIONS=".py"
CC_LINT_COMMAND="ruff check $1"
CC_FORMAT_COMMAND=""
CC_TEST_COMMAND="pytest"
CC_TEST_PATTERN="tests/**/*.py"
CC_DATABASE="none"
CC_ARCHITECTURE="ddd"
CC_SRC_ROOT="src"
CC_TEST_ROOT="tests"
CC_AGENTS="coordinator reviewer researcher"
CC_COORDINATOR_MODEL="opus"
CC_SPECIALIST_MODEL="sonnet"
CC_SKILLS="session-resume code-review security-baseline"
CC_HOOKS="setup-env compact-reminder validate-bash validate-read validate-fetch validate-write post-edit-lint"
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

# Run install.sh
install_out=$(bash "${ROOT_DIR}/install.sh" "$FIXTURE_DIR" 2>&1) || {
    _fail "self-host fixture: install.sh failed" "$(printf '%s\n' "$install_out" | tail -20)"
    suite_end
    exit $?
}
_pass "self-host fixture: install.sh completed"

# Assertion: install-produced manifest is non-empty and contains expected hooks.
INSTALL_MANIFEST="${FIXTURE_DIR}/.claude/cognitive-core/version.json"
if [ ! -f "$INSTALL_MANIFEST" ]; then
    _fail "self-host fixture: install manifest missing" "expected at ${INSTALL_MANIFEST}"
    suite_end
    exit $?
fi
_pass "self-host fixture: install manifest exists"

install_count=$(python3 -c "
import json, sys
try:
    with open('${INSTALL_MANIFEST}') as f:
        data = json.load(f)
    print(len(data.get('files', [])))
except Exception as exc:
    print('ERR:%s' % exc)
    sys.exit(1)
" 2>&1)

case "$install_count" in
    ERR:*|'')
        _fail "self-host fixture: install manifest JSON unreadable" "$install_count"
        ;;
    0)
        _fail "self-host fixture: install manifest is empty (#265 regression)" \
              "files[] length is 0; expected > 0 in cognitive-core-named tempdir"
        ;;
    *)
        if [ "$install_count" -gt 0 ] 2>/dev/null; then
            _pass "self-host fixture: install manifest non-empty (${install_count} entries)"
        else
            _fail "self-host fixture: install manifest count not numeric" "got: ${install_count}"
        fi
        ;;
esac

# Assert specific hook paths are present (fail-soft deterministic markers).
install_paths_check=$(python3 -c "
import json
with open('${INSTALL_MANIFEST}') as f:
    data = json.load(f)
paths = {e.get('path', '') for e in data.get('files', [])}
need = ['.claude/hooks/setup-env.sh', '.claude/hooks/validate-bash.sh']
missing = [p for p in need if p not in paths]
print('OK' if not missing else 'MISSING:' + ','.join(missing))
" 2>&1)

if [ "$install_paths_check" = "OK" ]; then
    _pass "self-host fixture: install manifest contains setup-env.sh + validate-bash.sh"
else
    _fail "self-host fixture: install manifest missing expected hooks" "$install_paths_check"
fi

# ---- Now run update.sh over the fixture ----
# Disable branch-guard auto-switching: the fixture has no origin remote, so the
# guard is already skipped, but set it explicitly for safety across envs.
CC_SYNC_ENFORCE=false update_out=$(CC_SYNC_ENFORCE=false bash "${ROOT_DIR}/update.sh" "$FIXTURE_DIR" 2>&1) || {
    _fail "self-host fixture: update.sh failed" "$(printf '%s\n' "$update_out" | tail -20)"
    suite_end
    exit $?
}
_pass "self-host fixture: update.sh completed"

update_count=$(python3 -c "
import json
with open('${INSTALL_MANIFEST}') as f:
    data = json.load(f)
print(len(data.get('files', [])))
" 2>&1)

case "$update_count" in
    0)
        _fail "self-host fixture: update manifest is empty (#265 regression)" \
              "update.sh regenerated an empty manifest in cognitive-core-named project"
        ;;
    *)
        if [ "$update_count" -gt 0 ] 2>/dev/null; then
            _pass "self-host fixture: update manifest non-empty (${update_count} entries)"
        else
            _fail "self-host fixture: update manifest count not numeric" "got: ${update_count}"
        fi
        ;;
esac

update_paths_check=$(python3 -c "
import json
with open('${INSTALL_MANIFEST}') as f:
    data = json.load(f)
paths = {e.get('path', '') for e in data.get('files', [])}
need = ['.claude/hooks/setup-env.sh', '.claude/hooks/validate-bash.sh']
missing = [p for p in need if p not in paths]
print('OK' if not missing else 'MISSING:' + ','.join(missing))
" 2>&1)

if [ "$update_paths_check" = "OK" ]; then
    _pass "self-host fixture: update manifest contains setup-env.sh + validate-bash.sh"
else
    _fail "self-host fixture: update manifest missing expected hooks" "$update_paths_check"
fi

suite_end
