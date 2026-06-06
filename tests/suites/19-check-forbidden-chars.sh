#!/bin/bash
# Test suite: check-forbidden-chars.sh hook
#
# Verifies the AI-tell character pre-commit hook in two enforcement modes:
#   - ASCII-only for source code (rejects any byte > 0x7F)
#   - Blocklist for docs (rejects 11 specific Unicode AI-tells)
#
# Each test creates an isolated temp git repo, stages a fixture file,
# invokes the hook with the right GIT_DIR/GIT_WORK_TREE, captures exit
# code, and asserts on it. No state leaks between tests.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "19 - check-forbidden-chars hook"

HOOK="${ROOT_DIR}/core/git-hooks/check-forbidden-chars.sh"

# ---- Hook exists and is executable ----
assert_file_exists "hook script exists" "$HOOK"
assert_file_executable "hook script is executable" "$HOOK"

# ---- Helper: run the hook in an isolated staged-file fixture ----
# $1 - test name
# $2 - filename (e.g. "test.md", "script.pl")
# $3 - content (printf-format; use \xHH for byte literals)
# $4 - expected exit (0 or 1)
run_hook_fixture() {
    local name="$1" filename="$2" content="$3" expected_exit="$4"

    local tmp
    tmp=$(mktemp -d)

    git -C "$tmp" init -q
    printf "%b" "$content" > "$tmp/$filename"
    git -C "$tmp" add "$filename" 2>/dev/null

    local actual_exit=0
    pushd "$tmp" >/dev/null
    bash "$HOOK" >/dev/null 2>&1 || actual_exit=$?
    popd >/dev/null

    if [ "$actual_exit" = "$expected_exit" ]; then
        _pass "$name (exit=$actual_exit)"
    else
        _fail "$name (got exit=$actual_exit, expected=$expected_exit)"
    fi

    rm -rf "$tmp"
}

# ---- Helper: run hook and capture output for assertion ----
# Echoes the hook output to stdout so caller can grep/inspect.
run_hook_capture() {
    local filename="$1" content="$2"
    local tmp
    tmp=$(mktemp -d)
    git -C "$tmp" init -q >/dev/null
    printf "%b" "$content" > "$tmp/$filename"
    git -C "$tmp" add "$filename" 2>/dev/null
    pushd "$tmp" >/dev/null
    bash "$HOOK" 2>&1 || true
    popd >/dev/null
    rm -rf "$tmp"
}

# ============================================================
# ASCII-only mode tests (source code files)
# ============================================================

# Pure ASCII Perl file - should pass
run_hook_fixture "ASCII: clean .pl passes" \
    "clean.pl" \
    "#!/usr/bin/env perl\nprint \"hello\\\\n\";\n" \
    0

# Perl file with German umlaut (U+00E4) - should fail (ASCII mode)
run_hook_fixture "ASCII: .pl with U+00E4 fails" \
    "umlaut.pl" \
    "#!/usr/bin/env perl\n# Bemerkung: \xc3\xa4nderung\nprint \"x\";\n" \
    1

# Shell script with em-dash - should fail (ASCII mode)
run_hook_fixture "ASCII: .sh with em-dash fails" \
    "test.sh" \
    "#!/bin/bash\n# em-dash: \xe2\x80\x94\necho ok\n" \
    1

# JS file with smart-quote - should fail (ASCII mode)
run_hook_fixture "ASCII: .js with smart-quote fails" \
    "test.js" \
    "// Smart quote \xe2\x80\x9chi\xe2\x80\x9d\nconsole.log(1);\n" \
    1

# YAML config - should pass (clean ASCII)
run_hook_fixture "ASCII: clean .yml passes" \
    "config.yml" \
    "key: value\nlist:\n  - one\n  - two\n" \
    0

# SQL file with non-ASCII (e.g., a Unicode collation comment) - should fail
run_hook_fixture "ASCII: .sql with non-ASCII fails" \
    "schema.sql" \
    "-- Caf\xc3\xa9 schema\nCREATE TABLE x (id INT);\n" \
    1

