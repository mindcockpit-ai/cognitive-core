#!/usr/bin/env bash
# =============================================================================
# Push Metrics to Pushgateway — cognitive-core framework
# =============================================================================
# Pushes CI/CD metrics to Prometheus Pushgateway.
#
# Finding #17 fix: Corrected gauge semantics.
# - Gauges (fitness_score, test_pass_rate) set absolute values, NOT incremented.
# - Job start/end use timestamp-based gauges, NOT counters.
# - Each push replaces all metrics for the job grouping key.
#
# Usage:
#   bash push-metrics.sh push_fitness --project myapp --score 85
#   bash push-metrics.sh push_job_start --project myapp --job lint
#   bash push-metrics.sh push_job_end --project myapp --job lint --status success
#   bash push-metrics.sh push_test_results --project myapp --total 150 --passed 145 --failed 5
#
# Environment variables:
#   PUSHGATEWAY_URL   URL of pushgateway (default: http://127.0.0.1:9091)
#   PROJECT_NAME      Default project name
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
PUSHGATEWAY_URL="${PUSHGATEWAY_URL:-http://127.0.0.1:9091}"
PROJECT="${PROJECT_NAME:-unknown}"
JOB_NAME=""
STATUS=""
SCORE=""
TEST_TOTAL=""
TEST_PASSED=""
TEST_FAILED=""

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
COMMAND="${1:-help}"
shift || true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project)  PROJECT="$2"; shift 2 ;;
        --job)      JOB_NAME="$2"; shift 2 ;;
        --status)   STATUS="$2"; shift 2 ;;
        --score)    SCORE="$2"; shift 2 ;;
        --total)    TEST_TOTAL="$2"; shift 2 ;;
        --passed)   TEST_PASSED="$2"; shift 2 ;;
        --failed)   TEST_FAILED="$2"; shift 2 ;;
        --gateway)  PUSHGATEWAY_URL="$2"; shift 2 ;;
        --help|-h)  COMMAND="help"; shift ;;
        *)          echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Helper: push metrics via HTTP POST
# Finding #17: Use PUT to replace all metrics for the grouping key.
# This ensures gauge values are SET (not accumulated) on each push.
# ---------------------------------------------------------------------------
push_to_gateway() {
    local job_label="$1"
    local instance_label="${2:-}"
    local payload="$3"

    local url="${PUSHGATEWAY_URL}/metrics/job/${job_label}"
    if [ -n "$instance_label" ]; then
        url="${url}/instance/${instance_label}"
    fi

    # PUT replaces all metrics for this grouping key (correct gauge semantics)
    # POST would append, which is wrong for gauges.
    local response
    response=$(curl -s -w "\n%{http_code}" -X PUT --data-binary "$payload" "$url" 2>&1)
    local http_code
    http_code=$(echo "$response" | tail -1)
    local body
    body=$(echo "$response" | head -n -1)

    if [[ "$http_code" =~ ^2 ]]; then
        echo "Metrics pushed successfully (HTTP $http_code)"
    else
        echo "Warning: Push returned HTTP $http_code: $body" >&2
    fi
}

# ---------------------------------------------------------------------------
# Command: push_fitness
# Finding #17: fitness_score is a GAUGE — set to absolute value, not delta.
# ---------------------------------------------------------------------------
push_fitness() {
    local score="${SCORE:?--score is required}"

    local payload
    payload=$(cat <<METRICS
# HELP fitness_score Current fitness score (0-100)
# TYPE fitness_score gauge
fitness_score{project="${PROJECT}"} ${score}
# HELP fitness_score_timestamp_seconds When the fitness check was run
# TYPE fitness_score_timestamp_seconds gauge
fitness_score_timestamp_seconds{project="${PROJECT}"} $(date +%s)
METRICS
    )

    push_to_gateway "fitness" "$PROJECT" "$payload"
}

# ---------------------------------------------------------------------------
# Command: push_job_start
# Records the start time of a CI/CD job as a gauge (epoch seconds).
# ---------------------------------------------------------------------------
push_job_start() {
    local job="${JOB_NAME:?--job is required}"
    local now
    now=$(date +%s)

    local payload
    payload=$(cat <<METRICS
# HELP cicd_job_start_time_seconds Epoch time when the job started
# TYPE cicd_job_start_time_seconds gauge
cicd_job_start_time_seconds{project="${PROJECT}",job_name="${job}"} ${now}
# HELP cicd_job_running Is the job currently running (1=yes, 0=no)
# TYPE cicd_job_running gauge
cicd_job_running{project="${PROJECT}",job_name="${job}"} 1
METRICS
    )

    push_to_gateway "cicd_job_${job}" "$PROJECT" "$payload"
}

