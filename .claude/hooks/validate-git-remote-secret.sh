#!/bin/bash
# cognitive-core hook: PreToolUse (Bash) + SessionStart
# Guards against credentials embedded in git remote URLs, e.g.
#   https://x-access-token:gho_XXXX@github.com/owner/repo.git
# which leaks the token in plaintext (.git/config) and pushes it around.
#
# Two modes, selected by the stdin payload:
#   - PreToolUse (a Bash command is present): DENY a git command that would
#     embed a credential in a remote URL.
#   - SessionStart (hook_event_name): AUDIT the project's configured remotes
#     and .gitmodules and WARN (additionalContext) if one carries a credential.
#
# Not covered: writes to .git/config through file tools or sed/echo; pair
# with server-side secret scanning.
#
# All patterns use POSIX ERE (no \s, \b, \w) for macOS + Linux compatibility.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"
_cc_load_config

# A URL carries a credential when it has userinfo with a secret part
# (scheme://user:secret@host) or a known token format as the user.
CRED_URL_RE='://[^/@[:space:]]+:[^/@[:space:]]+@'
TOKEN_RE='(gh[opsu]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20,})'

# The git command word (or the gh / hub wrappers) anywhere in a segment, so
# wrappers, subshells, bash -c, xargs, quoting and paths like /usr/bin/git
# still count, but not a .git suffix or a git-* helper name. Fail closed: a
# segment that also mentions a git operation and a credential is denied,
# even inside a quoted commit message.
GIT_WORD_RE='(^|[^A-Za-z0-9_.-])(git|gh|hub)([^A-Za-z0-9_.-]|$)'
# Git operations that store or use a URL: remotes (options allowed before the
# subcommand), submodules (.gitmodules is committed), clone/ls-remote/push/
# fetch/pull, and config writes to remote.*, url.* (insteadOf), submodule.*
# or branch.* keys.
GIT_OP_RE='remote([[:space:]]+-[^[:space:]]+)*[[:space:]]+(add|set-url)|submodule(--helper)?([[:space:]]+-[^[:space:]]+)*[[:space:]]+(add|set-url)|[[:space:]](clone|ls-remote)[[:space:]]|[[:space:]](push|fetch|pull)([[:space:]]|$)|config[[:space:]].*(remote|url|submodule|branch)\.'

_cc_has_embedded_cred() {
    # $1 = text; returns 0 if a credential pattern is present.
    # Here-strings instead of printf | grep -q: no SIGPIPE under pipefail.
    grep -qE "$CRED_URL_RE" <<< "$1" && return 0
    grep -qE "$TOKEN_RE" <<< "$1" && return 0
    return 1
}

_cc_redact() {
    # Scrub userinfo and bare token formats so a secret is never printed.
    # Up to the last @ before the path, so a password containing @ is covered
    sed -E -e 's#://[^/[:space:]]*@#://<REDACTED>@#g' \
           -e 's#(gh[opsu]_|github_pat_|glpat-)[A-Za-z0-9_-]{10,}#<REDACTED>#g'
}

_cc_log_safe() {
    # One redacted, single-line log value: control characters (newlines
    # included) would otherwise forge separate security.log entries.
    tr '[:cntrl:]' ' ' <<< "$1" | _cc_redact | head -c 300
}

# Split a command into segments on && || ; | & ( ) { } $( and backticks,
# respecting quotes: nothing splits inside '...', and inside "..." only the
# command substitutions $( and backtick do. One segment per output line.
_cc_split_segments() {
    awk -v sq="'" '
    {
        out = ""; q = ""; n = length($0)
        for (i = 1; i <= n; i++) {
            c = substr($0, i, 1); two = substr($0, i, 2)
            if (c == "\\" && q != sq) { out = out c substr($0, i + 1, 1); i++; continue }
            if (q == sq) { out = out c; if (c == sq) q = ""; continue }
            if (q == "\"") {
                if (two == "$(") { out = out "\n"; i++; continue }
                if (c == "`") { out = out "\n"; continue }
                out = out c; if (c == "\"") q = ""; continue
            }
            if (c == sq || c == "\"") { q = c; out = out c; continue }
            if (two == "&&" || two == "||" || two == "$(") { out = out "\n"; i++; continue }
            if (index(";|&`(){}", c) > 0) { out = out "\n"; continue }
            out = out c
        }
        print out
    }' <<< "$1"
}

