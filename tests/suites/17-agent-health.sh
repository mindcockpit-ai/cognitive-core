#!/bin/bash
# Test suite: Validate agent health monitoring (#74)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "17 - Agent Health Monitoring"

# Fake long-running agent/tool for the detection tests. No exec, so the
# script name stays visible in ps. It kills its own sleep on TERM/INT: a
# plain `sleep 300` child would be adopted by PID 1 once the script dies
# and keep running (and holding the runner's stdout) for 5 minutes.
# Each script records its sleep PID here, so the final check can prove none
# of them outlived the suite.
_SIM_SLEEP_PIDS="$(mktemp "${TMPDIR:-/tmp}/cc-sim-sleep-pids.XXXXXX")"
_SIM_SCRIPTS=0  # each written script is started exactly once

_write_sim_script() {
    # _write_sim_script <path> [extra comment line]
    {
        echo '#!/bin/bash'
        [ -z "${2:-}" ] || echo "$2"
        echo 'trap '\''kill "$c" 2>/dev/null; exit 0'\'' TERM INT'
        echo 'sleep 300 & c=$!'
        printf 'echo "$c" >> %q\n' "$_SIM_SLEEP_PIDS"
        echo 'wait "$c"'
        echo 'exit 0'
    } > "$1"
    chmod +x "$1"
    _SIM_SCRIPTS=$((_SIM_SCRIPTS + 1))
}

# Safety net: stop any fake process left behind, even if the suite aborts
_sim_cleanup() {
    local pid
    pkill -TERM -f "cc-(agent|orphan|outside)-sim-test-$$" 2>/dev/null || true
    while read -r pid; do
        kill "$pid" 2>/dev/null || true
    done < "$_SIM_SLEEP_PIDS" 2>/dev/null
}
trap '_sim_cleanup; rm -f "$_SIM_SLEEP_PIDS"' EXIT

HYGIENE_SH="${ROOT_DIR}/core/hooks/_session-hygiene.sh"
CONF="${ROOT_DIR}/cognitive-core.conf"
CONF_EXAMPLE="${ROOT_DIR}/cognitive-core.conf.example"
AGENTS_README="${ROOT_DIR}/.claude/AGENTS_README.md"

# Read file contents for assert_contains (expects string, not path)
_conf_content=$(cat "$CONF")
_example_content=$(cat "$CONF_EXAMPLE")
_hygiene_content=$(cat "$HYGIENE_SH")
_readme_content=$(cat "$AGENTS_README")

# ============================================================
# Section 1: Configuration variables
# ============================================================

assert_file_exists "session hygiene script exists" "$HYGIENE_SH"
assert_file_exists "cognitive-core.conf exists" "$CONF"
assert_file_exists "cognitive-core.conf.example exists" "$CONF_EXAMPLE"
assert_file_exists "AGENTS_README.md exists" "$AGENTS_README"

# Check config variables exist in conf
assert_contains "conf: CC_AGENT_TIMEOUT_MINUTES" "$_conf_content" "CC_AGENT_TIMEOUT_MINUTES"
assert_contains "conf: CC_AGENT_AUTO_KILL" "$_conf_content" "CC_AGENT_AUTO_KILL"
assert_contains "conf: CC_AGENT_TIMEOUT_EXPLORE" "$_conf_content" "CC_AGENT_TIMEOUT_EXPLORE"
assert_contains "conf: CC_AGENT_TIMEOUT_RESEARCH" "$_conf_content" "CC_AGENT_TIMEOUT_RESEARCH"
assert_contains "conf: CC_AGENT_TIMEOUT_PLAN" "$_conf_content" "CC_AGENT_TIMEOUT_PLAN"
assert_contains "conf: CC_AGENT_TIMEOUT_IMPLEMENT" "$_conf_content" "CC_AGENT_TIMEOUT_IMPLEMENT"

