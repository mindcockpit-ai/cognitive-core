#!/bin/bash
# SPDX-License-Identifier: FSL-1.1-ALv2
# =============================================================================
# cognitive-core update.sh - Checksum-based updater
# Safely updates framework files while preserving user modifications.
#
# Usage:
#   ./update.sh [--prune] [--dry-run] [project-dir]
#   ./update.sh /path/to/myproject
#   ./update.sh --prune --dry-run /path/to/myproject
#
# Options:
#   --prune     Remove installed agents, skills and hooks not selected in
#               cognitive-core.conf (CC_AGENTS, CC_SKILLS, CC_HOOKS)
#   --dry-run   With --prune: list what would be removed, change nothing
#
# Files listed in CC_LOCAL_OVERRIDES are project owned: never overwritten,
# never pruned.
# =============================================================================
set -euo pipefail

# ---- Constants ----
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---- Branding (colors, banners, status helpers) ----
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/core/brand.sh"

# Legacy aliases - existing code uses short names and direct color vars
BOLD="${_CC_BOLD}" CYAN="${_CC_CYAN}" RESET="${_CC_RESET}"
info()  { _cc_info "$@"; }
warn()  { _cc_warn "$@"; }
err()   { _cc_err "$@"; }
header(){ _cc_header "$@"; }

# ---- Parse arguments ----
PRUNE=false
DRY_RUN=false
PROJECT_ARG=""
for arg in "$@"; do
    case "$arg" in
        --prune)   PRUNE=true ;;
        --dry-run) DRY_RUN=true ;;
        -*)
            err "Unknown option: ${arg}"
            err "Usage: update.sh [--prune] [--dry-run] [project-dir]"
            exit 1
            ;;
        *) PROJECT_ARG="$arg" ;;
    esac
done
if [ "$DRY_RUN" = true ] && [ "$PRUNE" = false ]; then
    err "--dry-run requires --prune"
    exit 1
fi

# ---- Resolve project directory ----
PROJECT_DIR="${PROJECT_ARG:-$(pwd)}"
PROJECT_DIR="$(cd "$PROJECT_DIR" 2>/dev/null && pwd)" || {
    err "Directory does not exist: $PROJECT_DIR"
    exit 1
}

# ---- Resolve platform adapter (install dir, prune support) ----
# Peek at CC_PLATFORM the same way install.sh does, before the conf is sourced.
CC_PLATFORM=""
for _conf in "${PROJECT_DIR}/cognitive-core.conf" "${PROJECT_DIR}/.claude/cognitive-core.conf"; do
    if [ -f "$_conf" ]; then
        CC_PLATFORM=$(grep -E '^CC_PLATFORM=' "$_conf" | head -1 | sed 's/CC_PLATFORM=//' | tr -d '"' || true)
        break
    fi
done
CC_PLATFORM="${CC_PLATFORM:-claude}"
case "$CC_PLATFORM" in
    *[!a-z0-9-]*) err "Invalid CC_PLATFORM: ${CC_PLATFORM}"; exit 1 ;;
esac
ADAPTER_DIR="${SCRIPT_DIR}/adapters/${CC_PLATFORM}"
if [ ! -f "${ADAPTER_DIR}/adapter.sh" ]; then
    err "Unknown platform: ${CC_PLATFORM} (no adapter at ${ADAPTER_DIR})"
    exit 1
fi
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/adapters/_adapter-lib.sh"
# shellcheck disable=SC1090
source "${ADAPTER_DIR}/adapter.sh"
_adapter_resolve_install_dir "$PROJECT_DIR"
INSTALL_REL="$_ADAPTER_INSTALL_DIR"
VERSION_FILE="${CC_INSTALL_DIR}/cognitive-core/version.json"

_cc_banner_compact
info "Project: ${PROJECT_DIR}"

# ---- Read current version manifest ----
if [ ! -f "$VERSION_FILE" ]; then
    err "No version.json found at ${VERSION_FILE}"
    err "Run install.sh first to set up cognitive-core."
    exit 1
fi

CURRENT_VERSION=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$VERSION_FILE" | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"//;s/"//')
SOURCE_DIR=$(grep -o '"source"[[:space:]]*:[[:space:]]*"[^"]*"' "$VERSION_FILE" | head -1 | sed 's/.*"source"[[:space:]]*:[[:space:]]*"//;s/"//')
info "Installed version: ${CURRENT_VERSION}"
info "Source: ${SOURCE_DIR}"

