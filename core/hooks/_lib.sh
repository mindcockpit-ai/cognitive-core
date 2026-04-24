#!/bin/bash
# SPDX-License-Identifier: FSL-1.1-ALv2
# cognitive-core shared hook library
# Sourced by all hook scripts for config loading and JSON output helpers

# CRLF self-heal: strip carriage returns if sourced from a CRLF environment (Windows Git Bash)
if [[ "${BASH_SOURCE[0]}" == *$'\r'* ]] 2>/dev/null; then
    _cc_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"
    sed -i.bak 's/\r$//' "$_cc_self" 2>/dev/null && rm -f "${_cc_self}.bak"
fi

# Resolve project directory
CC_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Load configuration (resolution order: project root > .claude/ > user defaults > env)
_cc_load_config() {
    local conf=""
    if [ -f "${CC_PROJECT_DIR}/cognitive-core.conf" ]; then
        conf="${CC_PROJECT_DIR}/cognitive-core.conf"
    elif [ -f "${CC_PROJECT_DIR}/.claude/cognitive-core.conf" ]; then
        conf="${CC_PROJECT_DIR}/.claude/cognitive-core.conf"
    elif [ -f "${HOME}/.cognitive-core/defaults.conf" ]; then
        conf="${HOME}/.cognitive-core/defaults.conf"
    fi
    if [ -n "$conf" ]; then
        # shellcheck disable=SC1090
        source "$conf"
    fi
}

# Recursive grep using ripgrep when available, falling back to grep -r
# Usage: _cc_rg [--all] [grep-compatible flags] "pattern" [path]
#   --all   Search all files including gitignored (passes --no-ignore to rg)
# Translates --include/--exclude to rg -g syntax. Strips -r/-E (rg defaults).
# Follows _cc_compute_sha256 pattern: detect available tool, never auto-install.
_cc_rg() {
    local use_no_ignore=false
    local rg_args=("--no-heading" "--color=never")
    local grep_args=()

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --all)
                use_no_ignore=true
                shift
                ;;
            -r|-R)
                grep_args+=("$1")
                shift
                ;;  # strip for rg (recursive by default)
            -E)
                grep_args+=("$1")
                shift
                ;;  # strip for rg (ERE by default)
            --include=*)
                rg_args+=("-g" "${1#--include=}")
                grep_args+=("$1")
                shift
                ;;
            --include)
                shift
                rg_args+=("-g" "$1")
                grep_args+=("--include=$1")
                shift
                ;;
            --exclude=*)
                rg_args+=("-g" "!${1#--exclude=}")
                grep_args+=("$1")
                shift
                ;;
            --exclude)
                shift
                rg_args+=("-g" "!$1")
                grep_args+=("--exclude=$1")
                shift
                ;;
            *)
                rg_args+=("$1")
                grep_args+=("$1")
                shift
                ;;
        esac
    done

    if [ "$use_no_ignore" = true ]; then
        rg_args+=("--no-ignore")
    fi

    if command -v rg &>/dev/null; then
        rg "${rg_args[@]}"
    else
        grep -r "${grep_args[@]}"
    fi
}

# Output JSON using jq if available, otherwise fallback to printf
# Usage: _cc_json_output "hookEventName" "fieldName" "fieldValue"
_cc_json_session_context() {
    local ctx="$1"
    if command -v jq &>/dev/null; then
        jq -n --arg ctx "$ctx" '{
            hookSpecificOutput: {
                hookEventName: "SessionStart",
                additionalContext: $ctx
            }
        }'
    else
        local escaped
        escaped=$(printf '%s' "$ctx" | sed 's/"/\\"/g' | tr '\n' '\\n')
        printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}' "$escaped"
    fi
}

_cc_json_pretool_deny() {
    local reason="$1"
    if command -v jq &>/dev/null; then
        jq -n --arg reason "$reason" '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "deny",
                permissionDecisionReason: $reason
            }
        }'
    else
        local escaped
        escaped=$(printf '%s' "$reason" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
        printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}' "$escaped"
    fi
}