# Check config variables exist in example
assert_contains "example: CC_AGENT_TIMEOUT_MINUTES" "$_example_content" "CC_AGENT_TIMEOUT_MINUTES"
assert_contains "example: CC_AGENT_AUTO_KILL" "$_example_content" "CC_AGENT_AUTO_KILL"
assert_contains "example: CC_AGENT_TIMEOUT_EXPLORE" "$_example_content" "CC_AGENT_TIMEOUT_EXPLORE"
assert_contains "example: CC_AGENT_TIMEOUT_RESEARCH" "$_example_content" "CC_AGENT_TIMEOUT_RESEARCH"
assert_contains "example: CC_AGENT_TIMEOUT_PLAN" "$_example_content" "CC_AGENT_TIMEOUT_PLAN"
assert_contains "example: CC_AGENT_TIMEOUT_IMPLEMENT" "$_example_content" "CC_AGENT_TIMEOUT_IMPLEMENT"

# Check defaults are sensible
_timeout_val=$(grep 'CC_AGENT_TIMEOUT_MINUTES=' "$CONF" | head -1 | cut -d'"' -f2)
assert_eq "default timeout is 30" "$_timeout_val" "30"

_auto_kill_val=$(grep 'CC_AGENT_AUTO_KILL=' "$CONF" | head -1 | cut -d'"' -f2)
assert_eq "auto-kill defaults to false" "$_auto_kill_val" "false"

_explore_val=$(grep 'CC_AGENT_TIMEOUT_EXPLORE=' "$CONF" | head -1 | cut -d'"' -f2)
assert_eq "explore timeout is 5" "$_explore_val" "5"

_research_val=$(grep 'CC_AGENT_TIMEOUT_RESEARCH=' "$CONF" | head -1 | cut -d'"' -f2)
assert_eq "research timeout is 15" "$_research_val" "15"

_plan_val=$(grep 'CC_AGENT_TIMEOUT_PLAN=' "$CONF" | head -1 | cut -d'"' -f2)
assert_eq "plan timeout is 10" "$_plan_val" "10"

_implement_val=$(grep 'CC_AGENT_TIMEOUT_IMPLEMENT=' "$CONF" | head -1 | cut -d'"' -f2)
assert_eq "implement timeout is 30" "$_implement_val" "30"

# ============================================================
# Section 2: Session hygiene script structure
# ============================================================

assert_contains "hygiene: defines _cc_session_hygiene" "$_hygiene_content" "_cc_session_hygiene()"
assert_contains "hygiene: defines _cc_check_agent_health" "$_hygiene_content" "_cc_check_agent_health()"
assert_contains "hygiene: uses CC_AGENT_TIMEOUT_MINUTES" "$_hygiene_content" "CC_AGENT_TIMEOUT_MINUTES"
assert_contains "hygiene: uses CC_AGENT_AUTO_KILL" "$_hygiene_content" "CC_AGENT_AUTO_KILL"
assert_contains "hygiene: calls _cc_check_agent_health" "$_hygiene_content" '_cc_check_agent_health'
assert_contains "hygiene: logs to agent-health.log" "$_hygiene_content" "agent-health.log"
assert_contains "hygiene: recommends TaskStop" "$_hygiene_content" "TaskStop"

# Verify syntax
_syntax_ok=true
bash -n "$HYGIENE_SH" 2>/dev/null || _syntax_ok=false
assert_eq "hygiene: bash -n passes" "$_syntax_ok" "true"

# ============================================================
# Section 3: _cc_check_agent_health function behavior
# ============================================================

# Source the hygiene script to test the function directly
# shellcheck disable=SC1090
source "$HYGIENE_SH"

# Test with no stuck agents (no matching processes)
_result=$(CC_AGENT_TIMEOUT_MINUTES=30 CC_AGENT_AUTO_KILL=false _cc_check_agent_health "/tmp/cc-test-$$")
assert_eq "no agents: returns empty" "$_result" ""

# Test log directory detection
_test_dir="/tmp/cc-agent-health-test-$$"
mkdir -p "$_test_dir/.claude/cognitive-core"
assert_dir_exists "health check: accepts project dir" "$_test_dir/.claude/cognitive-core"

