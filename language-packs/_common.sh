#!/bin/bash
# cognitive-core language pack shared utilities
# Source this from fitness-checks.sh for common functions.
#
# Provides:
#   _cc_rg()              - ripgrep with grep fallback
#   _cc_fitness_init()    - initialize check counters
#   _cc_fitness_check()   - record a check result (replaces add_check)
#   _cc_fitness_result()  - calculate score and output result line

# Recursive grep using ripgrep when available, falling back to grep -r.
# Usage: _cc_rg [--all] [flags] "pattern" [path]
#   --all   Search all files including gitignored (passes --no-ignore to rg)
# Detects rg once per session and caches the result.
if [ -z "${_CC_HAS_RG+x}" ]; then
    command -v rg &>/dev/null && _CC_HAS_RG=1 || _CC_HAS_RG=0
fi

_cc_rg() {
    local use_no_ignore=false
    local rg_args=("--no-heading" "--color=never")
    local grep_args=()

    while [ $# -gt 0 ]; do
        case "$1" in
            --all)       use_no_ignore=true; shift ;;
            -r|-R)       grep_args+=("$1"); shift ;;
            -E)          grep_args+=("$1"); shift ;;
            --include=*) rg_args+=("-g" "${1#--include=}"); grep_args+=("$1"); shift ;;
            --include)   shift; rg_args+=("-g" "$1"); grep_args+=("--include=$1"); shift ;;
            --exclude=*) rg_args+=("-g" "!${1#--exclude=}"); grep_args+=("$1"); shift ;;
            --exclude)   shift; rg_args+=("-g" "!$1"); grep_args+=("--exclude=$1"); shift ;;
            *)           rg_args+=("$1"); grep_args+=("$1"); shift ;;
        esac
    done

    [ "$use_no_ignore" = true ] && rg_args+=("--no-ignore")

    if [ "$_CC_HAS_RG" -eq 1 ]; then
        # Translate BRE escapes to ERE/Rust regex: \| → |, \( → (, \) → )
        local translated=()
        for arg in "${rg_args[@]}"; do
            arg="${arg//\\|/|}"
            arg="${arg//\\(/(}"
            arg="${arg//\\)/)}"
            translated+=("$arg")
        done
        rg "${translated[@]}"
    else
        grep -r "${grep_args[@]}"
    fi
}

# ---- Fitness check framework ----
# Eliminates boilerplate from language pack fitness-checks.sh files.
# Each pack only needs to define its language-specific checks.

_CC_FITNESS_TOTAL=0
_CC_FITNESS_PASSED=0
_CC_FITNESS_DETAILS=""

_cc_fitness_init() {
    _CC_FITNESS_TOTAL=0
    _CC_FITNESS_PASSED=0
    _CC_FITNESS_DETAILS=""
}

_cc_fitness_check() {
    local name="$1" passed="$2" detail="${3:-}"
    _CC_FITNESS_TOTAL=$((_CC_FITNESS_TOTAL + 1))
    if [ "$passed" -eq 1 ]; then
        _CC_FITNESS_PASSED=$((_CC_FITNESS_PASSED + 1))
    else
        _CC_FITNESS_DETAILS="${_CC_FITNESS_DETAILS}FAIL: ${name}${detail:+ ($detail)}; "
    fi
}

_cc_fitness_result() {
    local label="${1:-checks}"
    local score=50
    if [ "$_CC_FITNESS_TOTAL" -gt 0 ]; then
        score=$(( (_CC_FITNESS_PASSED * 100) / _CC_FITNESS_TOTAL ))
    fi
    local details="${_CC_FITNESS_DETAILS%; }"
    echo "$score ${_CC_FITNESS_PASSED}/${_CC_FITNESS_TOTAL} ${label} passed${details:+. $details}"
}
