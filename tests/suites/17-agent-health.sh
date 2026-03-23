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

suite_end