# Test auto_kill message variation
_result_no_kill=$(CC_AGENT_AUTO_KILL=false _cc_check_agent_health "$_test_dir" 2>/dev/null)
assert_eq "auto_kill=false: no output without agents" "$_result_no_kill" ""

# Cleanup
rm -rf "$_test_dir"

# ============================================================
# Section 4: Documentation completeness
# ============================================================

assert_contains "readme: timeout section exists" "$_readme_content" "Timeout & Health Monitoring"
assert_contains "readme: timeout table header" "$_readme_content" "Agent Type"
assert_contains "readme: explore timeout documented" "$_readme_content" "CC_AGENT_TIMEOUT_EXPLORE"
assert_contains "readme: research timeout documented" "$_readme_content" "CC_AGENT_TIMEOUT_RESEARCH"
assert_contains "readme: plan timeout documented" "$_readme_content" "CC_AGENT_TIMEOUT_PLAN"
assert_contains "readme: implement timeout documented" "$_readme_content" "CC_AGENT_TIMEOUT_IMPLEMENT"
assert_contains "readme: TaskStop documented" "$_readme_content" "TaskStop"
assert_contains "readme: agent-health.log documented" "$_readme_content" "agent-health.log"
assert_contains "readme: stuck patterns section" "$_readme_content" "Known Stuck Patterns"
assert_contains "readme: killing section" "$_readme_content" "Killing Stuck Background Agents"

# ============================================================
# Section 5: Health log format
# ============================================================

assert_contains "log format: ISO timestamp" "$_hygiene_content" "date -u"
assert_contains "log format: STUCK keyword" "$_hygiene_content" "STUCK"
assert_contains "log format: pid field" "$_hygiene_content" "pid="
assert_contains "log format: elapsed field" "$_hygiene_content" "elapsed="
assert_contains "log format: threshold field" "$_hygiene_content" "threshold="
assert_contains "log format: auto_kill field" "$_hygiene_content" "auto_kill="

# ============================================================
# Section 6: Integration with session hygiene
# ============================================================

# Verify _cc_session_hygiene calls _cc_check_agent_health
_hygiene_body=$(sed -n '/_cc_session_hygiene()/,/^}/p' "$HYGIENE_SH")
_calls_health=false
if echo "$_hygiene_body" | grep -q '_cc_check_agent_health'; then
    _calls_health=true
fi
assert_eq "hygiene calls agent health check" "$_calls_health" "true"

# Verify the agent section label exists
assert_contains "hygiene: agent section comment" "$_hygiene_content" "Background agent health check"

# Verify set -euo pipefail is NOT in the file (it's a sourced library, not standalone)
_has_set_e=false
if grep -q 'set -euo pipefail' "$HYGIENE_SH"; then
    _has_set_e=true
fi
assert_eq "hygiene: no set -euo (sourced lib)" "$_has_set_e" "false"

# ============================================================
# Section 7: Live agent simulation (spawn -> detect -> log -> kill)
# ============================================================
# Spawns 3 fake "stuck" agents as background processes whose command
# lines match the grep pattern: claude.*(agent|subagent|background).
# Uses CC_AGENT_TIMEOUT_MINUTES=0 so they are detected immediately
# (etime 00:00 >= 0 = stuck). Proves the full pipeline end-to-end.

_sim_dir="/tmp/cc-agent-sim-test-$$"
mkdir -p "$_sim_dir/.claude/cognitive-core"
_sim_log="$_sim_dir/.claude/cognitive-core/agent-health.log"
_sim_pids=""

# Spawn 3 fake stuck agents using temp scripts whose filenames contain
# "claude" + "agent/subagent" + "background" - matching the health check
# grep pattern in ps output. The "exit 0" after sleep prevents bash exec
# optimization, keeping the script name visible in ps.
for _agent_name in \
    "claude-test-agent-explore-background" \
    "claude-test-subagent-research-background" \
    "claude-test-agent-implement-background"; do
    _script="$_sim_dir/${_agent_name}.sh"
    _write_sim_script "$_script"
    "$_script" >/dev/null 2>&1 &
    _sim_pids="$_sim_pids $!"
