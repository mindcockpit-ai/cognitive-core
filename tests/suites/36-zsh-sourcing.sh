#!/bin/bash
# Test suite: _lib.sh sourced into zsh (#429)
# Skill snippets (skill-sync, skill-updater) source _lib.sh into the user's
# shell, which is zsh on macOS. zsh ties `path` to PATH, has no BASH_SOURCE
# and no `read -a`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "36 - zsh Sourcing"

LIB="${ROOT_DIR}/core/hooks/_lib.sh"

# ---- Static: no local or typeset of a zsh special parameter ----
ZSH_SPECIAL='path|fpath|cdpath|manpath|mailpath|module_path|psvar|status|pipestatus|argv|options|commands|functions|aliases|parameters|history|signals|dirstack|modules|builtins|funcstack|mapfile|histchars|ARGC|ERRNO'
bad=$(grep -nE "(local|declare|typeset)[[:space:]]+(-[a-zA-Z]+[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*(=[^ ]*)?[[:space:]]+)*(${ZSH_SPECIAL})(=|[[:space:]]|$)" "$LIB" || true)
assert_eq "_lib.sh declares no zsh special parameter as a local" "" "$bad"
assert_eq "_lib.sh uses no read -a" "" "$(grep -nE 'read[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*-[a-zA-Z]*a' "$LIB" | grep -vE '^[0-9]+:[[:space:]]*#' || true)"

if ! command -v zsh &>/dev/null; then
    _skip "zsh not installed (runtime checks)"
    suite_end
    exit 0
fi

# ---- Runtime: a minimal install with a framework root pinned in the conf ----
W=$(create_test_dir)
W=$(cd "$W" && pwd -P)
proj="${W}/proj"
mkdir -p "${W}/fw" "${proj}/.claude/hooks" "${proj}/.claude/cognitive-core"
printf '#!/bin/bash\n' > "${W}/fw/update.sh"
chmod 755 "${W}/fw/update.sh"
cp "$LIB" "${proj}/.claude/hooks/_lib.sh"
printf '{"source":"%s"}\n' "${W}/fw" > "${proj}/.claude/cognitive-core/version.json"
printf 'x\n' > "${proj}/.claude/hooks/validate-read.sh"
pin=$(shasum -a 256 "${proj}/.claude/hooks/validate-read.sh" | cut -d' ' -f1)
printf 'CC_PROJECT_NAME="z"\nCC_FRAMEWORK_ROOT="%s"\nCC_LOCAL_OVERRIDES="  skills/a/\tagents/b.md hooks/validate-read.sh@%s hooks/validate-write.sh *\nagents/next-line.md"\n' \
    "$W" "$pin" > "${proj}/cognitive-core.conf"

# Runs a snippet in <shell> from the project dir, like the Bash tool does
# (no CLAUDE_PROJECT_DIR, no CC_* from the environment)
in_shell() { # <shell> <snippet>
    (cd "$proj" && env -u CLAUDE_PROJECT_DIR -u CC_FRAMEWORK_ROOT -u CC_LOCAL_OVERRIDES "$1" -c "$2" 2>&1) || true
}

# skill-sync prerequisite exactly as rendered
snip=$(grep -m1 '^!`VF=' "${ROOT_DIR}/core/skills/skill-sync/SKILL.md" | sed 's/^!`//; s/`$//')
assert_contains "skill-sync prerequisite: snippet found" "$snip" "_cc_validate_framework_source"
for sh in bash zsh; do
    assert_eq "${sh}: skill-sync prerequisite accepts a valid source" "Framework: ${W}/fw" "$(in_shell "$sh" "$snip" | head -1)"
done

# The three functions of #429, plus the override helpers; PATH must survive
probe='. .claude/hooks/_lib.sh; _cc_load_config
printf "dir=%s\n" "$(cd "$CC_PROJECT_DIR" && pwd -P)"
_cc_validate_framework_source "$CC_FRAMEWORK_ROOT/fw"; printf "validate=%s %s\n" $? "$CC_VALIDATED_SOURCE"
for a in skills/a/x.md agents/b.md agents/c.md hooks/validate-read.sh hooks/validate-write.sh agents/next-line.md "*" hooks/zz.sh; do
    _cc_is_local_override "$a" ".claude/$a"; printf "override %s=%s\n" "$a" $?
done
_cc_has_local_override_under skills/; printf "under skills/=%s\n" $?
_cc_has_local_override_under rules/; printf "under rules/=%s\n" $?
printf "json=%s\n" "$(printf "{\"a\":{\"b\":\"v\"}}" | _cc_json_get .a.b)"
date >/dev/null && echo "PATH intact"'
expected="dir=${proj}
validate=0 ${W}/fw
override skills/a/x.md=0
override agents/b.md=0
override agents/c.md=1
override hooks/validate-read.sh=0
override hooks/validate-write.sh=2
override agents/next-line.md=1
override *=0
override hooks/zz.sh=1
under skills/=0
under rules/=1
json=v
PATH intact"
bash_out=$(in_shell bash "$probe")
zsh_out=$(in_shell zsh "$probe")
assert_eq "bash: functions behave as specified" "$expected" "$bash_out"
assert_eq "zsh: functions behave as in bash" "$expected" "$zsh_out"

suite_end
