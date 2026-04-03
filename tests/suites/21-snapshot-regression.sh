#!/bin/bash
# Test suite 21: Snapshot regression test for DRY refactoring (#139)
# Installs all 4 platforms into temp dirs, captures file checksums.
# Compares against baseline to detect unintended output changes.
#
# Usage:
#   bash tests/suites/21-snapshot-regression.sh              # Compare against baseline
#   bash tests/suites/21-snapshot-regression.sh --capture     # Capture new baseline
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "21 — Snapshot Regression"

BASELINE_DIR="${ROOT_DIR}/tests/baselines"
CAPTURE_MODE=false
[ "${1:-}" = "--capture" ] && CAPTURE_MODE=true

# ---- Platform configs ----
# Minimal config per platform — enough for a full install

_generate_config() {
    local platform="$1" install_dir="$2"
    cat > "${install_dir}/cognitive-core.conf" << CONFEOF
#!/bin/false
CC_PROJECT_NAME="snapshot-${platform}"
CC_PROJECT_DESCRIPTION="Snapshot test for ${platform}"
CC_ORG="test-org"
CC_PLATFORM="${platform}"
CC_LANGUAGE="python"
CC_LINT_EXTENSIONS=".py"
CC_LINT_COMMAND="ruff check \$1"
CC_FORMAT_COMMAND=""
CC_TEST_COMMAND="pytest"
CC_TEST_PATTERN="tests/**/*.py"
CC_DATABASE="none"
CC_ARCHITECTURE="layered"
CC_SRC_ROOT="src"
CC_TEST_ROOT="tests"
CC_AGENTS="coordinator reviewer"
CC_COORDINATOR_MODEL="opus"
CC_SPECIALIST_MODEL="sonnet"
CC_SKILLS="code-review session-resume"
CC_HOOKS="setup-env validate-bash"
CC_MAIN_BRANCH="main"
CC_COMMIT_FORMAT="conventional"
CC_COMMIT_SCOPES="core"
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
CONFEOF

    # Platform-specific config additions
    case "$platform" in
        aider)
            cat >> "${install_dir}/cognitive-core.conf" << 'AEOF'
CC_AIDER_MODEL="qwen2.5-coder:32b"
CC_AIDER_OLLAMA_BASE="http://localhost:11434"
CC_AIDER_EDIT_FORMAT="diff"
AEOF
            ;;
        intellij)
            cat >> "${install_dir}/cognitive-core.conf" << 'IEOF'
CC_INTELLIJ_PROVIDER="ollama"
CC_INTELLIJ_MODEL="qwen2.5-coder:32b"
CC_INTELLIJ_OLLAMA_URL="http://localhost:11434"
IEOF
            ;;
    esac
}

# ---- Snapshot capture function ----
# Captures: relative file paths + md5 checksums (sorted, deterministic)
_capture_snapshot() {
    local dir="$1" platform="$2"
    # Find all installed files (exclude .git, cognitive-core.conf, version.json timestamps)
    cd "$dir"
    find . -type f \
        -not -path './.git/*' \
        -not -name 'cognitive-core.conf' \
        -not -name '.gitignore' \
    | sort | while read -r f; do
        # Normalize dynamic content before checksumming
        _bn="$(basename "$f")"
        case "$_bn" in
            version.json)
                sed -e 's/"installed_at":[^,]*/"installed_at":"STRIPPED"/' \
                    -e 's/"updated_at":[^,]*/"updated_at":"STRIPPED"/' \
                    -e 's/"source":[^,]*/"source":"STRIPPED"/' \
                    "$f" | md5sum | awk '{print $1}'
                ;;
            mcp-config.json|CLAUDE.md|DEVOXXGENIE.md|.devoxxgenie.yaml)
                # These contain generated paths/content that vary per install dir
                # Normalize: strip absolute paths, sort deterministic sections
                sed -e "s|${dir}|PROJECT_DIR|g" \
                    -e 's|/private/var/[^ ]*|TMPDIR|g' \
                    -e 's|/var/[^ ]*|TMPDIR|g' \
                    -e 's|/tmp/[^ ]*|TMPDIR|g' \
                    "$f" | md5sum | awk '{print $1}'
                ;;
            *)
                md5sum "$f" | awk '{print $1}'
                ;;
        esac
        printf '%s\n' "$f"
    done | paste - - | sort -k2
    cd - >/dev/null
}

# ---- Run install for each platform ----
PLATFORMS="claude aider intellij vscode"
FAIL_COUNT=0

for platform in $PLATFORMS; do
    test_dir=$(create_test_dir)
    git -C "$test_dir" init --quiet 2>/dev/null

    _generate_config "$platform" "$test_dir"

    # Run install
    install_out=$(bash "${ROOT_DIR}/install.sh" "$test_dir" 2>&1) || {
        _fail "snapshot ${platform}: install failed"
        echo "$install_out" | tail -10
        FAIL_COUNT=$((FAIL_COUNT + 1))
        continue
    }
    _pass "snapshot ${platform}: install succeeded"

    # Capture snapshot
    snapshot=$(_capture_snapshot "$test_dir" "$platform")
    snapshot_file="/tmp/cc-snapshot-${platform}.txt"
    echo "$snapshot" > "$snapshot_file"

    file_count=$(echo "$snapshot" | wc -l | tr -d ' ')
    _pass "snapshot ${platform}: captured ${file_count} files"

    if $CAPTURE_MODE; then
        # Save as baseline
        mkdir -p "$BASELINE_DIR"
        cp "$snapshot_file" "${BASELINE_DIR}/${platform}.snapshot"
        _pass "snapshot ${platform}: baseline saved to tests/baselines/${platform}.snapshot"
    else
        # Compare against baseline
        baseline="${BASELINE_DIR}/${platform}.snapshot"
        if [ ! -f "$baseline" ]; then
            _skip "snapshot ${platform}: no baseline — run with --capture first"
            continue
        fi

        # Diff
        diff_output=$(diff "$baseline" "$snapshot_file" 2>&1) || true
        if [ -z "$diff_output" ]; then
            _pass "snapshot ${platform}: output matches baseline (${file_count} files)"
        else
            _fail "snapshot ${platform}: output differs from baseline"
            echo "$diff_output" | head -20
            FAIL_COUNT=$((FAIL_COUNT + 1))

            # Show which files changed
            added=$(echo "$diff_output" | grep '^>' | wc -l | tr -d ' ')
            removed=$(echo "$diff_output" | grep '^<' | wc -l | tr -d ' ')
            echo "  Files added: ${added}, removed: ${removed}"
        fi
    fi

    rm -rf "$test_dir"
done

# ---- Cross-platform consistency checks ----

# Safety rules should be identical across all platform snapshots
if ! $CAPTURE_MODE; then
    _SAFETY_HASHES=""
    for platform in $PLATFORMS; do
        sf="/tmp/cc-snapshot-${platform}.txt"
        [ -f "$sf" ] || continue
        # Find safety-rules related files and their hashes
        hash=$(grep -E 'safety|SAFETY' "$sf" 2>/dev/null | md5sum | awk '{print $1}') || hash="none"
        _SAFETY_HASHES="${_SAFETY_HASHES}${hash} "
    done
    unique_hashes=$(echo "$_SAFETY_HASHES" | tr ' ' '\n' | sort -u | grep -v '^$' | wc -l | tr -d ' ')
    if [ "$unique_hashes" -le 1 ]; then
        _pass "cross-platform: safety rules consistent across platforms"
    else
        _fail "cross-platform: safety rules differ between platforms"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
fi

suite_end