done

# Give processes a moment to register in the process table
sleep 1

# Verify all 3 are running
_running=0
for _p in $_sim_pids; do
    if kill -0 "$_p" 2>/dev/null; then
        _running=$((_running + 1))
    fi
done
assert_eq "sim: 3 fake agents running" "3" "$_running"

# ---- Detection test: timeout=0, auto_kill=false ----
_detect_result=$(CC_AGENT_TIMEOUT_MINUTES=0 CC_AGENT_AUTO_KILL=false _cc_check_agent_health "$_sim_dir" 2>/dev/null)

# Count how many of our 3 test PIDs appear in the output
_detected_test_pids=0
for _p in $_sim_pids; do
    if echo "$_detect_result" | grep -q "PID ${_p}"; then
        _detected_test_pids=$((_detected_test_pids + 1))
    fi
done
assert_eq "sim: all 3 test agents detected" "3" "$_detected_test_pids"

# Verify output mentions "background agent(s)"
assert_contains "sim: output mentions background agent" "$_detect_result" "background agent"
assert_contains "sim: output mentions timeout" "$_detect_result" "timeout"

# Verify NO TaskStop recommendation (auto_kill=false)
_has_taskstop=false
if echo "$_detect_result" | grep -q "TaskStop"; then
    _has_taskstop=true
fi
assert_eq "sim: no TaskStop when auto_kill=false" "$_has_taskstop" "false"

# ---- Auto-kill test: timeout=0, auto_kill=true ----
_kill_result=$(CC_AGENT_TIMEOUT_MINUTES=0 CC_AGENT_AUTO_KILL=true _cc_check_agent_health "$_sim_dir" 2>/dev/null)
_has_taskstop_now=false
if echo "$_kill_result" | grep -q "TaskStop"; then
    _has_taskstop_now=true
fi
assert_eq "sim: TaskStop recommended when auto_kill=true" "$_has_taskstop_now" "true"

# ---- Health log verification ----
_log_exists=false
if [ -f "$_sim_log" ]; then
    _log_exists=true
fi
assert_eq "sim: agent-health.log created" "$_log_exists" "true"

# Count STUCK entries for our specific test PIDs
_log_test_entries=0
if [ -f "$_sim_log" ]; then
    for _p in $_sim_pids; do
        if grep -q "pid=${_p}" "$_sim_log" 2>/dev/null; then
            _log_test_entries=$((_log_test_entries + 1))
        fi
    done
fi
assert_eq "sim: log has STUCK entry for each test agent" "3" "$_log_test_entries"

# Verify log format has all required fields
if [ -f "$_sim_log" ]; then
    _sample_line=$(head -1 "$_sim_log")
    assert_contains "sim: log has pid=" "$_sample_line" "pid="
    assert_contains "sim: log has elapsed=" "$_sample_line" "elapsed="
    assert_contains "sim: log has threshold=" "$_sample_line" "threshold="
    assert_contains "sim: log has auto_kill=" "$_sample_line" "auto_kill="
else
    _fail "sim: log has pid=" "log file missing"
    _fail "sim: log has elapsed=" "log file missing"
    _fail "sim: log has threshold=" "log file missing"
    _fail "sim: log has auto_kill=" "log file missing"
fi

# ---- Kill fake agents and verify clean state ----
for _p in $_sim_pids; do
    kill "$_p" 2>/dev/null || true
    pkill -P "$_p" 2>/dev/null || true
done
sleep 2

_post_alive=0
for _p in $_sim_pids; do
    if kill -0 "$_p" 2>/dev/null; then
        _post_alive=$((_post_alive + 1))
    fi
done
assert_eq "sim: all test agents killed" "0" "$_post_alive"

# ---- High timeout test: agents should NOT be detected ----
# Spawn a fresh agent, check with timeout=9999 - must NOT be detected
_fresh_script="$_sim_dir/claude-test-agent-fresh-background.sh"
_write_sim_script "$_fresh_script"
"$_fresh_script" >/dev/null 2>&1 &
_fresh_pid=$!
sleep 1