INPUT=$(cat)
EVENT=$(printf '%s' "$INPUT" | _cc_json_get ".hook_event_name" || true)
CMD=$(printf '%s' "$INPUT" | _cc_json_get ".tool_input.command" || true)

# ---- PreToolUse: a Bash command is present ----
if [ -n "$CMD" ]; then
    # Check each segment of a compound command on its own, so a credential in
    # another command of the chain (a grep pattern, an echo) is not mistaken
    # for one passed to a git remote operation. xargs takes its arguments from
    # elsewhere in the chain, so there the whole command is checked.
    while IFS= read -r segment; do
        if grep -qE "$GIT_WORD_RE" <<< "$segment" \
           && grep -qE "$GIT_OP_RE" <<< "$segment" \
           && { _cc_has_embedded_cred "$segment" \
                || { grep -qE '(^|[^A-Za-z0-9_])xargs([^A-Za-z0-9_]|$)' <<< "$segment" && _cc_has_embedded_cred "$CMD"; }; }; then
            _cc_security_log "DENY" "git-remote-secret" "credential in git remote URL | cmd=$(_cc_log_safe "$CMD")"
            _cc_json_pretool_deny "Refusing: this git command embeds a credential in a remote URL (token or user:secret@). Never store a secret in .git/config or .gitmodules - use SSH or a credential helper (e.g. 'gh auth setup-git'). If the token was exposed, revoke and rotate it."
            exit 0
        fi
    done < <(_cc_split_segments "$CMD")
    exit 0
fi

# ---- SessionStart only: audit configured remotes (warn only) ----
# Any other payload (another event, unparseable input) is left alone.
[ "$EVENT" = "SessionStart" ] || exit 0
git -C "$CC_PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1 || exit 0

findings=""
_cc_audit_url() {
    # $1 = label, $2 = url
    if [ -n "$2" ] && _cc_has_embedded_cred "$2"; then
        findings="${findings}  - $1: $(_cc_redact <<< "$2")"$'\n'
    fi
}

while IFS= read -r name; do
    [ -z "$name" ] && continue
    while IFS= read -r url; do
        _cc_audit_url "remote '${name}'" "$url"
    done < <( { git -C "$CC_PROJECT_DIR" remote get-url --all "$name" 2>/dev/null
               git -C "$CC_PROJECT_DIR" remote get-url --push --all "$name" 2>/dev/null; } | sort -u )
done < <(git -C "$CC_PROJECT_DIR" remote 2>/dev/null)

# .gitmodules is committed, so a credential there is published with the repo
if [ -f "${CC_PROJECT_DIR}/.gitmodules" ]; then
    while IFS= read -r line; do
        # "<key> <url>": the key may contain spaces, the URL cannot
        _cc_audit_url ".gitmodules ${line% *}" "${line##* }"
    done < <(git config -f "${CC_PROJECT_DIR}/.gitmodules" --get-regexp 'submodule\..*\.url' 2>/dev/null)
fi

if [ -n "$findings" ]; then
    _cc_security_log "WARN" "git-remote-secret" "credential in configured git remote: $(tr '\n' ' ' <<< "$findings")"
    _cc_json_session_context "SECURITY: a credential is embedded in a git remote URL (.git/config or .gitmodules). Remove it (use SSH or 'gh auth setup-git') and rotate the token:"$'\n'"${findings}"
fi
exit 0