# ---- Project config ----
CONF_FILE="${PROJECT_DIR}/cognitive-core.conf"
CONF_ALT="${PROJECT_DIR}/.claude/cognitive-core.conf"

# Migration: fix unescaped $1 in command variables (pre-1.6.0 installs)
# Without this, sourcing the conf under set -u fails with "unbound variable"
_cc_fix_unescaped_dollar() {
    local f="$1"
    if grep -qE '^CC_(LINT|TEST|FORMAT)_COMMAND="[^"]*[^\\]\$[0-9]' "$f" 2>/dev/null; then
        if [ "$DRY_RUN" = true ]; then
            err "$(basename "$f") needs a one-time migration (unescaped \$N)."
            err "Run update.sh once without --dry-run first."
            exit 1
        fi
        sed -i.bak -E 's/^(CC_(LINT|TEST|FORMAT)_COMMAND="[^"]*[^\\])\$([0-9])/\1\\$\3/g' "$f"
        rm -f "${f}.bak"
        info "Migrated: escaped \$N in command variables in $(basename "$f")"
    fi
}

_UPDATE_LIB="${SCRIPT_DIR}/core/hooks/_lib.sh"
if [ ! -f "$_UPDATE_LIB" ]; then
    err "Framework library not found: ${_UPDATE_LIB}"
    exit 1
fi
# Export CC_PROJECT_DIR BEFORE sourcing so _cc_security_log writes to the
# project's security.log. Pre-command assignment (`VAR=x source`) does not
# reliably survive under set -u.
export CC_PROJECT_DIR="$PROJECT_DIR"
# shellcheck disable=SC1090
source "$_UPDATE_LIB"
# _lib.sh derives CC_PROJECT_DIR from its own location (the framework),
# so point it back at the target project.
CC_PROJECT_DIR="$PROJECT_DIR"

# Load the target project's conf. Only the project conf counts: no user
# defaults fallback, and selection lists and overrides are never inherited
# from the environment (#328). Called again after the branch guard switches.
CONF_LOADED=""
load_project_conf() {
    local conf=""
    if [ -f "$CONF_FILE" ]; then
        conf="$CONF_FILE"
    elif [ -f "$CONF_ALT" ]; then
        conf="$CONF_ALT"
    fi
    unset CC_LOCAL_OVERRIDES CC_AGENTS CC_SKILLS CC_HOOKS
    CONF_LOADED=""
    [ -n "$conf" ] || return 0
    _cc_fix_unescaped_dollar "$conf"
    # shellcheck disable=SC1090
    source "$conf"
    CONF_LOADED="$conf"
    # The conf must not redirect the install dir, directly or through the
    # adapter constant
    _ADAPTER_INSTALL_DIR="$INSTALL_REL"
    _adapter_resolve_install_dir "$PROJECT_DIR"
}
load_project_conf

# Validate the manifest-declared SOURCE_DIR before trusting it for display or
# any later use (#256). Attack scenario: malicious manifest with
# {"source": "/tmp/evil"} could redirect downstream consumers. update.sh itself
# uses SCRIPT_DIR as the real framework root, but we validate here
# so the guard applies uniformly and any deny is logged with full context.
# Use SCRIPT_DIR as the anchor when CC_FRAMEWORK_ROOT is unset - this script
# itself is running from the framework source, so SCRIPT_DIR is authoritative.
export CC_FRAMEWORK_ROOT="${CC_FRAMEWORK_ROOT:-$SCRIPT_DIR}"
if ! _cc_validate_framework_source "$SOURCE_DIR" 2>/dev/null; then
    err "Refused to trust manifest-declared source: ${SOURCE_DIR}"
    err "Check ${CC_INSTALL_DIR}/cognitive-core/security.log for details."
    err "update.sh will use its own location (${SCRIPT_DIR}) instead."
fi

# Use the script's own directory as the framework source (may have been updated via git pull)
FRAMEWORK_DIR="$SCRIPT_DIR"
if [ ! -d "${FRAMEWORK_DIR}/core" ]; then
    err "Framework source not found at ${FRAMEWORK_DIR}"
    exit 1