_high_result=$(CC_AGENT_TIMEOUT_MINUTES=9999 CC_AGENT_AUTO_KILL=false _cc_check_agent_health "$_sim_dir" 2>/dev/null)
assert_eq "sim: high timeout = no detection" "$_high_result" ""

kill "$_fresh_pid" 2>/dev/null || true
pkill -P "$_fresh_pid" 2>/dev/null || true
sleep 1

# Cleanup
rm -rf "$_sim_dir"

# ============================================================
# Section 8: Orphaned subprocess detection (spawn -> detect -> kill)
# ============================================================
# Simulates orphaned tool processes (PPID=1, no TTY) by spawning
# subshell-exit processes whose commands match the tool pattern list
# AND contain ".claude" in their command line. Uses _ORPHAN_MIN_MINUTES
# override via function patching (threshold=0) for immediate detection.

_orphan_dir="/tmp/cc-orphan-sim-test-$$"
_CC_TEST_PS_FILTER="$_orphan_dir"
mkdir -p "$_orphan_dir/.claude/cognitive-core"
_orphan_log="$_orphan_dir/.claude/cognitive-core/agent-health.log"
_orphan_pids=""

# Configuration tests
_conf_content_updated=$(cat "$CONF")
_example_content_updated=$(cat "$CONF_EXAMPLE")
assert_contains "conf: CC_ORPHAN_AUTO_KILL" "$_conf_content_updated" "CC_ORPHAN_AUTO_KILL"
assert_contains "example: CC_ORPHAN_AUTO_KILL" "$_example_content_updated" "CC_ORPHAN_AUTO_KILL"

_orphan_auto_val=$(grep 'CC_ORPHAN_AUTO_KILL=' "$CONF" | head -1 | cut -d'"' -f2)
assert_eq "orphan auto-kill defaults to false" "$_orphan_auto_val" "false"

# Structure tests
assert_contains "hygiene: defines _cc_check_orphaned_subprocesses" "$_hygiene_content" "_cc_check_orphaned_subprocesses()"
assert_contains "hygiene: calls _cc_check_orphaned_subprocesses" "$_hygiene_content" '_cc_check_orphaned_subprocesses'
assert_contains "hygiene: orphan section comment" "$_hygiene_content" "Orphaned tool subprocesses"
assert_contains "hygiene: uses CC_ORPHAN_AUTO_KILL" "$_hygiene_content" "CC_ORPHAN_AUTO_KILL"
assert_contains "hygiene: uses ORPHAN keyword" "$_hygiene_content" "ORPHAN"
assert_contains "hygiene: tool pattern list" "$_hygiene_content" "cp|git|curl|ssh|node|python|plackup|npm|cargo"
assert_contains "hygiene: uses grep -qF for path" "$_hygiene_content" "grep -qF"
assert_contains "hygiene: uses SIGTERM not SIGKILL" "$_hygiene_content" "kill -TERM"
assert_contains "hygiene: re-verifies PID before kill" "$_hygiene_content" "ps -p"

# Verify _cc_session_hygiene calls _cc_check_orphaned_subprocesses
_hygiene_body_orphan=$(sed -n '/_cc_session_hygiene()/,/^}/p' "$HYGIENE_SH")
_calls_orphan=false
if echo "$_hygiene_body_orphan" | grep -q '_cc_check_orphaned_subprocesses'; then
    _calls_orphan=true
fi
assert_eq "hygiene calls orphan check" "$_calls_orphan" "true"

# Log format tests
assert_contains "orphan log: ORPHAN keyword" "$_hygiene_content" "ORPHAN pid="
assert_contains "orphan log: elapsed field" "$_hygiene_content" 'elapsed=${_total_minutes}min'
assert_contains "orphan log: command field" "$_hygiene_content" 'command='
assert_contains "orphan log: auto_kill field" "$_hygiene_content" 'auto_kill=${auto_kill}'
assert_contains "orphan log: killed field" "$_hygiene_content" 'killed=${_killed}'

