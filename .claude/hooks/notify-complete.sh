#!/bin/bash
# cognitive-core hook: Stop | SubagentStop | Notification
# Dispatches completion notifications to enabled channels
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"
_cc_load_config

# ---- Read stdin JSON ----
INPUT=$(cat)
EVENT=$(echo "$INPUT" | _cc_json_get ".hook_event_name")

# [E4] Guard: empty or missing event name — exit silently
if [ -z "$EVENT" ]; then
    exit 0
fi

# ---- Master switch ----
# [C1] Normalise to lowercase for case-insensitive comparison
_NOTIFY_ENABLED=$(echo "${CC_NOTIFY_ENABLED:-false}" | tr '[:upper:]' '[:lower:]')
if [ "$_NOTIFY_ENABLED" != "true" ]; then
    exit 0
fi

# ---- Event whitelist ----
# Use case statement, NOT [[ =~ ]] — EVENT is untrusted input and would be
# interpreted as regex RHS, allowing bypass via metacharacters (e.g., "Stop|Evil").
ALLOWED_EVENTS="${CC_NOTIFY_EVENTS:-Stop SubagentStop Notification}"
_event_allowed=false
for _evt in $ALLOWED_EVENTS; do
    if [ "$EVENT" = "$_evt" ]; then
        _event_allowed=true
        break
    fi
done
if [ "$_event_allowed" = "false" ]; then
    exit 0
fi

# ---- Min-duration gate ----
MIN_DURATION="${CC_NOTIFY_MIN_DURATION:-30}"
# [C2] Validate MIN_DURATION is an integer
if ! [[ "$MIN_DURATION" =~ ^[0-9]+$ ]]; then
    MIN_DURATION=30
fi
# [E1] Guard: CC_PROJECT_DIR must be set
if [ -n "${CC_PROJECT_DIR:-}" ]; then
    SESSION_MARKER="${CC_PROJECT_DIR}/.claude/cognitive-core/.session-started"
    if [ -f "$SESSION_MARKER" ]; then
        # [S4] Validate session marker content is an integer
        SESSION_START=$(cat "$SESSION_MARKER" 2>/dev/null || echo "0")
        if [[ "$SESSION_START" =~ ^[0-9]+$ ]]; then
            NOW=$(date +%s)
            ELAPSED=$((NOW - SESSION_START))
            # [C4] Negative elapsed (clock skew) — treat as valid session
            if [ "$ELAPSED" -ge 0 ] && [ "$ELAPSED" -lt "$MIN_DURATION" ]; then
                _cc_security_log "INFO" "notify-skipped" "${EVENT}: session too short (${ELAPSED}s < ${MIN_DURATION}s)"
                exit 0
            fi
        fi
    fi
fi

# ---- Build message ----
case "$EVENT" in
    SubagentStop)
        AGENT_NAME=$(echo "$INPUT" | _cc_json_get ".agent_name" | tr -cd '[:print:]')
        MSG="${CC_PROJECT_NAME:-Project}: Agent complete: ${AGENT_NAME:-unknown}"
        ;;
    Stop)
        MSG="${CC_PROJECT_NAME:-Project}: Session complete"
        ;;
    Notification)
        DETAIL=$(echo "$INPUT" | _cc_json_get ".message" | tr -cd '[:print:]')
        MSG="${CC_PROJECT_NAME:-Project}: Needs attention: ${DETAIL:-check terminal}"
        ;;
    *)
        MSG="${CC_PROJECT_NAME:-Project}: ${EVENT}"
        ;;
esac

# [S1] Sanitise message: strip characters that could inject into osascript or shell
# shellcheck disable=SC1003
MSG=$(echo "$MSG" | tr -d "'\"\`\$\\\\" | cut -c1-200)

# ---- Dispatch to enabled channels ----
CHANNELS="${CC_NOTIFY_CHANNELS:-bell desktop ntfy}"

# [E5] Skip dispatch and logging if no channels configured
if [ -z "$CHANNELS" ]; then
    exit 0
fi

for channel in $CHANNELS; do
    case "$channel" in
        bell)
            printf '\a' 2>/dev/null || true
            ;;
        desktop)
            if [[ "$OSTYPE" == darwin* ]]; then
                # [S1] Use osascript with sanitised MSG (dangerous chars already stripped)
                osascript -e "display notification \"${MSG}\" with title \"Claude Code\"" 2>/dev/null &
            elif command -v notify-send &>/dev/null; then
                # [P2] Use timeout to prevent D-Bus stalls on headless Linux
                timeout 3 notify-send "Claude Code" "$MSG" 2>/dev/null &
            fi
            ;;
        ntfy)
            TOPIC="${CC_NOTIFY_NTFY_TOPIC:-}"
            # [S2] Validate topic: alphanumeric, hyphens, underscores only
            if [[ "$TOPIC" =~ ^[a-zA-Z0-9_-]+$ ]] && command -v curl &>/dev/null; then
                # [E2] Bounded timeout: 5s connect, 10s total
                # [S3] Send truncated message (first 200 chars, already enforced above)
                curl -s -m 10 --connect-timeout 5 -d "$MSG" "https://ntfy.sh/${TOPIC}" 2>/dev/null &
            fi
            ;;
    esac
done

# [E2] Wait with bounded timeout — kill any stalled dispatches after 5s
_wait_start=$(date +%s)
while jobs -p 2>/dev/null | grep -q .; do
    _wait_now=$(date +%s)
    if [ $((_wait_now - _wait_start)) -ge 5 ]; then
        # Kill any remaining background jobs
        jobs -p 2>/dev/null | xargs kill 2>/dev/null || true
        break
    fi
    sleep 0.2 2>/dev/null || sleep 1
done
wait 2>/dev/null || true

# [S3] Log truncated message (max 100 chars) to prevent secret leakage
LOG_MSG=$(echo "$MSG" | cut -c1-100)
_cc_security_log "INFO" "notify-sent" "${EVENT}: channels=[${CHANNELS}] msg=[${LOG_MSG}]"
