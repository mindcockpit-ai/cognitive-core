#!/usr/bin/env bash
# =============================================================================
# Fitness Check — cognitive-core framework
# =============================================================================
# Pluggable quality scoring with weighted checks and progressive gates.
# Language-agnostic core — language-specific checks loaded from packs.
#
# Usage:
#   bash fitness-check.sh                  # Full report
#   bash fitness-check.sh --score-only     # Print score number only
#   bash fitness-check.sh --verbose        # Detailed output
#   bash fitness-check.sh --gate merge     # Check against gate threshold
#
# Environment variables:
#   FITNESS_CONFIG      Path to config file (default: .fitness.yml)
#   FITNESS_PACKS_DIR   Directory containing language pack fitness checks
#   GATE_MERGE_THRESHOLD   Minimum score for merge gate (default: 70)
#   GATE_DEPLOY_THRESHOLD  Minimum score for deploy gate (default: 80)
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCORE_ONLY=false
VERBOSE=false
GATE=""
CONFIG_FILE="${FITNESS_CONFIG:-.fitness.yml}"
PACKS_DIR="${FITNESS_PACKS_DIR:-language-packs}"
GATE_MERGE_THRESHOLD="${GATE_MERGE_THRESHOLD:-70}"
GATE_DEPLOY_THRESHOLD="${GATE_DEPLOY_THRESHOLD:-80}"

# Color codes (disabled if not a terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'
    YELLOW='\033[0;33m'
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' YELLOW='' GREEN='' BLUE='' BOLD='' NC=''
fi

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --score-only) SCORE_ONLY=true; shift ;;
        --verbose|-v) VERBOSE=true; shift ;;
        --gate) GATE="$2"; shift 2 ;;
        --config) CONFIG_FILE="$2"; shift 2 ;;
        --packs-dir) PACKS_DIR="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: fitness-check.sh [--score-only] [--verbose] [--gate merge|deploy]"
            exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Scoring accumulators
# ---------------------------------------------------------------------------
TOTAL_WEIGHT=0
WEIGHTED_SCORE=0
CHECKS_RUN=0
CHECKS_PASSED=0
declare -a CHECK_RESULTS=()

# ---------------------------------------------------------------------------
# Helper: record a check result
# ---------------------------------------------------------------------------
record_check() {
    local name="$1"
    local weight="$2"
    local score="$3"   # 0-100
    local detail="${4:-}"

    TOTAL_WEIGHT=$((TOTAL_WEIGHT + weight))
    WEIGHTED_SCORE=$((WEIGHTED_SCORE + (weight * score)))
    CHECKS_RUN=$((CHECKS_RUN + 1))
    [ "$score" -ge 50 ] && CHECKS_PASSED=$((CHECKS_PASSED + 1))

    # Color based on score
    local color="$RED"
    [ "$score" -ge 40 ] && color="$YELLOW"
    [ "$score" -ge 70 ] && color="$GREEN"

    CHECK_RESULTS+=("${color}[${score}%]${NC} ${name} (weight: ${weight}) ${detail}")

    if [ "$VERBOSE" = "true" ]; then
        echo -e "  ${color}[${score}%]${NC} ${name} (weight: ${weight}) ${detail}"
    fi
}