# ---- Live simulation: spawn orphan-like processes ----
# Create scripts named after tool patterns with ".claude" in path to match filters.
# Use subshell-exit pattern: ( nohup CMD </dev/null >/dev/null 2>&1 & )
# Child reparents to PID 1 and loses TTY - simulates real orphan.
#
# IMPORTANT: We patch _ORPHAN_MIN_MINUTES to 0 inside the function by
# wrapping it. This avoids needing to wait 10+ minutes in tests.

_cc_check_orphaned_subprocesses_test() {
    # Test-only copy of the detector: min age 0 (no 10 minute wait), and it
    # only sees this run's fake processes. Unscoped, the auto-kill test would
    # SIGTERM every orphaned tool process with .claude in its command line on
    # the machine: a parallel run's fakes, or a real orphaned node/git.
    local _orig_fn _test_fn
    local _scoped_ps='| tail -n +2 | grep -F -- "$_CC_TEST_PS_FILTER" || true)'
    _orig_fn=$(declare -f _cc_check_orphaned_subprocesses)
    _test_fn=${_orig_fn/_ORPHAN_MIN_MINUTES=10/_ORPHAN_MIN_MINUTES=0}
    _test_fn=${_test_fn/"| tail -n +2)"/$_scoped_ps}
    if [[ "$_test_fn" != *_CC_TEST_PS_FILTER* ]]; then
        # Never run an unscoped auto-kill against the whole machine
        echo "orphan test: could not scope the detector to the test dir" >&2
        return 1
    fi
    eval "$_test_fn"
    _cc_check_orphaned_subprocesses "$@"
    # Restore original
    eval "${_orig_fn}"
}

for _orphan_name in \
    "git" \
    "node" \
    "curl"; do
    _orphan_script="$_orphan_dir/${_orphan_name}-orphan-sim-${$}.sh"
    # The script name contains ".claude" via the directory path reference in args
    # We pass .claude as an argument so it appears in the command line
    _write_sim_script "$_orphan_script"
    # Spawn as orphan: subshell exits, child reparents to PID 1
    ( nohup "$_orphan_script" "$_orphan_dir/.claude/test" </dev/null >/dev/null 2>&1 & echo $! > "$_orphan_dir/${_orphan_name}.pid" )
done

sleep 1

# Collect PIDs of the orphaned processes
_orphan_pids=""
_orphan_running=0
for _orphan_name in git node curl; do
    _opid=$(cat "$_orphan_dir/${_orphan_name}.pid" 2>/dev/null || echo "")
    if [ -n "$_opid" ] && kill -0 "$_opid" 2>/dev/null; then
        _orphan_pids="$_orphan_pids $_opid"
        _orphan_running=$((_orphan_running + 1))
    fi
done
assert_eq "orphan sim: 3 orphan processes running" "3" "$_orphan_running"

# ---- Detection test: auto_kill=false (warn only) ----
# The spawned processes have script names like "git-orphan-sim-XXXX.sh" which
# won't match the tool basename pattern directly (the basename filter checks
# for exact match: ^(cp|git|curl|...)$). We need the actual binary to be named
# as the tool. Instead, let's use a symlink approach where we create symlinks
# named "git", "node", "curl" that point to a sleep script.

# Cleanup first attempt
for _p in $_orphan_pids; do
    kill "$_p" 2>/dev/null || true
done
sleep 1
_orphan_pids=""

# Strategy: create executable scripts named exactly as tools, containing
# ".claude" in the command line via arguments or cwd
for _orphan_name in git node curl; do
    # Create a script that is named exactly like the tool
    _tool_script="$_orphan_dir/${_orphan_name}"
    _write_sim_script "$_tool_script" "# .claude marker for orphan detection"
    # Spawn as orphan with .claude in argument
    ( nohup "$_tool_script" --work-dir "$_orphan_dir/.claude/cognitive-core" </dev/null >/dev/null 2>&1 & echo $! > "$_orphan_dir/${_orphan_name}.pid" )
done

sleep 1