# ============================================================
# BLOCKLIST mode tests (doc files)
# ============================================================

# Markdown with em-dash - should fail (in blocklist)
run_hook_fixture "BLOCK: .md with em-dash fails" \
    "doc.md" \
    "# Title\n\nSubtitle \xe2\x80\x94 with em-dash.\n" \
    1

# Markdown with en-dash - should fail (in blocklist)
run_hook_fixture "BLOCK: .md with en-dash fails" \
    "doc.md" \
    "Range: 1\xe2\x80\x935 inclusive.\n" \
    1

# Markdown with horizontal ellipsis - should fail (in blocklist)
run_hook_fixture "BLOCK: .md with ellipsis fails" \
    "doc.md" \
    "And so on\xe2\x80\xa6\n" \
    1

# Markdown with smart double quotes - should fail
run_hook_fixture "BLOCK: .md with smart double quotes fails" \
    "doc.md" \
    "He said \xe2\x80\x9chello\xe2\x80\x9d to her.\n" \
    1

# Markdown with smart single quote (typographic apostrophe) - should fail
run_hook_fixture "BLOCK: .md with typographic apostrophe fails" \
    "doc.md" \
    "It\xe2\x80\x99s a problem.\n" \
    1

# Markdown with rightwards arrow - should fail
run_hook_fixture "BLOCK: .md with right arrow fails" \
    "doc.md" \
    "Step 1 \xe2\x86\x92 Step 2.\n" \
    1

# Markdown with non-breaking space - should fail
run_hook_fixture "BLOCK: .md with NBSP fails" \
    "doc.md" \
    "word1\xc2\xa0word2\n" \
    1

# Markdown with zero-width space - should fail
run_hook_fixture "BLOCK: .md with zero-width space fails" \
    "doc.md" \
    "vis\xe2\x80\x8bible word\n" \
    1

# Markdown with German content - should pass (German chars are NOT in blocklist)
run_hook_fixture "BLOCK: .md with German content (Ü, ä) passes" \
    "doc.md" \
    "Title: \xc3\x84NDERUNG (Erledigt)\n" \
    0

# Markdown with math notation (set membership) - should pass
run_hook_fixture "BLOCK: .md with math notation passes" \
    "doc.md" \
    "x \xe2\x88\x88 S means x is in S.\n" \
    0

# Plain text file with em-dash - should fail
run_hook_fixture "BLOCK: .txt with em-dash fails" \
    "notes.txt" \
    "Important \xe2\x80\x94 note this.\n" \
    1

# Plain text file ASCII-clean - should pass
run_hook_fixture "BLOCK: clean .txt passes" \
    "notes.txt" \
    "Plain ASCII content.\n" \
    0

# ============================================================
# Mode dispatch tests
# ============================================================

# Unknown extension - should be skipped (no error)
run_hook_fixture "DISPATCH: .xyz extension is skipped" \
    "data.xyz" \
    "anything \xe2\x80\x94 here\n" \
    0

# ============================================================
# Output format tests
# ============================================================

# Verify output contains the right error markers
output=$(run_hook_capture "doc.md" "Header \xe2\x80\x94 dash\n")
assert_contains "BLOCK output names U+2014 EM DASH" "$output" "U+2014 EM DASH"
assert_contains "BLOCK output names mode tag" "$output" "[mode: BLOCK]"

output=$(run_hook_capture "code.pl" "use strict;\n# \xc3\xa4\n")
assert_contains "ASCII output names mode tag" "$output" "[mode: ASCII]"
assert_contains "ASCII output reports codepoint" "$output" "non-ASCII:"

# Verify auto-fix command is included on violation
output=$(run_hook_capture "doc.md" "x \xe2\x80\x94 y\n")
assert_contains "Output includes auto-fix command" "$output" "perl -i -CSD -pe"