fi

# ---- Prune: installed components no longer selected (#328) ----
# Candidates must have a framework source in core/. Never pruned: local
# components, CC_LOCAL_OVERRIDES, _-prefixed hook libraries, language and
# database pack skills, and hooks the adapter still has wired
# (_adapter_hook_is_wired, e.g. .claude/settings.json).
PRUNE_LIST=""   # space separated paths relative to the install dir
PRUNE_WIRED=""  # unselected hooks the adapter still has wired

_cc_word_in() {
    case " $2 " in *" $1 "*) return 0 ;; esac
    return 1
}

PRUNE_MODIFIED="" # unselected components changed since install
MANIFEST_INDEX="" # "path sha256" lines from version.json

# Refuse to prune on an incomplete selection or through symlinks: a missing
# list would select nothing and remove everything.
prune_preflight() {
    local d
    if [ -z "$CONF_LOADED" ]; then
        err "Refusing to prune: no cognitive-core.conf in ${PROJECT_DIR}"
        exit 1
    fi
    if [ -z "${CC_AGENTS+x}" ] || [ -z "${CC_SKILLS+x}" ] || [ -z "${CC_HOOKS+x}" ]; then
        err "Refusing to prune: CC_AGENTS, CC_SKILLS and CC_HOOKS must all be set in ${CONF_LOADED}"
        exit 1
    fi
    for d in "$CC_INSTALL_DIR" "${CC_INSTALL_DIR}/agents" "${CC_INSTALL_DIR}/skills" "${CC_INSTALL_DIR}/hooks"; do
        if [ -L "$d" ]; then
            err "Refusing to prune: ${d} is a symlink"
            exit 1
        fi
    done
    if ! command -v python3 &>/dev/null; then
        err "Refusing to prune: python3 is required to read the version manifest"
        exit 1
    fi
    MANIFEST_INDEX=$(python3 -c '
import json, sys
with open(sys.argv[1]) as f:
    for entry in json.load(f).get("files", []):
        print(entry.get("path", ""), entry.get("sha256", ""))
' "$VERSION_FILE")
}

# True if any file of an installed component differs from its manifest
# checksum or is unknown to the manifest (added by the user).
_cc_component_modified() {
    local f recorded
    while IFS= read -r f; do
        recorded=$(awk -v p="${f#"${PROJECT_DIR}"/}" '$1 == p { print $2; exit }' <<< "$MANIFEST_INDEX")
        if [ -z "$recorded" ] || [ "$recorded" != "$(_cc_compute_sha256 "$f")" ]; then
            return 0
        fi
    done < <(find "${CC_INSTALL_DIR}/${1%/}" -type f)
    return 1
}

_cc_is_pack_skill() {
    local d
    for d in "${FRAMEWORK_DIR}/language-packs/"*/skills/"$1" "${FRAMEWORK_DIR}/database-packs/"*/skills/"$1"; do
        [ -d "$d" ] && return 0
    done
    return 1
}

collect_prune_candidates() {
    local f name a selected_agents=""
    for a in ${CC_AGENTS:-}; do
        selected_agents="${selected_agents} $(agent_file_for "$a")"
    done
    for f in "${CC_INSTALL_DIR}/agents/"*.md; do
        [ -f "$f" ] || continue
        name="${f##*/}"
        [ -f "${FRAMEWORK_DIR}/core/agents/${name}" ] || continue
        _cc_word_in "$name" "$selected_agents" && continue
        _cc_is_local_override "agents/${name}" && continue
        if _cc_component_modified "agents/${name}"; then
            PRUNE_MODIFIED="${PRUNE_MODIFIED} agents/${name}"
            continue
        fi
        PRUNE_LIST="${PRUNE_LIST} agents/${name}"
    done
    for f in "${CC_INSTALL_DIR}/skills/"*/; do
        [ -d "$f" ] || continue
        name="$(basename "$f")"
        [ -d "${FRAMEWORK_DIR}/core/skills/${name}" ] || continue
        _cc_word_in "$name" "${CC_SKILLS:-}" && continue
        _cc_is_pack_skill "$name" && continue
        _cc_has_local_override_under "skills/${name}/" && continue
        if _cc_component_modified "skills/${name}/"; then
            PRUNE_MODIFIED="${PRUNE_MODIFIED} skills/${name}/"
            continue
        fi
        PRUNE_LIST="${PRUNE_LIST} skills/${name}/"
    done
    for f in "${CC_INSTALL_DIR}/hooks/"*.sh; do
        [ -f "$f" ] || continue
        name="${f##*/}"
        case "$name" in _*) continue ;; esac
        [ -f "${FRAMEWORK_DIR}/core/hooks/${name}" ] || continue
        _cc_word_in "${name%.sh}" "${CC_HOOKS:-}" && continue
        _cc_is_local_override "hooks/${name}" "$f" && continue
        if _adapter_hook_is_wired "$PROJECT_DIR" "$name"; then
            PRUNE_WIRED="${PRUNE_WIRED} hooks/${name}"
            continue
        fi
        if _cc_component_modified "hooks/${name}"; then
            PRUNE_MODIFIED="${PRUNE_MODIFIED} hooks/${name}"
            continue
        fi
        PRUNE_LIST="${PRUNE_LIST} hooks/${name}"
    done
}

