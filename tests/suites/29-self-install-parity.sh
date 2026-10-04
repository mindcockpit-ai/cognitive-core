#!/bin/bash
# Test suite: the framework's own install (.claude/) matches core/
# The self-install has no tracked manifest, so update.sh never refreshes it
# in CI. Without this check it drifted for months (a stale _lib.sh session
# key re-prompted every WebFetch). Change core/ and .claude/ together.
# Iterates from core/, so a framework file missing from the install fails.
# Extra installed files (project-local components) are not checked.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "29 - Self-Install Parity"

INST="${ROOT_DIR}/.claude"
# Core hooks deliberately not installed in the self-install, with the reason
#   validate-reply-links: new in #369, needs Stop wiring in settings.json;
#   installed with #371 (CC_HOOKS reconciliation)
EXCLUDE_HOOKS=" validate-reply-links.sh "

if [ ! -d "${INST}/hooks" ]; then
    _fail "self-install present" "${INST}/hooks not found"
    suite_end || true
    exit 1
fi

differ=""
note() { differ="${differ}"$'\n'"$1"; }

# check_pair <installed> <framework source> <mode rule: same|exec>
check_pair() {
    local inst="$1" src="$2" rel="${1#"${ROOT_DIR}/"}"
    if [ ! -f "$inst" ]; then
        note "missing: ${rel}"
        return 0
    fi
    cmp -s "$src" "$inst" || note "differs: ${rel}"
    case "$3" in
        exec) [ -x "$inst" ] || note "not executable: ${rel}" ;;
        same) if [ -x "$src" ] && [ ! -x "$inst" ]; then note "lost exec bit: ${rel}"; fi ;;
    esac
}

# Hooks: every core hook (installed hooks are always executable, update.sh
# sets +x on all of them)
n_hooks=0 e_hooks=0
for src in "${ROOT_DIR}"/core/hooks/*.sh; do
    case "$EXCLUDE_HOOKS" in *" ${src##*/} "*) continue ;; esac
    e_hooks=$((e_hooks + 1))
    check_pair "${INST}/hooks/${src##*/}" "$src" exec
    n_hooks=$((n_hooks + 1))
done

# Agents: every core agent
n_agents=0 e_agents=0
for src in "${ROOT_DIR}"/core/agents/*.md; do
    e_agents=$((e_agents + 1))
    check_pair "${INST}/agents/${src##*/}" "$src" same
    n_agents=$((n_agents + 1))
done

# Utilities
n_utils=0
for u in check-update.sh context-cleanup.sh health-check.sh; do
    check_pair "${INST}/cognitive-core/${u}" "${ROOT_DIR}/core/utilities/${u}" same
    n_utils=$((n_utils + 1))
done

# Skills: every selected skill is installed, and every framework file of
# every installed skill (core or pack) matches
CC_SKILLS="$(sed -n 's/^CC_SKILLS="\(.*\)"$/\1/p' "${ROOT_DIR}/cognitive-core.conf")"
n_selected=0
for s in $CC_SKILLS; do
    n_selected=$((n_selected + 1))
    [ -d "${INST}/skills/${s}" ] || note "missing skill: .claude/skills/${s}"
done

# Skills of the selected language and database packs are installed too
for pack in "language-packs/$(sed -n 's/^CC_LANGUAGE="\(.*\)"$/\1/p' "${ROOT_DIR}/cognitive-core.conf")" \
            "database-packs/$(sed -n 's/^CC_DATABASE="\(.*\)"$/\1/p' "${ROOT_DIR}/cognitive-core.conf")"; do
    for d in "${ROOT_DIR}/${pack}"/skills/*/; do
        [ -d "$d" ] || continue
        [ -d "${INST}/skills/$(basename "$d")" ] || note "missing pack skill: .claude/skills/$(basename "$d")"
    done
done

n_skill_files=0
for d in "${INST}"/skills/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    src_dir=""
    for c in "${ROOT_DIR}/core/skills/${name}" "${ROOT_DIR}"/language-packs/*/skills/"${name}" "${ROOT_DIR}"/database-packs/*/skills/"${name}"; do
        if [ -d "$c" ]; then src_dir="$c"; break; fi
    done
    [ -n "$src_dir" ] || continue
    while IFS= read -r rel; do
        check_pair "${d}${rel}" "${src_dir}/${rel}" same
        n_skill_files=$((n_skill_files + 1))
    done < <(cd "$src_dir" && find . -name '.*' ! -name . -prune -o -type f -print | sed 's|^\./||')
done

# Excluded hooks must still exist, so the list cannot go stale
for h in $EXCLUDE_HOOKS; do
    [ -f "${ROOT_DIR}/core/hooks/${h}" ] || note "stale EXCLUDE_HOOKS entry: ${h}"
done

# Coverage guard: an empty category means the iteration itself broke
if [ "$e_hooks" -gt 0 ] && [ "$e_agents" -gt 0 ] && [ "$n_selected" -gt 0 ] && [ "$n_skill_files" -gt "$n_selected" ]; then
    _pass "parity covered ${n_hooks} hooks, ${n_agents} agents, ${n_selected} skills (${n_skill_files} files), ${n_utils} utilities"
else
    _fail "parity coverage" "hooks=${e_hooks} agents=${e_agents} skills=${n_selected} skill files=${n_skill_files}"
fi

if [ -z "$differ" ]; then
    _pass "self-install matches core/"
else
    _fail "self-install matches core/ (cp core/<path> .claude/<path>)" "${differ}"
fi

suite_end
