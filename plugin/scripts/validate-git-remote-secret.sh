#!/bin/bash
# cognitive-core hook: PreToolUse (Bash) + SessionStart
# Guards against credentials embedded in git remote URLs, e.g.
#   https://x-access-token:gho_XXXX@github.com/owner/repo.git
# which leaks the token in plaintext (.git/config) and pushes it around.
#
# Two modes, selected by the stdin payload:
#   - PreToolUse (a Bash command is present): DENY a git command that would
#     embed a credential in a remote URL.
#   - SessionStart (no command): AUDIT the repo's configured remotes and WARN
#     (additionalContext) if one already carries a credential.
#
# All patterns use POSIX ERE (no \s, \b, \w) for macOS + Linux compatibility.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"
_cc_load_config

# A URL carries a credential when it has userinfo with a secret part
# (scheme://user:secret@host) or a known token format.
CRED_URL_RE='://[^/@[:space:]]+:[^/@[:space:]]+@'
TOKEN_RE='(gh[opsu]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|x-access-token:)'

_cc_has_embedded_cred() {
    # $1 = text; returns 0 if a credential pattern is present.
    printf '%s' "$1" | grep -qE "$CRED_URL_RE" && return 0
    printf '%s' "$1" | grep -qE "$TOKEN_RE" && return 0
    return 1
}

_cc_redact() {
    # Scrub userinfo and bare token formats so a secret is never printed.
    sed -E -e 's#://[^/@]+(:[^/@]+)?@#://<REDACTED>@#g' \
           -e 's#(gh[opsu]_|github_pat_)[A-Za-z0-9_]{10,}#<REDACTED>#g'
}

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | _cc_json_get ".tool_input.command" || true)

# ---- PreToolUse: a Bash command is present ----
if [ -n "$CMD" ]; then
    # Only police git commands that create or use a remote URL.
    if printf '%s' "$CMD" | grep -qE '(^|[^[:alnum:]_])git([^[:alnum:]_]|$)' \
       && printf '%s' "$CMD" | grep -qE 'remote[[:space:]]+(add|set-url)|[[:space:]]clone[[:space:]]|[[:space:]](push|fetch|pull)([[:space:]]|$)|config[[:space:]]+remote\.'; then
        if _cc_has_embedded_cred "$CMD"; then
            _cc_json_pretool_deny "Refusing: this git command embeds a credential in a remote URL (token or user:secret@). Never store a secret in .git/config - use SSH or a credential helper (e.g. 'gh auth setup-git'). If the token was exposed, revoke and rotate it."
            exit 0
        fi
    fi
    exit 0
fi

# ---- SessionStart: no command -> audit configured remotes (warn only) ----
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

findings=""
while IFS= read -r name; do
    [ -z "$name" ] && continue
    while IFS= read -r url; do
        [ -z "$url" ] && continue
        if _cc_has_embedded_cred "$url"; then
            red=$(printf '%s' "$url" | _cc_redact)
            findings="${findings}  - remote '${name}': ${red}"$'\n'
        fi
    done < <( { git remote get-url --all "$name" 2>/dev/null
               git remote get-url --push --all "$name" 2>/dev/null; } | sort -u )
done < <(git remote 2>/dev/null)

if [ -n "$findings" ]; then
    _cc_json_session_context "SECURITY: a credential is embedded in a git remote URL (.git/config). Remove it (use SSH or 'gh auth setup-git') and rotate the token:"$'\n'"${findings}"
fi
exit 0