# Verify bypass instruction on violation
output=$(run_hook_capture "doc.md" "x \xe2\x80\x94 y\n")
assert_contains "Output includes bypass instruction" "$output" "git commit --no-verify"

# ============================================================
# Multiple violations in one file
# ============================================================

# Doc with em-dash AND ellipsis - should fail and report both
run_hook_fixture "BLOCK: .md with em-dash + ellipsis fails" \
    "doc.md" \
    "First \xe2\x80\x94 second \xe2\x80\xa6 third.\n" \
    1

output=$(run_hook_capture "doc.md" "First \xe2\x80\x94 second \xe2\x80\xa6 third.\n")
assert_contains "BLOCK reports em-dash" "$output" "U+2014 EM DASH"
assert_contains "BLOCK reports ellipsis" "$output" "U+2026 HORIZONTAL ELLIPSIS"

# ============================================================
# Self-exemption: hook script itself
# ============================================================

# The hook documents codepoints in comments. It must not flag itself.
# Simulate by staging the hook content under a different name (we can't
# stage the actual hook outside its repo, so we replicate its self-exempt
# behaviour: any file whose absolute path matches the script's own path).
# This test is partial -- full behaviour is exercised in integration with
# the real repo. We assert the script contains the self-exempt logic.
assert_contains "hook contains self-exempt logic" \
    "$(cat "$HOOK")" \
    'abs_file" = "$SCRIPT_FILE'

# ============================================================
# Config overrides (CODE_EXT, DOC_EXT, ALLOW_DEFAULT, custom rule, !removal)
# ============================================================

# ---- Helper: run hook with a config file at .husky/forbidden-chars.conf ----
# $1 - test name
# $2 - filename to stage
# $3 - file content (printf %b format)
# $4 - config content
# $5 - expected exit
# $6 - bash binary to use (defaults to "bash"; pass /bin/bash to force 3.2 on macOS)
run_hook_with_config() {
    local name="$1" filename="$2" content="$3" config="$4" expected_exit="$5"
    local bash_bin="${6:-bash}"

    local tmp
    tmp=$(mktemp -d)

    git -C "$tmp" init -q
    mkdir -p "$tmp/.husky"
    printf "%b" "$config" > "$tmp/.husky/forbidden-chars.conf"
    # Stage the file under test (mkdir -p in case the filename contains dirs)
    mkdir -p "$tmp/$(dirname "$filename")"
    printf "%b" "$content" > "$tmp/$filename"
    git -C "$tmp" add -A 2>/dev/null

    local actual_exit=0
    pushd "$tmp" >/dev/null
    "$bash_bin" "$HOOK" >/dev/null 2>&1 || actual_exit=$?
    popd >/dev/null

    if [ "$actual_exit" = "$expected_exit" ]; then
        _pass "$name (exit=$actual_exit)"
    else
        _fail "$name (got exit=$actual_exit, expected=$expected_exit)"
    fi

    rm -rf "$tmp"
}

# CONFIG: CODE_EXT narrows scope -- staged .sh is no longer ASCII-checked
run_hook_with_config "CONFIG: CODE_EXT=pm narrows scope, .sh w/ non-ASCII passes" \
    "test.sh" \
    "#!/bin/bash\n# em-dash: \xe2\x80\x94\necho ok\n" \
    "CODE_EXT = pm\n" \
    0

# CONFIG: DOC_EXT narrows scope -- staged .md is no longer blocklist-checked
run_hook_with_config "CONFIG: DOC_EXT=txt narrows scope, .md w/ em-dash passes" \
    "doc.md" \
    "Header \xe2\x80\x94 dash\n" \
    "DOC_EXT = txt\n" \
    0

# CONFIG: ALLOW_DEFAULT=0 empties the blocklist
run_hook_with_config "CONFIG: ALLOW_DEFAULT=0 empties blocklist, .md w/ em-dash passes" \
    "doc.md" \
    "Header \xe2\x80\x94 dash\n" \
    "ALLOW_DEFAULT = 0\n" \
    0