# Structured deny with error classification
# Usage: _cc_json_pretool_deny_structured "reason" "errorCategory" "isRetryable" ["suggestion"]
# errorCategory: security | validation | permission | policy
# isRetryable: true | false
_cc_json_pretool_deny_structured() {
    local reason="${1:-}"
    local category="${2:-security}"
    local retryable="${3:-false}"
    local suggestion="${4:-}"

    if command -v jq &>/dev/null; then
        if [ -n "$suggestion" ]; then
            jq -n --arg reason "$reason" --arg cat "$category" \
                --argjson retry "$retryable" --arg sug "$suggestion" '{
                hookSpecificOutput: {
                    hookEventName: "PreToolUse",
                    permissionDecision: "deny",
                    permissionDecisionReason: $reason,
                    errorCategory: $cat,
                    isRetryable: $retry,
                    suggestion: $sug
                }
            }'
        else
            jq -n --arg reason "$reason" --arg cat "$category" \
                --argjson retry "$retryable" '{
                hookSpecificOutput: {
                    hookEventName: "PreToolUse",
                    permissionDecision: "deny",
                    permissionDecisionReason: $reason,
                    errorCategory: $cat,
                    isRetryable: $retry
                }
            }'
        fi
    else
        local escaped
        escaped=$(printf '%s' "$reason" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
        local suggestion_field=""
        if [ -n "$suggestion" ]; then
            local escaped_sug
            escaped_sug=$(printf '%s' "$suggestion" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
            suggestion_field=$(printf ',"suggestion":"%s"' "$escaped_sug")
        fi
        printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s","errorCategory":"%s","isRetryable":%s%s}}' \
            "$escaped" "$category" "$retryable" "$suggestion_field"
    fi
}

_cc_json_posttool_context() {
    local ctx="$1"
    if command -v jq &>/dev/null; then
        jq -n --arg ctx "$ctx" '{
            hookSpecificOutput: {
                hookEventName: "PostToolUse",
                additionalContext: $ctx
            }
        }'
    else
        local escaped
        escaped=$(printf '%s' "$ctx" | sed 's/"/\\"/g' | tr '\n' '\\n')
        printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}' "$escaped"
    fi
}

# PreToolUse "ask" decision (escalate to human)
_cc_json_pretool_ask() {
    local reason="$1"
    if command -v jq &>/dev/null; then
        jq -n --arg reason "$reason" '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "ask",
                permissionDecisionReason: $reason
            }
        }'
    else
        local escaped
        escaped=$(printf '%s' "$reason" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
        printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}' "$escaped"
    fi
}

# Security event logging
_cc_security_log() {
    local level="$1" event="$2" detail="$3"
    local logfile="${CC_PROJECT_DIR}/.claude/cognitive-core/security.log"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local logdir
    logdir=$(dirname "$logfile")
    [ -d "$logdir" ] || mkdir -p "$logdir"
    echo "${timestamp} [${level}] ${event}: ${detail}" >> "$logfile"
    # Log rotation: truncate if >1MB
    if [ -f "$logfile" ] && [ "$(wc -c < "$logfile" | tr -d ' ')" -gt 1048576 ]; then
        tail -500 "$logfile" > "${logfile}.tmp" && mv "${logfile}.tmp" "$logfile"
    fi
}

# Version cache with mtime invalidation (#176)
# Stores in project-local .claude/cognitive-core/ (not /tmp)
_cc_version_cache_get() {
    local cache_name="$1"
    local source_files="$2"
    local cache_dir="${CC_PROJECT_DIR}/.claude/cognitive-core"
    local cache_file="${cache_dir}/.${cache_name}-version"

    [ ! -f "$cache_file" ] && return 0

    local cached
    cached=$(cat "$cache_file" 2>/dev/null)
    case "$cached" in
        ''|*[!0-9]*) rm -f "$cache_file"; return 0 ;;
    esac

    local src
    for src in $source_files; do
        if [ -f "${CC_PROJECT_DIR}/${src}" ] && [ "${CC_PROJECT_DIR}/${src}" -nt "$cache_file" ]; then
            rm -f "$cache_file"
            return 0
        fi
    done

    echo "$cached"
}

_cc_version_cache_set() {
    local cache_name="$1"
    local value="$2"
    local cache_dir="${CC_PROJECT_DIR}/.claude/cognitive-core"
    local cache_file="${cache_dir}/.${cache_name}-version"

    case "$value" in
        ''|*[!0-9]*) return 0 ;;
    esac

    [ -d "$cache_dir" ] && echo "$value" > "$cache_file"
}

# Cross-platform SHA256
_cc_compute_sha256() {
    local file="$1"
    if command -v sha256sum &>/dev/null; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v shasum &>/dev/null; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        openssl dgst -sha256 "$file" | awk '{print $NF}'
    fi
}

# Guard wrapper: isolates guard execution, catches errors
_cc_guard_run() {
    local guard_name="$1"
    shift
    local err_file="/tmp/cc_guard_err_$$"
    if ! "$@" 2>"$err_file"; then
        local err_msg
        err_msg=$(cat "$err_file" 2>/dev/null || echo "unknown error")
        _cc_security_log "ERROR" "guard-failure" "${guard_name}: ${err_msg}"
        rm -f "$err_file"
        return 0  # NEVER crash the framework
    fi
    rm -f "$err_file"
}

