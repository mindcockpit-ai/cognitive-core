#!/bin/bash
# Test suite: Validate agent health monitoring (#74)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "17 — Agent Health Monitoring"

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
# Section 7: Live agent simulation (spawn → detect → log → kill)
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
# "claude" + "agent/subagent" + "background" — matching the health check
# grep pattern in ps output. The "exit 0" after sleep prevents bash exec
# optimization, keeping the script name visible in ps.
for _agent_name in \
    "claude-test-agent-explore-background" \
    "claude-test-subagent-research-background" \
    "claude-test-agent-implement-background"; do
    _script="$_sim_dir/${_agent_name}.sh"
    printf '#!/bin/bash\nsleep 300\nexit 0\n' > "$_script"
    chmod +x "$_script"
    "$_script" &
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
# Spawn a fresh agent, check with timeout=9999 — must NOT be detected
_fresh_script="$_sim_dir/claude-test-agent-fresh-background.sh"
printf '#!/bin/bash\nsleep 300\nexit 0\n' > "$_fresh_script"
chmod +x "$_fresh_script"
"$_fresh_script" &
_fresh_pid=$!
sleep 1

_high_result=$(CC_AGENT_TIMEOUT_MINUTES=9999 CC_AGENT_AUTO_KILL=false _cc_check_agent_health "$_sim_dir" 2>/dev/null)
assert_eq "sim: high timeout = no detection" "$_high_result" ""

kill "$_fresh_pid" 2>/dev/null || true
pkill -P "$_fresh_pid" 2>/dev/null || true
sleep 1

# Cleanup
rm -rf "$_sim_dir"

suite_end