# CONFIG: custom rule adds a new codepoint to the blocklist (U+2248 ALMOST EQUAL TO)
run_hook_with_config "CONFIG: custom rule 2248 flags U+2248 in .md" \
    "doc.md" \
    "x \xe2\x89\x88 y\n" \
    "2248 ALMOST EQUAL TO -> ~=\n" \
    1

# CONFIG: ! removal drops a default rule (U+2018 LEFT SINGLE QUOTATION MARK)
run_hook_with_config "CONFIG: !2018 removes default, .md with U+2018 passes" \
    "doc.md" \
    "It\xe2\x80\x98s fine\n" \
    "!2018\n" \
    0

# ============================================================
# Empty staged set -- regression guard for line 146
# ============================================================

# When no files match CODE_EXT or DOC_EXT, hook exits 0 silently.
empty_tmp=$(mktemp -d)
git -C "$empty_tmp" init -q
echo "irrelevant" > "$empty_tmp/data.bin"  # extension not in defaults
git -C "$empty_tmp" add data.bin 2>/dev/null
empty_exit=0
pushd "$empty_tmp" >/dev/null
empty_output=$(bash "$HOOK" 2>&1) || empty_exit=$?
popd >/dev/null
if [ "$empty_exit" = "0" ] && [ -z "$empty_output" ]; then
    _pass "EMPTY: no matching staged files -> exit 0 silently"
else
    _fail "EMPTY: expected exit 0 + empty output, got exit=$empty_exit, output=[$empty_output]"
fi
rm -rf "$empty_tmp"

# ============================================================
# Filenames with spaces (#295 S2 regression)
# ============================================================

# Positive: file with space in name + em-dash -> still detected
run_hook_fixture "SPACES: 'My Notes.md' with em-dash fails" \
    "My Notes.md" \
    "Header \xe2\x80\x94 dash\n" \
    1

# Negative: file with space in name + clean ASCII -> passes
run_hook_fixture "SPACES: 'My Notes.md' clean ASCII passes" \
    "My Notes.md" \
    "Plain ASCII content.\n" \
    0

# Positive: subdirectory with space in path -- exercises both the spaces fix
# and the per-file recursion. Uses run_hook_with_config (creates dirs) with
# an empty config to avoid extending run_hook_fixture.
run_hook_with_config "SPACES: 'sub dir/page.md' with em-dash fails" \
    "sub dir/page.md" \
    "Header \xe2\x80\x94 dash\n" \
    "" \
    1

# ============================================================
# Bash 3.2 + set -u empty-array safety (#295 S3 regression)
# ============================================================

# Force /bin/bash (macOS = 3.2.57). With ALLOW_DEFAULT=0 the EFFECTIVE
# array is empty; any unsafe `"${EFFECTIVE[@]}"` would error under set -u.
# Guard: run on /bin/bash and require exit 0 on a clean .md.
if [ -x /bin/bash ]; then
    run_hook_with_config "BASH-3.2: ALLOW_DEFAULT=0 + clean .md does not error under /bin/bash" \
        "clean.md" \
        "Plain ASCII content.\n" \
        "ALLOW_DEFAULT = 0\n" \
        0 \
        /bin/bash
else
    _skip "BASH-3.2: /bin/bash not present, skipping bash-3.2 regression"
fi

# Bash-3.2 + config rule whose name contains spaces -- regression guard for
# the `${arr[@]+"${arr[@]}"}` quoting fix. Rule name "EM DASH" must survive
# the EFFECTIVE assignment loop intact, so em-dash is still flagged.
if [ -x /bin/bash ]; then
    run_hook_with_config "BASH-3.2: rule 'EM DASH' (spaces in name) preserved under /bin/bash" \
        "doc.md" \
        "Header \xe2\x80\x94 dash\n" \
        "ALLOW_DEFAULT = 0\n2014 EM DASH -> -\n" \
        1 \
        /bin/bash
else
    _skip "BASH-3.2: /bin/bash not present, skipping spaces-in-rule-name regression"
fi

suite_end
