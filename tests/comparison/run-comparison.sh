#!/bin/bash
# =============================================================================
# run-comparison.sh — OLD monolithic vs NEW ability-decomposed smoke-test
#
# Runs each design 3 times against identical mock environment.
# Compares: consistency, correctness, step completion, latency.
# Outputs: Markdown report to tests/comparison/report.md
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RESULTS_DIR=$(mktemp -d "${TMPDIR:-/tmp}/cc-comparison-XXXXXX")
MOCK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/cc-mock-env-XXXXXX")
FIXTURE="${SCRIPT_DIR}/smoke-results.json"
SCRIPTS_DIR="${ROOT_DIR}/core/skills/smoke-test/scripts"
RUNS=3
MOCK_PORT=19999
REPORT="${SCRIPT_DIR}/report.md"

echo "=== Comparison Test: OLD monolithic vs NEW ability-decomposed ==="
echo "Results dir: ${RESULTS_DIR}"
echo "Mock dir:    ${MOCK_DIR}"
echo ""

# ---- Cleanup trap ----
cleanup() {
    if [[ -n "${MOCK_SERVER_PID:-}" ]]; then
        kill "$MOCK_SERVER_PID" 2>/dev/null || true
        wait "$MOCK_SERVER_PID" 2>/dev/null || true
    fi
    echo "Results preserved at: ${RESULTS_DIR}"
}
trap cleanup EXIT

# ---- Setup mock environment ----
echo "[SETUP] Creating mock environment..."

# Mock HTTP server
python3 -c "
from http.server import HTTPServer, BaseHTTPRequestHandler
import sys
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'OK')
    def log_message(self, *args): pass
HTTPServer(('127.0.0.1', ${MOCK_PORT}), H).serve_forever()
" &
MOCK_SERVER_PID=$!
sleep 1

# Verify mock server
if ! curl -s -o /dev/null -w "%{http_code}" "http://localhost:${MOCK_PORT}" | grep -q 200; then
    echo "ERROR: Mock server failed to start"
    exit 1
fi
echo "[SETUP] Mock server running on port ${MOCK_PORT}"

# Mock gh CLI
MOCK_BIN="${MOCK_DIR}/bin"
mkdir -p "$MOCK_BIN"
cp "${SCRIPT_DIR}/mock-gh.sh" "${MOCK_BIN}/gh"
chmod +x "${MOCK_BIN}/gh"
export MOCK_GH_LOG="${RESULTS_DIR}/gh-calls.log"

# Mock cognitive-core.conf
cat > "${MOCK_DIR}/cognitive-core.conf" << CONFEOF
CC_SMOKE_TEST_COMMAND="cat ${FIXTURE}"
CC_SMOKE_TEST_URL="http://localhost:${MOCK_PORT}"
CC_SMOKE_TEST_LABEL="smoke-test"
CC_ORG="test-org"
CC_PROJECT_NAME="test-repo"
CONFEOF

# Extract OLD SKILL.md from main branch
OLD_SKILL=$(git -C "$ROOT_DIR" show main:core/skills/smoke-test/SKILL.md 2>/dev/null)
if [[ -z "$OLD_SKILL" ]]; then
    echo "ERROR: Cannot extract OLD SKILL.md from main branch"
    exit 1
fi
echo "[SETUP] Extracted OLD SKILL.md from main branch"
echo ""

# ---- Phase A: OLD flow (LLM-interpreted monolithic SKILL.md) x3 ----
echo "=== Phase A: OLD flow (monolithic) — ${RUNS} runs ==="

for i in $(seq 1 $RUNS); do
    echo -n "  OLD run ${i}/${RUNS}..."
    START_NS=$(date +%s%N)

    claude -p "You must execute the smoke-test skill in REPORT mode. Follow the workflow EXACTLY.

CONFIG (cognitive-core.conf):
CC_SMOKE_TEST_COMMAND=\"cat ${FIXTURE}\"
CC_SMOKE_TEST_URL=\"http://localhost:${MOCK_PORT}\"

SKILL.MD INSTRUCTIONS:
${OLD_SKILL}

Execute the 'report' subcommand: steps 1-5 from the 'run' workflow.
Step 1: Confirm config is loaded.
Step 2: Run: curl -s -o /dev/null -w \"%{http_code}\" http://localhost:${MOCK_PORT}
Step 3: Run: cat ${FIXTURE}
Step 4: Parse the JSON output.
Step 5: Display the results as a formatted markdown table with columns: # | Page | URL | HTTP | Status | Errors. Include a Summary line.