report_kept_components() {
    local rel
    for rel in $PRUNE_WIRED; do
        warn "  KEPT (still wired): ${rel}"
        warn "    Unwire it from the ${_ADAPTER_NAME} settings first, then re-run --prune."
    done
    for rel in $PRUNE_MODIFIED; do
        warn "  KEPT (modified since install): ${rel}"
        warn "    List it in CC_LOCAL_OVERRIDES to keep it, or remove it by hand."
    done
}

# Dry run: plan against the current tree and exit before the branch guard
if [ "$DRY_RUN" = true ]; then
    prune_preflight
    collect_prune_candidates
    header "Prune dry run (nothing is changed)"
    _dry_branch=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || true)
    if [ "${CC_SYNC_ENFORCE:-true}" = "true" ] && git -C "$PROJECT_DIR" remote get-url origin &>/dev/null; then
        case "$_dry_branch" in
            main|develop|master|"${CC_SYNC_BRANCH:-chore/cognitive-core-sync}"|"") ;;
            *)
                warn "Planned on feature branch ${_dry_branch}. A real --prune switches to"
                warn "${CC_SYNC_BRANCH:-chore/cognitive-core-sync} first and plans against that branch's conf."
                ;;
        esac
    fi
    if [ -z "$PRUNE_LIST" ]; then
        info "Nothing to prune."
    fi
    for rel in $PRUNE_LIST; do
        info "  WOULD REMOVE: ${rel}"
    done
    report_kept_components
    exit 0
fi

# ---- Branch guard: prevent PR contamination (#199) ----
# If the target project is a connected git repo on a feature branch,
# auto-switch to a dedicated sync branch to keep updates out of feature PRs.
_CC_SYNC_BRANCH="${CC_SYNC_BRANCH:-chore/cognitive-core-sync}"
_CC_SYNC_ENFORCE="${CC_SYNC_ENFORCE:-true}"
_CC_ORIGINAL_BRANCH=""

if [ "$_CC_SYNC_ENFORCE" = "true" ] && git -C "$PROJECT_DIR" rev-parse --git-dir &>/dev/null; then
    # Git repo detected - check if it has a remote (connected vs local-only)
    if git -C "$PROJECT_DIR" remote get-url origin &>/dev/null; then
        _CC_CURRENT_BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || true)
        # Allow updates on: main, develop, master, the sync branch itself
        case "$_CC_CURRENT_BRANCH" in
            main|develop|master|"$_CC_SYNC_BRANCH") ;;
            *)
                info "Feature branch detected: ${_CC_CURRENT_BRANCH}"
                info "Switching to ${_CC_SYNC_BRANCH} to prevent PR contamination"
                _CC_ORIGINAL_BRANCH="$_CC_CURRENT_BRANCH"
                git -C "$PROJECT_DIR" stash push -m "cognitive-core: stash before sync" --quiet 2>/dev/null || true
                _CC_SYNC_BASE="${CC_SYNC_BASE:-$(git -C "$PROJECT_DIR" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo main)}"
                if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/${_CC_SYNC_BRANCH}" 2>/dev/null; then
                    git -C "$PROJECT_DIR" checkout "$_CC_SYNC_BRANCH" --quiet
                else
                    git -C "$PROJECT_DIR" checkout -b "$_CC_SYNC_BRANCH" "origin/${_CC_SYNC_BASE}" --quiet 2>/dev/null \
                        || git -C "$PROJECT_DIR" checkout -b "$_CC_SYNC_BRANCH" --quiet
                fi
                info "Now on: ${_CC_SYNC_BRANCH}"
                # Selection and overrides must come from the branch being updated
                load_project_conf
                ;;
        esac
    fi
