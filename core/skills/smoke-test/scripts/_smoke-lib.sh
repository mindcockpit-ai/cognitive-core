#!/bin/bash
# =============================================================================
# _smoke-lib.sh — Shared library for smoke-test ability scripts
#
# Provides: config loading, validation, output helpers.
# Sourced by each ability script. Never executed directly.
# =============================================================================

_st_load_config() {
    local dir="${PROJECT_DIR:-.}"
    local conf
    for conf in "$dir/cognitive-core.conf" "$dir/.claude/cognitive-core.conf" "$HOME/.cognitive-core/defaults.conf"; do
        if [[ -f "$conf" ]]; then
            # shellcheck source=/dev/null
            source "$conf"
            return 0
        fi
    done
    _st_die "cognitive-core.conf not found in $dir or ~/.cognitive-core/"
}

_st_repo() {
    echo "${CC_ORG:?CC_ORG not set}/${CC_PROJECT_NAME:?CC_PROJECT_NAME not set}"
}

_st_label() {
    echo "${CC_SMOKE_TEST_LABEL:-smoke-test}"
}

_st_die() {
    echo "ERROR: $1" >&2
    exit 1
}

_st_info() {
    echo "INFO: $1" >&2
}

_st_require_var() {
    local name="$1"
    if [[ -z "${!name:-}" ]]; then
        _st_die "$name is not set. Configure it in cognitive-core.conf"
    fi
}

_st_require_gh() {
    if ! command -v gh &>/dev/null; then
        _st_die "gh CLI not available. Install: https://cli.github.com/"
    fi
}