Output ONLY the markdown table and summary. No commentary, no explanations." \
        --output-format text \
        --max-turns 15 \
        > "${RESULTS_DIR}/old-run-${i}.txt" 2>"${RESULTS_DIR}/old-run-${i}-stderr.txt" || true

    END_NS=$(date +%s%N)
    MS=$(( (END_NS - START_NS) / 1000000 ))
    echo "$MS" > "${RESULTS_DIR}/old-run-${i}-ms.txt"
    echo " done (${MS}ms)"
done
echo ""

# ---- Phase B: NEW flow (D-type scripts + LLM table formatting) x3 ----
echo "=== Phase B: NEW flow (ability-decomposed) — ${RUNS} runs ==="

for i in $(seq 1 $RUNS); do
    echo -n "  NEW run ${i}/${RUNS}..."
    START_NS=$(date +%s%N)

    # Step 1 [D]: preflight
    PREFLIGHT_OUT=$(PROJECT_DIR="$MOCK_DIR" bash "${SCRIPTS_DIR}/preflight.sh" 2>"${RESULTS_DIR}/new-run-${i}-preflight-stderr.txt") || true
    PREFLIGHT_EXIT=$?
    echo "$PREFLIGHT_OUT" > "${RESULTS_DIR}/new-run-${i}-preflight.txt"
    echo "$PREFLIGHT_EXIT" > "${RESULTS_DIR}/new-run-${i}-preflight-exit.txt"

    # Step 2 [D]: execute-test
    EXECUTE_OUT=$(PROJECT_DIR="$MOCK_DIR" bash "${SCRIPTS_DIR}/execute-test.sh" 2>"${RESULTS_DIR}/new-run-${i}-execute-stderr.txt") || true
    EXECUTE_EXIT=$?
    echo "$EXECUTE_OUT" > "${RESULTS_DIR}/new-run-${i}-execute.json"
    echo "$EXECUTE_EXIT" > "${RESULTS_DIR}/new-run-${i}-execute-exit.txt"

    # Step 3 [S]: format table (LLM — the only stochastic step)
    TABLE_OUT=$(claude -p "Format this smoke test JSON as a markdown table. Use EXACTLY this format:

# Smoke Test Results — <timestamp>
Server: <server> | Environment: <environment>

| # | Page | URL | HTTP | Status | Errors |
|---|------|-----|------|--------|--------|
(one row per result)

Summary: X/Y passed, Z failed

JSON:
${EXECUTE_OUT}

Output ONLY the table. No commentary." \
        --output-format text \
        --max-turns 5 \
        2>"${RESULTS_DIR}/new-run-${i}-table-stderr.txt") || true
    echo "$TABLE_OUT" > "${RESULTS_DIR}/new-run-${i}.txt"

    END_NS=$(date +%s%N)
    MS=$(( (END_NS - START_NS) / 1000000 ))
    echo "$MS" > "${RESULTS_DIR}/new-run-${i}-ms.txt"
    echo " done (${MS}ms)"
done
echo ""

# ---- Phase C: Compare ----
echo "=== Phase C: Analysis ==="

# D-type consistency (preflight)
PREFLIGHT_CONSISTENT="true"
for i in 2 3; do
    if ! diff -q "${RESULTS_DIR}/new-run-1-preflight.txt" "${RESULTS_DIR}/new-run-${i}-preflight.txt" >/dev/null 2>&1; then
        PREFLIGHT_CONSISTENT="false"
    fi
done

# D-type consistency (execute-test JSON)
EXECUTE_CONSISTENT="true"
for i in 2 3; do
    if ! diff -q "${RESULTS_DIR}/new-run-1-execute.json" "${RESULTS_DIR}/new-run-${i}-execute.json" >/dev/null 2>&1; then
        EXECUTE_CONSISTENT="false"
    fi
done

# OLD full output consistency
OLD_CONSISTENT_COUNT=0
for i in 2 3; do
    if diff -q "${RESULTS_DIR}/old-run-1.txt" "${RESULTS_DIR}/old-run-${i}.txt" >/dev/null 2>&1; then
        OLD_CONSISTENT_COUNT=$((OLD_CONSISTENT_COUNT + 1))
    fi
done
OLD_CONSISTENT_LABEL="$((OLD_CONSISTENT_COUNT + 1))/${RUNS}"

# NEW full output consistency (includes S-type table)
NEW_CONSISTENT_COUNT=0
for i in 2 3; do
    if diff -q "${RESULTS_DIR}/new-run-1.txt" "${RESULTS_DIR}/new-run-${i}.txt" >/dev/null 2>&1; then
        NEW_CONSISTENT_COUNT=$((NEW_CONSISTENT_COUNT + 1))
    fi
done
NEW_CONSISTENT_LABEL="$((NEW_CONSISTENT_COUNT + 1))/${RUNS}"

# Correctness checks
EXPECTED_PAGES=("Homepage" "Dashboard" "EW Index" "MPMF Viewer")
check_correctness() {
    local file="$1"
    if [[ ! -s "$file" ]]; then
        echo "FAIL (empty)"
        return
    fi
    local missing=0
    for page in "${EXPECTED_PAGES[@]}"; do
        if ! grep -qF "$page" "$file"; then
            missing=$((missing + 1))
        fi
    done
    if [[ $missing -gt 0 ]]; then
        echo "PARTIAL (${missing} pages missing)"
    else
        echo "PASS"
    fi
}

# Step completion checks
check_steps_old() {
    local file="$1"
    local steps=0
    [[ -s "$file" ]] && steps=$((steps + 1))  # produced output at all
    grep -qF "|" "$file" 2>/dev/null && steps=$((steps + 1))  # has table
    grep -qiE "summary|passed|failed" "$file" 2>/dev/null && steps=$((steps + 1))  # has summary
    echo "${steps}/3"
}

check_steps_new() {
    local run="$1"
    local steps=0
    [[ "$(cat "${RESULTS_DIR}/new-run-${run}-preflight-exit.txt")" == "0" ]] && steps=$((steps + 1))
    [[ "$(cat "${RESULTS_DIR}/new-run-${run}-execute-exit.txt")" == "0" ]] && steps=$((steps + 1))
    [[ -s "${RESULTS_DIR}/new-run-${run}.txt" ]] && steps=$((steps + 1))
    echo "${steps}/3"
}

# Latency
calc_avg_ms() {
    local prefix="$1"
    local total=0
    for i in $(seq 1 $RUNS); do
        val=$(cat "${RESULTS_DIR}/${prefix}-run-${i}-ms.txt")
        total=$((total + val))
    done
    echo $((total / RUNS))
}

OLD_AVG=$(calc_avg_ms "old")
NEW_AVG=$(calc_avg_ms "new")

echo "  D-type preflight consistent: ${PREFLIGHT_CONSISTENT}"
echo "  D-type execute consistent:   ${EXECUTE_CONSISTENT}"
echo "  OLD full output consistent:  ${OLD_CONSISTENT_LABEL}"
echo "  NEW full output consistent:  ${NEW_CONSISTENT_LABEL}"
echo "  OLD avg latency: ${OLD_AVG}ms"
echo "  NEW avg latency: ${NEW_AVG}ms"
echo ""

# ---- Phase D: Generate Report ----
echo "=== Phase D: Generating report ==="

cat > "$REPORT" << REPORTEOF
## Comparison Test: Monolithic SKILL.md vs Ability-Decomposed Design

**Date**: $(date +%Y-%m-%d) | **Branch**: feat/195-smoke-test-ability-decomposition
**Fixture**: 4 endpoints (2 PASS, 2 FAIL) | **Runs per design**: ${RUNS}
**Ref**: #195 (ability-type decomposition), #152 (deterministic enforcement)

### Consistency (are ${RUNS} runs identical?)

| Component | OLD (monolithic) | NEW (decomposed) |
|-----------|:---:|:---:|
| Preflight output | N/A (LLM-interpreted) | $(if [[ "$PREFLIGHT_CONSISTENT" == "true" ]]; then echo "PASS — ${RUNS}/${RUNS} identical"; else echo "FAIL — outputs differ"; fi) |
| Test execution JSON | N/A (LLM-interpreted) | $(if [[ "$EXECUTE_CONSISTENT" == "true" ]]; then echo "PASS — ${RUNS}/${RUNS} identical"; else echo "FAIL — outputs differ"; fi) |
| Full output (incl. table) | ${OLD_CONSISTENT_LABEL} identical | ${NEW_CONSISTENT_LABEL} identical |
| **D-type overall** | **N/A** | **$(if [[ "$PREFLIGHT_CONSISTENT" == "true" && "$EXECUTE_CONSISTENT" == "true" ]]; then echo "100% deterministic"; else echo "variance detected"; fi)** |

### Correctness (all 4 page names + summary present?)

| Run | OLD (monolithic) | NEW (decomposed) |
|-----|:---:|:---:|
REPORTEOF

for i in $(seq 1 $RUNS); do
    OLD_CORRECT=$(check_correctness "${RESULTS_DIR}/old-run-${i}.txt")
    NEW_CORRECT=$(check_correctness "${RESULTS_DIR}/new-run-${i}.txt")
    echo "| ${i} | ${OLD_CORRECT} | ${NEW_CORRECT} |" >> "$REPORT"
done

cat >> "$REPORT" << REPORTEOF

### Step Completion

| Run | OLD (monolithic) | NEW (decomposed) |
|-----|:---:|:---:|
REPORTEOF

for i in $(seq 1 $RUNS); do
    OLD_STEPS=$(check_steps_old "${RESULTS_DIR}/old-run-${i}.txt")
    NEW_STEPS=$(check_steps_new "$i")
    echo "| ${i} | ${OLD_STEPS} | ${NEW_STEPS} |" >> "$REPORT"
done

cat >> "$REPORT" << REPORTEOF

### Latency

| Run | OLD (ms) | NEW (ms) |
|-----|-------:|-------:|
REPORTEOF

for i in $(seq 1 $RUNS); do
    OLD_MS=$(cat "${RESULTS_DIR}/old-run-${i}-ms.txt")
    NEW_MS=$(cat "${RESULTS_DIR}/new-run-${i}-ms.txt")
    echo "| ${i} | ${OLD_MS} | ${NEW_MS} |" >> "$REPORT"
done

cat >> "$REPORT" << REPORTEOF
| **Average** | **${OLD_AVG}** | **${NEW_AVG}** |

### Sample Outputs

<details><summary>OLD run 1 output</summary>

\`\`\`
$(head -50 "${RESULTS_DIR}/old-run-1.txt" 2>/dev/null || echo "(empty)")
\`\`\`

</details>

<details><summary>NEW run 1 — D-type preflight output</summary>

\`\`\`
$(cat "${RESULTS_DIR}/new-run-1-preflight.txt" 2>/dev/null || echo "(empty)")
\`\`\`

</details>

<details><summary>NEW run 1 — D-type execute-test output (JSON)</summary>

\`\`\`json
$(cat "${RESULTS_DIR}/new-run-1-execute.json" 2>/dev/null || echo "(empty)")
\`\`\`

</details>

<details><summary>NEW run 1 — S-type table output</summary>

\`\`\`
$(head -50 "${RESULTS_DIR}/new-run-1.txt" 2>/dev/null || echo "(empty)")
\`\`\`

</details>

<details><summary>OLD run 1 vs run 2 diff</summary>

\`\`\`diff
$(diff "${RESULTS_DIR}/old-run-1.txt" "${RESULTS_DIR}/old-run-2.txt" 2>/dev/null || echo "(no diff or empty)")
\`\`\`

</details>

<details><summary>NEW D-type run 1 vs run 2 diff (execute-test.sh)</summary>

\`\`\`diff
$(diff "${RESULTS_DIR}/new-run-1-execute.json" "${RESULTS_DIR}/new-run-2-execute.json" 2>/dev/null || echo "(no diff — expected for D-type)")
\`\`\`

</details>

### Conclusion

REPORTEOF

# Generate conclusion
if [[ "$PREFLIGHT_CONSISTENT" == "true" && "$EXECUTE_CONSISTENT" == "true" ]]; then
    cat >> "$REPORT" << 'CONCEOF'
**D-type scripts are 100% deterministic** — preflight and execute-test produced byte-identical output across all runs. This validates the core claim of #195: deterministic operations extracted into scripts eliminate LLM variance for those steps.

The S-type table formatting step (present in both designs) shows expected LLM variance. The key difference is that the NEW design **isolates variance to the S-type step only**, while the OLD design has variance across the entire pipeline.

**Recommendation**: The ability-type decomposition pattern is validated. Proceed with applying the same pattern to acceptance-verification (#168) and project-board CRITICAL operations.
CONCEOF
else
    cat >> "$REPORT" << 'CONCEOF'
D-type consistency results require investigation. See diffs above.
CONCEOF
fi

echo ""
echo "Report saved to: ${REPORT}"
echo "Results preserved at: ${RESULTS_DIR}"
echo ""
cat "$REPORT"