# ---------------------------------------------------------------------------
# Core checks (language-agnostic)
# ---------------------------------------------------------------------------
run_core_checks() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${BOLD}Core Checks${NC}"
    fi

    # --- Check: Git cleanliness ---
    local git_score=100
    if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
        local dirty_count
        dirty_count=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        if [ "$dirty_count" -gt 0 ]; then
            git_score=$((100 - dirty_count * 5))
            [ "$git_score" -lt 0 ] && git_score=0
        fi
        record_check "Git cleanliness" 5 "$git_score" "(${dirty_count} uncommitted files)"
    else
        record_check "Git cleanliness" 5 50 "(not a git repo)"
    fi

    # --- Check: README/documentation exists ---
    local doc_score=0
    [ -f "README.md" ] || [ -f "README" ] || [ -f "readme.md" ] && doc_score=$((doc_score + 50))
    [ -d "docs" ] && doc_score=$((doc_score + 25))
    [ -f "CHANGELOG.md" ] || [ -f "CHANGES" ] && doc_score=$((doc_score + 25))
    record_check "Documentation" 5 "$doc_score"

    # --- Check: CI/CD config exists ---
    local ci_score=0
    if [ -d ".github/workflows" ] && ls .github/workflows/*.yml &>/dev/null 2>&1; then
        ci_score=100
    elif [ -f ".gitlab-ci.yml" ] || [ -f "Jenkinsfile" ] || [ -f ".circleci/config.yml" ]; then
        ci_score=100
    fi
    record_check "CI/CD configuration" 10 "$ci_score"

    # --- Check: No secrets in codebase ---
    local secret_score=100
    if command -v grep &>/dev/null; then
        local secret_hits
        secret_hits=$(grep -rEli '(password|secret|api_key|token)\s*[:=]\s*["\x27][A-Za-z0-9+/]{16,}' \
            --include='*.yml' --include='*.yaml' --include='*.json' --include='*.env' \
            --include='*.conf' --include='*.cfg' --include='*.ini' \
            . 2>/dev/null | grep -v node_modules | grep -v '.env.template' | wc -l | tr -d ' ')
        if [ "$secret_hits" -gt 0 ]; then
            secret_score=$((100 - secret_hits * 20))
            [ "$secret_score" -lt 0 ] && secret_score=0
        fi
    fi
    record_check "No hardcoded secrets" 15 "$secret_score"

    # --- Check: Dependency manifest exists ---
    local dep_score=0
    for f in cpanfile package.json requirements.txt Pipfile pyproject.toml go.mod Cargo.toml Gemfile pom.xml build.gradle; do
        if [ -f "$f" ]; then
            dep_score=100
            break
        fi
    done
    record_check "Dependency manifest" 5 "$dep_score"

    # --- Check: Test directory exists ---
    local test_score=0
    for d in t tests test spec __tests__; do
        if [ -d "$d" ]; then
            local test_count
            test_count=$(find "$d" -type f \( -name '*.t' -o -name '*.test.*' -o -name '*_test.*' \
                -o -name 'test_*' -o -name '*Test.*' -o -name '*.spec.*' \) 2>/dev/null | wc -l | tr -d ' ')
            if [ "$test_count" -gt 0 ]; then
                test_score=100
            else
                test_score=50
            fi
            break
        fi
    done
    record_check "Test suite" 15 "$test_score"

    # --- Check: .gitignore exists and covers basics ---
    local ignore_score=0
    if [ -f ".gitignore" ]; then
        ignore_score=60
        grep -q 'node_modules\|__pycache__\|\.env\|\.DS_Store\|local/' .gitignore 2>/dev/null && ignore_score=100
    fi
    record_check ".gitignore quality" 5 "$ignore_score"
}

# ---------------------------------------------------------------------------
# Language pack checks (pluggable)
# ---------------------------------------------------------------------------
run_pack_checks() {
    if [ "$VERBOSE" = "true" ]; then
        echo ""
        echo -e "${BOLD}Language Pack Checks${NC}"
    fi

    local pack_weight=40  # Remaining weight for pack checks
    local packs_found=0

    # Discover and run language pack fitness scripts
    if [ -d "$PACKS_DIR" ]; then
        for pack_dir in "$PACKS_DIR"/*/; do
            local fitness_script="${pack_dir}scripts/fitness-check.sh"
            if [ -x "$fitness_script" ]; then
                packs_found=$((packs_found + 1))
                local pack_name
                pack_name=$(basename "$pack_dir")

                if [ "$VERBOSE" = "true" ]; then
                    echo -e "  ${BLUE}Loading pack: ${pack_name}${NC}"
                fi

                # Pack scripts should output: SCORE DESCRIPTION
                # e.g., "85 Perl::Critic severity 4 passed"
                local pack_output
                pack_output=$("$fitness_script" 2>/dev/null || echo "0 Pack check failed")
                local pack_score
                pack_score=$(echo "$pack_output" | head -1 | awk '{print $1}')
                local pack_detail
                pack_detail=$(echo "$pack_output" | head -1 | cut -d' ' -f2-)

                # Validate score is numeric
                if ! [[ "$pack_score" =~ ^[0-9]+$ ]]; then
                    pack_score=0
                    pack_detail="Invalid score output from pack"
                fi

                record_check "Pack: ${pack_name}" "$((pack_weight / packs_found))" "$pack_score" "$pack_detail"
            fi
        done
    fi

    # If no packs found, give partial credit for having the framework
    if [ "$packs_found" -eq 0 ]; then
        record_check "Language packs" "$pack_weight" 50 "(no packs installed — using defaults)"
    fi
}

# ---------------------------------------------------------------------------
# Calculate final score
# ---------------------------------------------------------------------------
calculate_score() {
    if [ "$TOTAL_WEIGHT" -gt 0 ]; then
        echo $((WEIGHTED_SCORE / TOTAL_WEIGHT))
    else
        echo 0
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
run_core_checks
run_pack_checks

FINAL_SCORE=$(calculate_score)

# Score-only mode: just print the number
if [ "$SCORE_ONLY" = "true" ]; then
    echo "$FINAL_SCORE"
    exit 0
fi

# Full report
echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD}  FITNESS REPORT${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""

for result in "${CHECK_RESULTS[@]}"; do
    echo -e "  $result"
done

echo ""
echo -e "${BOLD}----------------------------------------${NC}"

# Color-coded final score
SCORE_COLOR="$RED"
[ "$FINAL_SCORE" -ge 40 ] && SCORE_COLOR="$YELLOW"
[ "$FINAL_SCORE" -ge 70 ] && SCORE_COLOR="$GREEN"

echo -e "  ${BOLD}Final Score: ${SCORE_COLOR}${FINAL_SCORE}/100${NC}"
echo -e "  Checks: ${CHECKS_PASSED}/${CHECKS_RUN} passed"
echo -e "${BOLD}========================================${NC}"

# Gate check
if [ -n "$GATE" ]; then
    local_threshold=0
    case "$GATE" in
        merge)  local_threshold="$GATE_MERGE_THRESHOLD" ;;
        deploy) local_threshold="$GATE_DEPLOY_THRESHOLD" ;;
        *)      echo "Unknown gate: $GATE"; exit 1 ;;
    esac

    echo ""
    if [ "$FINAL_SCORE" -ge "$local_threshold" ]; then
        echo -e "  ${GREEN}GATE PASSED${NC}: Score ${FINAL_SCORE} >= threshold ${local_threshold} (${GATE})"
        exit 0
    else
        echo -e "  ${RED}GATE FAILED${NC}: Score ${FINAL_SCORE} < threshold ${local_threshold} (${GATE})"
        exit 1
    fi
fi

exit 0