# Session-scoped domain cache for hooks (e.g., validate-fetch "don't ask again")
# Cache file is scoped to the Claude session to prevent cross-session leakage.
# Uses CLAUDE_SESSION_KEY (set by Claude Code) or falls back to parent PID.
_cc_session_cache_file() {
    local namespace="${1:-domains}"
    local session_key="${CLAUDE_SESSION_KEY:-ppid_$$}"
    local cache_dir="${TMPDIR:-/tmp}"
    echo "${cache_dir}/cc-session-${namespace}-${session_key}"
}

# Add a value to the session cache (one entry per line, deduped)
_cc_session_cache_add() {
    local namespace="$1" value="$2"
    local cache_file
    cache_file=$(_cc_session_cache_file "$namespace")
    # Append only if not already present
    if [ ! -f "$cache_file" ] || ! grep -qxF "$value" "$cache_file" 2>/dev/null; then
        echo "$value" >> "$cache_file"
    fi
}

# Check if a value exists in the session cache
_cc_session_cache_has() {
    local namespace="$1" value="$2"
    local cache_file
    cache_file=$(_cc_session_cache_file "$namespace")
    [ -f "$cache_file" ] && grep -qxF "$value" "$cache_file" 2>/dev/null
}

# Canonicalize a path without python3 dependency (#256).
# Strategy: prefer the system `realpath` when available; fall back to a POSIX
# shell resolver that uses `cd` + `pwd -P` to drop `..` and symlink components.
# Signals failure via non-zero exit when the path cannot be resolved. Callers
# must NOT fall back to the raw input on failure.
_cc_realpath() {
    local p="${1:-}"
    [ -n "$p" ] || return 1
    if command -v realpath >/dev/null 2>&1; then
        realpath "$p" 2>/dev/null && return 0
        return 1
    fi
    # POSIX fallback: resolve parent directory, then reattach basename.
    # Handles both files and directories; rejects when dirname cannot be cd'd.
    local dir base resolved
    dir=$(dirname -- "$p")
    base=$(basename -- "$p")
    resolved=$(cd -- "$dir" 2>/dev/null && pwd -P) || return 1
    case "$base" in
        /) printf '/\n' ;;
        .) printf '%s\n' "$resolved" ;;
        *) printf '%s/%s\n' "$resolved" "$base" ;;
    esac
}