# Collect PIDs
_orphan_pids=""
_orphan_running=0
for _orphan_name in git node curl; do
    _opid=$(cat "$_orphan_dir/${_orphan_name}.pid" 2>/dev/null || echo "")
    if [ -n "$_opid" ] && kill -0 "$_opid" 2>/dev/null; then
        _orphan_pids="$_orphan_pids $_opid"
        _orphan_running=$((_orphan_running + 1))
    fi
done
assert_eq "orphan sim: 3 tool-named orphan processes running" "3" "$_orphan_running"

# Verify they are actually reparented (PPID=1) and have no TTY
_reparented=0
for _p in $_orphan_pids; do
    _ppid_check=$(ps -p "$_p" -o ppid= 2>/dev/null | tr -d ' ')
    _tty_check=$(ps -p "$_p" -o tty= 2>/dev/null | tr -d ' ')
    if [ "$_ppid_check" = "1" ] && { [ "$_tty_check" = "??" ] || [ "$_tty_check" = "?" ] || [ "$_tty_check" = "-" ]; }; then
        _reparented=$((_reparented + 1))
    fi
done
# Note: reparenting to PID 1 may not happen on all systems (some use a subreaper).
# If not reparented, skip the live detection tests.
if [ "$_reparented" -lt 3 ]; then
    skip "orphan sim: detection (processes did not reparent to PID 1 on this system)"
    skip "orphan sim: auto_kill=false warn only"
    skip "orphan sim: auto_kill=true SIGTERM"
    skip "orphan sim: ORPHAN log entries"
    skip "orphan sim: high min-elapsed = no detection"
