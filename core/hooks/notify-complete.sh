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

# ---- Master switch ----
if [ "${CC_NOTIFY_ENABLED:-false}" != "true" ]; then
    exit 0
fi

# ---- Event whitelist ----
ALLOWED_EVENTS="${CC_NOTIFY_EVENTS:-Stop SubagentStop Notification}"
if [[ ! " $ALLOWED_EVENTS " =~ [[:space:]]${EVENT}[[:space:]] ]]; then
    exit 0
fi

# ---- Min-duration gate ----
MIN_DURATION="${CC_NOTIFY_MIN_DURATION:-30}"
SESSION_MARKER="${CC_PROJECT_DIR}/.claude/cognitive-core/.session-started"
if [ -f "$SESSION_MARKER" ]; then
    SESSION_START=$(cat "$SESSION_MARKER" 2>/dev/null || echo "0")
    NOW=$(date +%s)
    ELAPSED=$((NOW - SESSION_START))
    if [ "$ELAPSED" -lt "$MIN_DURATION" ]; then
        _cc_security_log "INFO" "notify-skipped" "${EVENT}: session too short (${ELAPSED}s < ${MIN_DURATION}s)"
        exit 0
    fi
fi

# ---- Build message ----
case "$EVENT" in
    SubagentStop)
        AGENT_NAME=$(echo "$INPUT" | _cc_json_get ".agent_name")
        MSG="${CC_PROJECT_NAME:-Project}: Agent complete: ${AGENT_NAME:-unknown}"
        ;;
    Stop)
        MSG="${CC_PROJECT_NAME:-Project}: Session complete"
        ;;
    Notification)
        DETAIL=$(echo "$INPUT" | _cc_json_get ".message")
        MSG="${CC_PROJECT_NAME:-Project}: Needs attention: ${DETAIL:-check terminal}"
        ;;
    *)
        MSG="${CC_PROJECT_NAME:-Project}: ${EVENT}"
        ;;
esac

# ---- Dispatch to enabled channels ----
CHANNELS="${CC_NOTIFY_CHANNELS:-bell desktop ntfy}"

for channel in $CHANNELS; do
    case "$channel" in
        bell)
            printf '\a' 2>/dev/null || true
            ;;
        desktop)
            if [[ "$OSTYPE" == darwin* ]]; then
                osascript -e "display notification \"${MSG}\" with title \"Claude Code\"" 2>/dev/null &
            elif command -v notify-send &>/dev/null; then
                notify-send "Claude Code" "$MSG" 2>/dev/null &
            fi
            ;;
        ntfy)
            TOPIC="${CC_NOTIFY_NTFY_TOPIC:-}"
            if [ -n "$TOPIC" ] && command -v curl &>/dev/null; then
                curl -s -d "$MSG" "https://ntfy.sh/${TOPIC}" 2>/dev/null &
            fi
            ;;
    esac
done

# Wait for backgrounded dispatches (max 5s)
wait 2>/dev/null || true

_cc_security_log "INFO" "notify-sent" "${EVENT}: channels=[${CHANNELS}] msg=[${MSG}]"