fi

# Plan the prune before any file is updated, so manifest checksums still
# describe the installed state (#328)
if [ "$PRUNE" = true ]; then
    prune_preflight
    collect_prune_candidates
fi

# ---- Compute checksums ----
header "Analyzing installed files"

compute_sha256() {
    if type _cc_compute_sha256 &>/dev/null; then
        _cc_compute_sha256 "$1"
    else
        # Inline fallback if _lib.sh unavailable
        local file="$1"
        if command -v sha256sum &>/dev/null; then
            sha256sum "$file" | awk '{print $1}'
        elif command -v shasum &>/dev/null; then
            shasum -a 256 "$file" | awk '{print $1}'
        else
            openssl dgst -sha256 "$file" | awk '{print $NF}'
        fi
    fi
}

UPDATED=0
SKIPPED=0
NEW_FILES=0
UNCHANGED=0
OVERRIDES=0
PRUNED=0
# Preserved files keep their previous manifest checksum, so a later update
# still sees them as modified (newline separated paths relative to project)
PRESERVED_PATHS=""

# ---- Process files from version manifest ----
# Extract file entries from version.json using lightweight parsing
if command -v python3 &>/dev/null; then
    # Use python3 for reliable JSON parsing
    eval "$(python3 -c "
import json, sys
with open('${VERSION_FILE}') as f:
    data = json.load(f)
files = data.get('files', [])
print(f'FILE_COUNT={len(files)}')
for i, entry in enumerate(files):
    path = entry.get('path', '')
    sha = entry.get('sha256', '')
    print(f'MANIFEST_PATH_{i}=\"{path}\"')
    print(f'MANIFEST_SHA_{i}=\"{sha}\"')
")"
else
    warn "python3 not found. Falling back to full re-install comparison."
    FILE_COUNT=0
fi

# ---- Compare and update each tracked file ----
header "Comparing files"