# Validate a framework source path before any exec/git operation (#256).
# Returns 0 only when ALL of these hold:
#   1. $CC_FRAMEWORK_ROOT is set and non-empty (anchor must be pinned)
#   2. Path argument is non-empty, absolute, free of `..` and null bytes
#   3. Canonicalized path is within canonicalized $CC_FRAMEWORK_ROOT (prefix
#      match must land on a `/` boundary to reject sibling-prefix attacks)
#   4. The directory exists
#   5. $path/update.sh is a regular file (not a symlink escaping the root),
#      executable, not setuid/setgid, and owned by the current user
# On accept: exports CC_VALIDATED_SOURCE to the canonical resolved path —
# callers MUST consume $CC_VALIDATED_SOURCE only, never the raw input.
# On deny: emits _cc_security_log DENY with {reason, path, caller} and
# returns 1 without touching CC_VALIDATED_SOURCE.
_cc_validate_framework_source() {
    local path="${1:-}"
    local caller="${FUNCNAME[1]:-top-level}"
    local reason=""

    # Anchor must be set
    if [ -z "${CC_FRAMEWORK_ROOT:-}" ]; then
        reason="CC_FRAMEWORK_ROOT unset"
        _cc_security_log "DENY" "source-validation" "${reason} path=${path} caller=${caller}"
        return 1
    fi

    # Non-empty, absolute
    if [ -z "$path" ]; then
        reason="empty path"
        _cc_security_log "DENY" "source-validation" "${reason} caller=${caller}"
        return 1
    fi
    case "$path" in
        /*) ;;
        *)
            reason="path not absolute"
            _cc_security_log "DENY" "source-validation" "${reason} path=${path} caller=${caller}"
            return 1
            ;;
    esac

    # No control characters (including NUL, newline, tab). Shell variables
    # cannot actually hold a literal NUL byte (POSIX exec boundary strips it),
    # but we reject every other control byte defensively — a path containing
    # a newline would break logging and argv parsing in callers.
    if LC_ALL=C printf '%s' "$path" | LC_ALL=C grep -q '[[:cntrl:]]'; then
        reason="path contains control character"
        _cc_security_log "DENY" "source-validation" "path=<redacted> caller=${caller}"
        return 1
    fi

    # No `..` segments (reject before resolution so we see the original intent)
    case "$path" in
        */../*|*/..|../*|..)
            reason="path contains .. segment"
            _cc_security_log "DENY" "source-validation" "${reason} path=${path} caller=${caller}"
            return 1
            ;;
    esac

    # Canonicalize both sides
    local canon_path canon_root
    canon_path=$(_cc_realpath "$path") || {
        reason="realpath failed"
        _cc_security_log "DENY" "source-validation" "${reason} path=${path} caller=${caller}"
        return 1
    }
    canon_root=$(_cc_realpath "$CC_FRAMEWORK_ROOT") || {
        reason="framework root realpath failed"
        _cc_security_log "DENY" "source-validation" "${reason} root=${CC_FRAMEWORK_ROOT} caller=${caller}"
        return 1
    }

    # Boundary check: canon_path must equal canon_root or begin with canon_root + '/'
    # Rejects sibling-prefix attacks like root=/tmp/foo, path=/tmp/foobar
    if [ "$canon_path" != "$canon_root" ]; then
        case "$canon_path" in
            "${canon_root}/"*) ;;
            *)
                reason="path outside framework root"
                _cc_security_log "DENY" "source-validation" "${reason} path=${canon_path} root=${canon_root} caller=${caller}"
                return 1
                ;;
        esac
    fi

    # Directory must exist
    if [ ! -d "$canon_path" ]; then
        reason="directory does not exist"
        _cc_security_log "DENY" "source-validation" "${reason} path=${canon_path} caller=${caller}"
        return 1
    fi

    # update.sh checks — regular file, executable, no setuid/setgid
    local updater="${canon_path}/update.sh"
    # Refuse if update.sh is a symlink (regular-file test already excludes symlinks
    # to non-files, but we want to reject even symlinks to regular files inside
    # the root: the canonicalization would let a symlink-to-outside-file pass
    # the directory boundary check).
    if [ -L "$updater" ]; then
        reason="update.sh is a symlink"
        _cc_security_log "DENY" "source-validation" "${reason} path=${updater} caller=${caller}"
        return 1
    fi
    if [ ! -f "$updater" ]; then
        reason="update.sh missing or not a regular file"
        _cc_security_log "DENY" "source-validation" "${reason} path=${updater} caller=${caller}"
        return 1
    fi
    if [ ! -x "$updater" ]; then
        reason="update.sh not executable"
        _cc_security_log "DENY" "source-validation" "${reason} path=${updater} caller=${caller}"
        return 1
    fi

    # setuid / setgid test — inline platform detection (no new helpers)
    local perms owner
    if stat -f %p "$updater" >/dev/null 2>&1; then
        # BSD/macOS: stat -f %p yields a 6-digit octal mode
        perms=$(stat -f %p "$updater" 2>/dev/null)
        owner=$(stat -f %u "$updater" 2>/dev/null)
    else
        # GNU/Linux: stat -c uses %a (symbolic octal) and %u
        perms=$(stat -c %a "$updater" 2>/dev/null)
        owner=$(stat -c %u "$updater" 2>/dev/null)
    fi
    # setuid bit 4000 / setgid bit 2000 — test by extracting the second-most-significant
    # octal digit (4 sticky-group position). We use modulo arithmetic for portability.
    if [ -n "$perms" ]; then
        # Normalize: pad to at least 5 digits (BSD) or keep short form (GNU 3-4 digits).
        # Special-bits digit is the one at position "length - 4" (0 if absent).
        local plen special
        plen=${#perms}
        if [ "$plen" -ge 4 ]; then
            special=$(printf '%s' "$perms" | cut -c$((plen - 3)))
        else
            special=0
        fi
        case "$special" in
            4|5|6|7)
                reason="update.sh has setuid bit"
                _cc_security_log "DENY" "source-validation" "${reason} path=${updater} perms=${perms} caller=${caller}"
                return 1
                ;;
        esac
        case "$special" in
            2|3|6|7)
                reason="update.sh has setgid bit"
                _cc_security_log "DENY" "source-validation" "${reason} path=${updater} perms=${perms} caller=${caller}"
                return 1
                ;;
        esac
    fi

    # Owner must match current user
    if [ -n "$owner" ] && [ "$owner" != "$(id -u)" ]; then
        reason="update.sh owner mismatch"
        _cc_security_log "DENY" "source-validation" "${reason} path=${updater} owner=${owner} uid=$(id -u) caller=${caller}"
        return 1
    fi

    # All checks passed
    export CC_VALIDATED_SOURCE="$canon_path"
    return 0
}

# Extract field from stdin JSON
# Usage: echo "$JSON" | _cc_json_get ".tool_input.command"
_cc_json_get() {
    local path="$1"
    if command -v jq &>/dev/null; then
        jq -r "${path} // \"\"" 2>/dev/null
    else
        # Basic fallback: extract simple string fields
        local key
        key=$(echo "$path" | sed 's/.*\.//')
        grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*: *"//;s/"$//'
    fi
}
