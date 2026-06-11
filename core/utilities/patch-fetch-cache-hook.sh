#!/bin/bash
# =============================================================================
# cognitive-core: Register post-fetch-cache PostToolUse hook
# =============================================================================
# Adds the PostToolUse -> WebFetch registration for post-fetch-cache.sh to a
# project's .claude/settings.json. This enables the "ask each domain once per
# session, then stay silent" behaviour of validate-fetch.sh.
#
# Why this exists: update.sh skips settings.json (user-managed), so projects
# installed before the registration shipped get the hook FILE but never the
# registration. This patch closes that gap. Idempotent and safe to re-run.
#
# Usage:
#   patch-fetch-cache-hook.sh                    # Patch ./.claude/settings.json
#   patch-fetch-cache-hook.sh /path/to/project   # Patch a specific project
#
# Requires: jq
# =============================================================================

set -euo pipefail

# Colors (disabled if not a terminal)
if [ -t 1 ]; then
    RED="\033[0;31m"; GREEN="\033[0;32m"; YELLOW="\033[1;33m"; NC="\033[0m"
else
    RED=""; GREEN=""; YELLOW=""; NC=""
fi
info()  { printf "%b\n" "$1"; }
ok()    { printf "%b\n" "${GREEN}$1${NC}"; }
warn()  { printf "%b\n" "${YELLOW}$1${NC}" >&2; }
fail()  { printf "%b\n" "${RED}$1${NC}" >&2; exit 1; }

# Literal placeholder - Claude Code expands $CLAUDE_PROJECT_DIR at hook runtime,
# so it must NOT be expanded here. Single quotes are intentional.
# shellcheck disable=SC2016
HOOK_CMD='$CLAUDE_PROJECT_DIR/.claude/hooks/post-fetch-cache.sh'

command -v jq >/dev/null 2>&1 || fail "jq is required but not found. Install jq and re-run."

# Resolve target project dir and settings file
PROJECT_DIR="${1:-$(pwd)}"
SETTINGS="${PROJECT_DIR%/}/.claude/settings.json"

[ -f "$SETTINGS" ] || fail "Not found: ${SETTINGS}
Run this from a project root, or pass the project path as an argument."

jq empty "$SETTINGS" 2>/dev/null || fail "Invalid JSON: ${SETTINGS} (refusing to patch)"

# Warn (do not fail) if the hook script itself is missing - update.sh installs it
if [ ! -f "${PROJECT_DIR%/}/.claude/hooks/post-fetch-cache.sh" ]; then
    warn "WARNING: .claude/hooks/post-fetch-cache.sh is missing in this project."
    warn "         Run update.sh there so the hook file is installed, or the"
    warn "         registration will point at a non-existent script."
fi

# Idempotency: is post-fetch-cache already registered under a WebFetch matcher?
ALREADY=$(jq -r '
    [ .hooks.PostToolUse[]?
      | select(.matcher == "WebFetch")
      | .hooks[]?.command // empty ]
    | any(. == "'"$HOOK_CMD"'")
' "$SETTINGS")

if [ "$ALREADY" = "true" ]; then
    ok "Already registered - no change needed: ${SETTINGS}"
    exit 0
fi

# Patch: ensure the nested structure exists, then append the WebFetch entry.
TMP="$(mktemp "${TMPDIR:-/tmp}/cc-settings.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

jq --arg cmd "$HOOK_CMD" '
    .hooks = (.hooks // {})
    | .hooks.PostToolUse = (.hooks.PostToolUse // [])
    | .hooks.PostToolUse += [
        { "matcher": "WebFetch",
          "hooks": [ { "type": "command", "command": $cmd } ] }
      ]
' "$SETTINGS" > "$TMP" || fail "jq transform failed; ${SETTINGS} left unchanged."

# Verify the result is valid JSON before replacing the original
jq empty "$TMP" 2>/dev/null || fail "Produced invalid JSON; ${SETTINGS} left unchanged."

cp "$SETTINGS" "${SETTINGS}.bak"
mv "$TMP" "$SETTINGS"
trap - EXIT

ok "Registered post-fetch-cache PostToolUse hook in: ${SETTINGS}"
info "Backup saved: ${SETTINGS}.bak"
info "Restart the session (or open /hooks) so the new matcher loads."