process_file() {
    local rel_path="$1"
    local original_sha="$2"
    local installed_file="${PROJECT_DIR}/${rel_path}"

    # Project-owned override: never compared, never overwritten (#328)
    local override_rc=0
    _cc_is_local_override "${rel_path#"${INSTALL_REL}/"}" "$installed_file" || override_rc=$?
    if [ "$override_rc" -eq 0 ]; then
        info "  OVERRIDE (project owned): ${rel_path}"
        OVERRIDES=$((OVERRIDES + 1))
        PRESERVED_PATHS="${PRESERVED_PATHS}${rel_path}"$'\n'
        return
    elif [ "$override_rc" -eq 2 ] && [ -f "$installed_file" ]; then
        warn "  OVERRIDE NOT HONOURED: ${rel_path} (security hook needs a matching sha256 pin)"
        warn "    To own the current content: ${rel_path#"${INSTALL_REL}/"}@$(compute_sha256 "$installed_file")"
    fi

    # Determine the framework source file
    local framework_file=""
    case "$rel_path" in
        "${INSTALL_REL}"/hooks/*)
            local basename="${rel_path##*/}"
            framework_file="${FRAMEWORK_DIR}/core/hooks/${basename}"
            ;;
        "${INSTALL_REL}"/agents/*)
            local basename="${rel_path##*/}"
            framework_file="${FRAMEWORK_DIR}/core/agents/${basename}"
            ;;
        "${INSTALL_REL}"/skills/*)
            local skill_rel="${rel_path#"${INSTALL_REL}"/skills/}"
            framework_file="${FRAMEWORK_DIR}/core/skills/${skill_rel}"
            # Also check language packs and database packs
            if [ ! -f "$framework_file" ]; then
                for pack_dir in "${FRAMEWORK_DIR}/language-packs/"*/skills "${FRAMEWORK_DIR}/database-packs/"*/skills; do
                    local candidate="${pack_dir}/${skill_rel}"
                    if [ -f "$candidate" ]; then
                        framework_file="$candidate"
                        break
                    fi
                done
            fi
            ;;
        "${INSTALL_REL}"/settings.json)
            # settings.json is always user-managed after initial generation
            info "  SKIP (user-managed): ${rel_path}"
            SKIPPED=$((SKIPPED + 1))
            return
            ;;
        *)
            # Unknown file type, skip
            SKIPPED=$((SKIPPED + 1))
            return
            ;;
    esac

    # If installed file no longer exists, skip
    if [ ! -f "$installed_file" ]; then
        warn "  MISSING: ${rel_path} (was tracked but file is gone)"
        SKIPPED=$((SKIPPED + 1))
        return
    fi

    # If framework source does not exist, skip
    if [ -z "$framework_file" ] || [ ! -f "$framework_file" ]; then
        info "  SKIP (no framework source): ${rel_path}"
        SKIPPED=$((SKIPPED + 1))
        return
    fi

    # Compute current checksum of installed file
    local current_sha
    current_sha=$(compute_sha256 "$installed_file")

    # Compute checksum of latest framework file
    local latest_sha
    latest_sha=$(compute_sha256 "$framework_file")

    if [ "$current_sha" = "$latest_sha" ]; then
        # Already up to date
        UNCHANGED=$((UNCHANGED + 1))
        return
    fi

    if [ "$current_sha" = "$original_sha" ]; then
        # File is unmodified from original install -- safe to update
        cp "$framework_file" "$installed_file"
        info "  UPDATED: ${rel_path}"
        UPDATED=$((UPDATED + 1))
    else
        # User has modified this file -- do NOT overwrite
        warn "  MODIFIED (preserved): ${rel_path}"
        warn "    Your changes differ from both the original and latest framework."
        warn "    Review manually: diff ${installed_file} ${framework_file}"
        SKIPPED=$((SKIPPED + 1))
        PRESERVED_PATHS="${PRESERVED_PATHS}${rel_path}"$'\n'
    fi
}

for ((i=0; i<FILE_COUNT; i++)); do
    eval "rel_path=\${MANIFEST_PATH_${i}}"
    eval "orig_sha=\${MANIFEST_SHA_${i}}"
    # shellcheck disable=SC2154
    process_file "$rel_path" "$orig_sha"
done

# ---- Check for new framework files not in manifest ----
header "Checking for new framework files"

# Check hooks for new files
for hook in ${CC_HOOKS:-}; do
    src="${FRAMEWORK_DIR}/core/hooks/${hook}.sh"
    dest="${CC_INSTALL_DIR}/hooks/${hook}.sh"
    _cc_is_local_override "hooks/${hook}.sh" && continue
    if [ -f "$src" ] && [ ! -f "$dest" ]; then
        cp "$src" "$dest"
        chmod +x "$dest"
        info "  NEW (hook): ${hook}.sh"
        NEW_FILES=$((NEW_FILES + 1))
    fi
done

# Check for updated utilities
for util_name in check-update.sh context-cleanup.sh health-check.sh; do
    UTIL_SRC="${FRAMEWORK_DIR}/core/utilities/${util_name}"
    UTIL_DEST="${CC_INSTALL_DIR}/cognitive-core/${util_name}"
    if [ -f "$UTIL_SRC" ]; then
        if [ ! -f "$UTIL_DEST" ]; then
            cp "$UTIL_SRC" "$UTIL_DEST"
            chmod +x "$UTIL_DEST"
            info "  NEW (utility): ${util_name}"
            NEW_FILES=$((NEW_FILES + 1))
        else
            local_sha=$(compute_sha256 "$UTIL_DEST")
            source_sha=$(compute_sha256 "$UTIL_SRC")
            if [ "$local_sha" != "$source_sha" ]; then
                cp "$UTIL_SRC" "$UTIL_DEST"
                chmod +x "$UTIL_DEST"
                info "  UPDATED (utility): ${util_name}"
                NEW_FILES=$((NEW_FILES + 1))
            fi
        fi
    fi
done


