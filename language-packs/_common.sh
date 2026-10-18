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

# Convert a grep BRE to rg (Rust) regex syntax: \( \) \{ \} \| \+ \? become
# operators, while bare ( ) { } | + ? are literals and get escaped. Bracket
# expressions such as [[:space:]] are copied unchanged.
_cc_bre_to_rg() {
    local s="$1" out="" c n i=0 len=${#1}
    while [ "$i" -lt "$len" ]; do
        c="${s:i:1}"
        if [ "$c" = "\\" ] && [ $((i + 1)) -lt "$len" ]; then
            n="${s:i+1:1}"
            case "$n" in
                '('|')'|'{'|'}'|'|'|'+'|'?') out="${out}${n}" ;;
                *) out="${out}\\${n}" ;;
            esac
            i=$((i + 2))
        elif [ "$c" = "[" ]; then
            # Copy up to the closing ]; a ] right after [ or [^ is a literal
            out="${out}["; i=$((i + 1))
            [ "${s:i:1}" = "^" ] && { out="${out}^"; i=$((i + 1)); }
            [ "${s:i:1}" = "]" ] && { out="${out}]"; i=$((i + 1)); }
            while [ "$i" -lt "$len" ] && [ "${s:i:1}" != "]" ]; do
                if [ "${s:i:2}" = "[:" ]; then
                    # POSIX class like [:space:]: copy through its :]
                    while [ "$i" -lt "$len" ] && [ "${s:i:2}" != ":]" ]; do
                        out="${out}${s:i:1}"; i=$((i + 1))
                    done
                    out="${out}${s:i:2}"; i=$((i + 2))
                else
                    out="${out}${s:i:1}"; i=$((i + 1))
                fi
            done
            out="${out}${s:i:1}"; i=$((i + 1))
        else
            case "$c" in
                '('|')'|'{'|'}'|'|'|'+'|'?') out="${out}\\${c}" ;;
                *) out="${out}${c}" ;;
            esac
            i=$((i + 1))
        fi
    done
    printf '%s' "$out"
}

_cc_rg() {
    local use_no_ignore=false ere=false pattern_seen=false
    local rg_args=("--no-heading" "--color=never")
    local grep_args=()

    while [ $# -gt 0 ]; do
        case "$1" in
            --all)       use_no_ignore=true; shift ;;
            -r|-R)       grep_args+=("$1"); shift ;;
            -E)          ere=true; grep_args+=("$1"); shift ;;
            --include=*) rg_args+=("-g" "${1#--include=}"); grep_args+=("$1"); shift ;;
            --include)   shift; rg_args+=("-g" "$1"); grep_args+=("--include=$1"); shift ;;
            --exclude=*) rg_args+=("-g" "!${1#--exclude=}"); grep_args+=("$1"); shift ;;
            --exclude)   shift; rg_args+=("-g" "!$1"); grep_args+=("--exclude=$1"); shift ;;
            # Options taking a separate value (-e, -m, -A) are not supported
            -*)          rg_args+=("$1"); grep_args+=("$1"); shift ;;
            *)
                # The first operand is the pattern (BRE unless -E); the rest are paths
                if [ "$pattern_seen" = false ] && [ "$ere" = false ]; then
                    rg_args+=("$(_cc_bre_to_rg "$1")")
                else
                    rg_args+=("$1")
                fi
                pattern_seen=true
                grep_args+=("$1"); shift ;;
        esac
    done

    [ "$use_no_ignore" = true ] && rg_args+=("--no-ignore")

    if [ "$_CC_HAS_RG" -eq 1 ]; then
        rg "${rg_args[@]}"
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