else
    # ---- Detection test: auto_kill=false ----
    _orphan_result=$(CC_ORPHAN_AUTO_KILL=false _cc_check_orphaned_subprocesses_test "$_orphan_dir" 2>/dev/null)

    _detected_orphans=0
    for _p in $_orphan_pids; do
        if echo "$_orphan_result" | grep -q "PID ${_p}"; then
            _detected_orphans=$((_detected_orphans + 1))
        fi
    done
    assert_eq "orphan sim: all 3 orphans detected" "3" "$_detected_orphans"

    assert_contains "orphan sim: output mentions orphaned" "$_orphan_result" "orphaned tool process"

    # Verify NO SIGTERM message when auto_kill=false
    _has_sigterm_msg=false
    if echo "$_orphan_result" | grep -q "SIGTERM sent"; then
        _has_sigterm_msg=true
    fi
    assert_eq "orphan sim: no SIGTERM when auto_kill=false" "$_has_sigterm_msg" "false"

    # ---- Health log verification ----
    _orphan_log_exists=false
    if [ -f "$_orphan_log" ]; then
        _orphan_log_exists=true
    fi
    assert_eq "orphan sim: agent-health.log has ORPHAN entries" "$_orphan_log_exists" "true"

    _orphan_log_entries=0
    if [ -f "$_orphan_log" ]; then
        for _p in $_orphan_pids; do
            if grep -q "ORPHAN pid=${_p}" "$_orphan_log" 2>/dev/null; then
                _orphan_log_entries=$((_orphan_log_entries + 1))
            fi
        done
    fi
    assert_eq "orphan sim: log has ORPHAN entry for each process" "3" "$_orphan_log_entries"

    # Verify log format fields
    if [ -f "$_orphan_log" ]; then
        _orphan_sample=$(grep "ORPHAN" "$_orphan_log" | head -1)
        assert_contains "orphan log: has pid=" "$_orphan_sample" "pid="
        assert_contains "orphan log: has elapsed=" "$_orphan_sample" "elapsed="
        assert_contains "orphan log: has command=" "$_orphan_sample" "command="
        assert_contains "orphan log: has auto_kill=" "$_orphan_sample" "auto_kill="
        assert_contains "orphan log: has killed=" "$_orphan_sample" "killed="
    fi

    # ---- High min-elapsed test: should NOT detect ----
    # Use the real function (10 min threshold) - freshly spawned processes < 10 min old
    _high_orphan_result=$(CC_ORPHAN_AUTO_KILL=false _cc_check_orphaned_subprocesses "$_orphan_dir" 2>/dev/null)
    assert_eq "orphan sim: high min-elapsed = no detection" "$_high_orphan_result" ""

    # ---- Auto-kill test: auto_kill=true ----
    # An orphan outside the test dir that matches every other criterion
    # (tool name, PPID 1, no TTY, .claude in its command line) must survive.
    _outside_dir="/tmp/cc-outside-sim-test-$$"
    mkdir -p "$_outside_dir/.claude/cognitive-core"
    _write_sim_script "$_outside_dir/git" "# .claude marker for orphan detection"
    ( nohup "$_outside_dir/git" --work-dir "$_outside_dir/.claude/cognitive-core" </dev/null >/dev/null 2>&1 & echo $! > "$_outside_dir/git.pid" )
    sleep 1
    _outside_pid=$(cat "$_outside_dir/git.pid" 2>/dev/null || echo "")

    # Clear log to isolate kill entries
    rm -f "$_orphan_log"

    _kill_orphan_result=$(CC_ORPHAN_AUTO_KILL=true _cc_check_orphaned_subprocesses_test "$_orphan_dir" 2>/dev/null)

    # Verify SIGTERM message present
    _has_sigterm_kill=false
    if echo "$_kill_orphan_result" | grep -q "SIGTERM sent"; then
        _has_sigterm_kill=true
    fi
    assert_eq "orphan sim: SIGTERM sent when auto_kill=true" "$_has_sigterm_kill" "true"

    # Verify log entries show killed=true
    if [ -f "$_orphan_log" ]; then
        _killed_entries=0
        _killed_entries=$(grep -c "killed=true" "$_orphan_log" 2>/dev/null || echo "0")
        # At least some should have killed=true (race condition: some may have died already)
        _has_killed=false
        if [ "$_killed_entries" -gt 0 ] 2>/dev/null; then
            _has_killed=true
        fi
        assert_eq "orphan sim: log shows killed=true entries" "$_has_killed" "true"
    fi

    # Wait for processes to die after SIGTERM
    sleep 2

    # Verify processes are dead
    _post_orphan_alive=0
    for _p in $_orphan_pids; do
        if kill -0 "$_p" 2>/dev/null; then
            _post_orphan_alive=$((_post_orphan_alive + 1))
        fi
    done
    assert_eq "orphan sim: all orphans killed after SIGTERM" "0" "$_post_orphan_alive"

    if [ -n "$_outside_pid" ] && kill -0 "$_outside_pid" 2>/dev/null; then
        _pass "orphan sim: orphan outside the test dir survives auto-kill"
    else
        _fail "orphan sim: orphan outside the test dir survives auto-kill"
    fi
    kill "$_outside_pid" 2>/dev/null || true
    rm -rf "$_outside_dir"
fi

# Cleanup: kill any remaining orphan test processes
for _p in $_orphan_pids; do
    kill "$_p" 2>/dev/null || true
    kill -9 "$_p" 2>/dev/null || true
done
rm -rf "$_orphan_dir"

# ============================================================
# No fake process may outlive the suite
# ============================================================
# Not via _sim_cleanup: the suite's own cleanup must already have ended them
sleep 1
# pgrep exits 1 when nothing matches, which pipefail would turn into an abort
_leftover=$({ pgrep -f "cc-(agent|orphan)-sim-test-$$" 2>/dev/null || true; } | wc -l | tr -d ' ')
assert_eq "cleanup: no fake agent or tool script left" "0" "$_leftover"
_live_sleeps=0
_recorded_sleeps=0
while read -r _pid; do
    _recorded_sleeps=$((_recorded_sleeps + 1))
    if kill -0 "$_pid" 2>/dev/null; then _live_sleeps=$((_live_sleeps + 1)); fi
done < "$_SIM_SLEEP_PIDS"
assert_eq "cleanup: sleep PID of every fake process recorded" "$_SIM_SCRIPTS" "$_recorded_sleeps"
assert_eq "cleanup: no fake sleep outlived its script" "0" "$_live_sleeps"

suite_end