# ---- Prune unselected components (#328) ----
if [ "$PRUNE" = true ]; then
    header "Pruning unselected components"
    for rel in $PRUNE_LIST; do
        rm -rf "${CC_INSTALL_DIR:?}/${rel%/}"
        info "  REMOVED: ${rel}"
        PRUNED=$((PRUNED + 1))
    done
    [ -n "$PRUNE_LIST" ] || info "Nothing to prune."
    report_kept_components
    if [ -n "$PRUNE_LIST" ]; then
        # shellcheck disable=SC2086
        _adapter_post_prune "$PROJECT_DIR" $PRUNE_LIST
    fi
fi

# ---- Update version manifest ----
header "Updating version manifest"

# Regenerate file checksums
INSTALLED_FILES="[]"
if command -v python3 &>/dev/null; then
    INSTALLED_FILES=$(find "${CC_INSTALL_DIR}" -type f -not -path "${CC_INSTALL_DIR}/cognitive-core/*" | sort \
        | CC_PRESERVED_PATHS="$PRESERVED_PATHS" CC_VERSION_FILE="$VERSION_FILE" python3 -c "
import sys, json, hashlib, os
files = []
project = '${PROJECT_DIR}'
preserved = set(p for p in os.environ.get('CC_PRESERVED_PATHS', '').splitlines() if p)
# An unreadable manifest must fail the update, not silently reset the
# baselines of preserved files
try:
    with open(os.environ['CC_VERSION_FILE']) as f:
        previous = {e.get('path'): e.get('sha256') for e in json.load(f).get('files', [])}
except FileNotFoundError:
    previous = {}
for line in sys.stdin:
    path = line.strip()
    if not path:
        continue
    rel = os.path.relpath(path, project)
    try:
        if rel in preserved and previous.get(rel):
            sha = previous[rel]
        else:
            with open(path, 'rb') as f:
                sha = hashlib.sha256(f.read()).hexdigest()
        files.append({'path': rel, 'sha256': sha})
    except:
        pass
print(json.dumps(files, indent=4))
")
fi

# Read original manifest values for preservation
ORIG_INSTALLED=$(grep -o '"installed_at"[[:space:]]*:[[:space:]]*"[^"]*"' "$VERSION_FILE" | head -1 | sed 's/.*"installed_at"[[:space:]]*:[[:space:]]*"//;s/"//')

# Determine framework version from version.txt (preferred) or install.sh fallback
if [ -f "${FRAMEWORK_DIR}/version.txt" ]; then
    FRAMEWORK_VERSION=$(tr -d '[:space:]' < "${FRAMEWORK_DIR}/version.txt")
else
    FRAMEWORK_VERSION="$CURRENT_VERSION"
fi

cat > "${VERSION_FILE}.tmp" << VEOF
{
    "version": "${FRAMEWORK_VERSION}",
    "installed_at": "${ORIG_INSTALLED}",
    "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "project": "${CC_PROJECT_NAME:-unknown}",
    "language": "${CC_LANGUAGE:-unknown}",
    "database": "${CC_DATABASE:-none}",
    "architecture": "${CC_ARCHITECTURE:-none}",
    "agents": "${CC_AGENTS:-}",
    "skills": "${CC_SKILLS:-}",
    "hooks": "${CC_HOOKS:-}",
    "cicd": ${CC_ENABLE_CICD:-false},
    "monitoring": ${CC_MONITORING:-false},
    "source": "${FRAMEWORK_DIR}",
    "files": ${INSTALLED_FILES}
}
VEOF
mv "${VERSION_FILE}.tmp" "$VERSION_FILE"
info "Updated version manifest."

# ---- Make scripts executable ----
find "${CC_INSTALL_DIR}/hooks" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

# ---- Adapter-specific cleanup ----
# Remove orphaned .claude/commands/ stubs that cause duplicate skill entries (#147).
# Claude Code auto-discovers skills from SKILL.md frontmatter; command stubs are redundant.
if [ -d "${CC_INSTALL_DIR}/commands" ]; then
    ORPHANS_REMOVED=0
    for stub in "${CC_INSTALL_DIR}/commands/"*.md; do
        [ -f "$stub" ] || continue
        stub_name="$(basename "$stub" .md)"
        # Only remove if a matching skill exists (avoid removing user-created commands)
        if [ -d "${CC_INSTALL_DIR}/skills/${stub_name}" ]; then
            rm -f "$stub"
            info "  CLEANUP: removed orphaned command stub ${stub_name}.md (#147)"
            ORPHANS_REMOVED=$((ORPHANS_REMOVED + 1))
        fi
    done
    # Remove commands/ dir if empty
    rmdir "${CC_INSTALL_DIR}/commands" 2>/dev/null || true
    if [ "$ORPHANS_REMOVED" -gt 0 ]; then
        info "Removed ${ORPHANS_REMOVED} orphaned command stub(s). Restart session to take effect."
    fi
fi

# ---- Ensure .gitignore policy (base + language pack) ----
GITIGNORE="${PROJECT_DIR}/.gitignore"
GITIGNORE_BASE="${FRAMEWORK_DIR}/core/templates/gitignore-base"
GITIGNORE_LANG="${FRAMEWORK_DIR}/language-packs/${CC_LANGUAGE:-none}/gitignore"

merge_gitignore_rules() {
    local template="$1" section_label="$2" target="${3:-$GITIGNORE}"
    [ -f "$template" ] || return 0
    local added=0
    local tmpfile
    tmpfile=$(mktemp)
    local section_marker="# ---- ${section_label} (cognitive-core) ----"
    if ! grep -qF "$section_marker" "$target" 2>/dev/null; then
        printf "\n%s\n" "$section_marker" > "$tmpfile"
    else
        printf "" > "$tmpfile"
    fi
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
            echo "$line" >> "$tmpfile"
            continue
        fi
        if ! grep -qxF "$line" "$target" 2>/dev/null; then
            echo "$line" >> "$tmpfile"
            added=$((added + 1))
        fi
    done < "$template"
    if [ "$added" -gt 0 ]; then
        cat "$tmpfile" >> "$target"
        info "Added ${added} rules from ${section_label} to .gitignore"
    fi
    rm -f "$tmpfile"
}

[ -f "$GITIGNORE" ] || touch "$GITIGNORE"
merge_gitignore_rules "$GITIGNORE_BASE" "base"
if [ -n "${CC_LANGUAGE:-}" ] && [ "$CC_LANGUAGE" != "none" ] && [ -f "$GITIGNORE_LANG" ]; then
    merge_gitignore_rules "$GITIGNORE_LANG" "${CC_LANGUAGE}"
fi

# ---- Summary ----
header "Update complete"

echo ""
printf "${BOLD}Results:${RESET}\n"
printf "  Updated:   %d file(s)\n" "$UPDATED"
printf "  New:       %d file(s)\n" "$NEW_FILES"
printf "  Unchanged: %d file(s)\n" "$UNCHANGED"
printf "  Override:  %d file(s) (CC_LOCAL_OVERRIDES)\n" "$OVERRIDES"
printf "  Skipped:   %d file(s) (user-modified or unresolvable)\n" "$SKIPPED"
if [ "$PRUNE" = true ]; then
    printf "  Pruned:    %d component(s)\n" "$PRUNED"
fi
echo ""

if [ "$SKIPPED" -gt 0 ]; then
    warn "Some files were skipped because you modified them."
    warn "Review manually and merge framework changes as needed."
    echo ""
fi

if [ "$UPDATED" -gt 0 ] || [ "$NEW_FILES" -gt 0 ] || [ "$PRUNED" -gt 0 ]; then
    info "Commit the updates:"
    printf "  ${CYAN}git add ${INSTALL_REL}/ && git commit -m \"chore: update cognitive-core to v${FRAMEWORK_VERSION}\"${RESET}\n"
    if [ -n "$_CC_ORIGINAL_BRANCH" ]; then
        printf "  ${CYAN}git push -u origin ${_CC_SYNC_BRANCH}${RESET}\n"
        echo ""
        info "Then return to your feature branch:"
        printf "  ${CYAN}git checkout ${_CC_ORIGINAL_BRANCH} && git stash pop${RESET}\n"
    fi
else
    info "Everything is up to date. No changes needed."
    # Restore original branch if we switched and nothing changed
    if [ -n "$_CC_ORIGINAL_BRANCH" ]; then
        info "No updates - switching back to ${_CC_ORIGINAL_BRANCH}"
        git -C "$PROJECT_DIR" checkout "$_CC_ORIGINAL_BRANCH" --quiet 2>/dev/null || true
        git -C "$PROJECT_DIR" stash pop --quiet 2>/dev/null || true
    fi
fi
echo ""