# ---------------------------------------------------------------------------
# Command: push_job_end
# Records completion with duration and status.
# Finding #17: status is a labeled gauge (1=occurred), not a counter.
# ---------------------------------------------------------------------------
push_job_end() {
    local job="${JOB_NAME:?--job is required}"
    local status="${STATUS:?--status is required}"
    local now
    now=$(date +%s)

    # Calculate duration if start time was pushed
    local start_metric
    start_metric=$(curl -s "${PUSHGATEWAY_URL}/metrics" 2>/dev/null | \
        grep "cicd_job_start_time_seconds.*job_name=\"${job}\".*project=\"${PROJECT}\"" | \
        awk '{print $NF}' || echo "")

    local duration=0
    if [ -n "$start_metric" ]; then
        duration=$((now - ${start_metric%.*}))
    fi

    # Map status to numeric: success=1, failure=0
    local status_value=0
    [ "$status" = "success" ] && status_value=1

    local payload
    payload=$(cat <<METRICS
# HELP cicd_job_duration_seconds Duration of the CI/CD job in seconds
# TYPE cicd_job_duration_seconds gauge
cicd_job_duration_seconds{project="${PROJECT}",job_name="${job}"} ${duration}
# HELP cicd_job_status Status of the CI/CD job (labeled by status string)
# TYPE cicd_job_status gauge
cicd_job_status{project="${PROJECT}",job_name="${job}",status="${status}"} 1
# HELP cicd_job_end_time_seconds Epoch time when the job finished
# TYPE cicd_job_end_time_seconds gauge
cicd_job_end_time_seconds{project="${PROJECT}",job_name="${job}"} ${now}
# HELP cicd_job_running Is the job currently running (1=yes, 0=no)
# TYPE cicd_job_running gauge
cicd_job_running{project="${PROJECT}",job_name="${job}"} 0
METRICS
    )

    push_to_gateway "cicd_job_${job}" "$PROJECT" "$payload"
}

# ---------------------------------------------------------------------------
# Command: push_test_results
# Finding #17: All test metrics are gauges (absolute snapshot values).
# ---------------------------------------------------------------------------
push_test_results() {
    local total="${TEST_TOTAL:?--total is required}"
    local passed="${TEST_PASSED:-0}"
    local failed="${TEST_FAILED:-0}"

    # Calculate pass rate
    local pass_rate=100
    if [ "$total" -gt 0 ]; then
        pass_rate=$((passed * 100 / total))
    fi

    local payload
    payload=$(cat <<METRICS
# HELP cicd_test_total Total number of tests in the latest run
# TYPE cicd_test_total gauge
cicd_test_total{project="${PROJECT}"} ${total}
# HELP cicd_test_passed Number of tests that passed
# TYPE cicd_test_passed gauge
cicd_test_passed{project="${PROJECT}"} ${passed}
# HELP cicd_test_failed Number of tests that failed
# TYPE cicd_test_failed gauge
cicd_test_failed{project="${PROJECT}"} ${failed}
# HELP cicd_test_pass_rate Test pass rate as percentage (0-100)
# TYPE cicd_test_pass_rate gauge
cicd_test_pass_rate{project="${PROJECT}"} ${pass_rate}
# HELP cicd_test_timestamp_seconds When the test run completed
# TYPE cicd_test_timestamp_seconds gauge
cicd_test_timestamp_seconds{project="${PROJECT}"} $(date +%s)
METRICS
    )

    push_to_gateway "cicd_tests" "$PROJECT" "$payload"
}

# ---------------------------------------------------------------------------
# Command: help
# ---------------------------------------------------------------------------
show_help() {
    cat <<'HELP'
Push Metrics to Pushgateway — cognitive-core framework

Commands:
  push_fitness       Push fitness score gauge
  push_job_start     Record CI/CD job start time
  push_job_end       Record CI/CD job end time, duration, status
  push_test_results  Push test result gauges

Options:
  --project NAME     Project name label (default: $PROJECT_NAME)
  --job NAME         Job name (for job_start/job_end)
  --status STATUS    Job status: success|failure (for job_end)
  --score N          Fitness score 0-100 (for push_fitness)
  --total N          Total tests (for push_test_results)
  --passed N         Passed tests (for push_test_results)
  --failed N         Failed tests (for push_test_results)
  --gateway URL      Pushgateway URL (default: $PUSHGATEWAY_URL)

Examples:
  push-metrics.sh push_fitness --project myapp --score 85
  push-metrics.sh push_job_start --project myapp --job lint
  push-metrics.sh push_job_end --project myapp --job lint --status success
  push-metrics.sh push_test_results --project myapp --total 150 --passed 145 --failed 5
HELP
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
case "$COMMAND" in
    push_fitness)      push_fitness ;;
    push_job_start)    push_job_start ;;
    push_job_end)      push_job_end ;;
    push_test_results) push_test_results ;;
    help|--help|-h)    show_help ;;
    *)
        echo "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac
