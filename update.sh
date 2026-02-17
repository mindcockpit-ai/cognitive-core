#!/bin/bash
# =============================================================================
# cognitive-core update.sh — Checksum-based updater
# Safely updates framework files while preserving user modifications.
#
# Usage:
#   ./update.sh [project-dir]
#   ./update.sh /path/to/myproject
# =============================================================================
set -euo pipefail

# ---- Constants ----
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

info()  { printf "${GREEN}[+]${RESET} %s\n" "$*"; }
warn()  { printf "${YELLOW}[!]${RESET} %s\n" "$*"; }
err()   { printf "${RED}[x]${RESET} %s\n" "$*" >&2; }
header(){ printf "\n${BOLD}${CYAN}=== %s ===${RESET}\n" "$*"; }

# ---- Resolve project directory ----
PROJECT_DIR="${1:-$(pwd)}"
PROJECT_DIR="$(cd "$PROJECT_DIR" 2>/dev/null && pwd)" || {
    err "Directory does not exist: $PROJECT_DIR"
    exit 1
}

CLAUDE_DIR="${PROJECT_DIR}/.claude"
VERSION_FILE="${CLAUDE_DIR}/cognitive-core/version.json"

header "cognitive-core updater"
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

# Use the script's own directory as the framework source (may have been updated via git pull)
FRAMEWORK_DIR="$SCRIPT_DIR"
if [ ! -d "${FRAMEWORK_DIR}/core" ]; then
    err "Framework source not found at ${FRAMEWORK_DIR}"
    exit 1
fi

# ---- Compute checksums ----
header "Analyzing installed files"

# Source shared library for _cc_compute_sha256
_LIB_FILE="${FRAMEWORK_DIR}/core/hooks/_lib.sh"
if [ -f "$_LIB_FILE" ]; then
    # shellcheck disable=SC2034
    CC_PROJECT_DIR="$PROJECT_DIR"
    # shellcheck disable=SC1090
    source "$_LIB_FILE"
fi

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

    # Determine the framework source file
    local framework_file=""
    case "$rel_path" in
        .claude/hooks/*)
            local basename="${rel_path##*/}"
            framework_file="${FRAMEWORK_DIR}/core/hooks/${basename}"
            ;;
        .claude/agents/*)
            local basename="${rel_path##*/}"
            framework_file="${FRAMEWORK_DIR}/core/agents/${basename}"
            ;;
        .claude/skills/*)
            local skill_rel="${rel_path#.claude/skills/}"
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
        .claude/settings.json)
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

# Load config to know which components are installed
CONF_FILE="${PROJECT_DIR}/cognitive-core.conf"
CONF_ALT="${PROJECT_DIR}/.claude/cognitive-core.conf"
if [ -f "$CONF_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONF_FILE"
elif [ -f "$CONF_ALT" ]; then
    # shellcheck disable=SC1090
    source "$CONF_ALT"
fi

check_new_files() {
    local src_dir="$1" dest_dir="$2" label="$3"
    if [ ! -d "$src_dir" ]; then
        return
    fi
    find "$src_dir" -type f | while read -r src_file; do
        local rel="${src_file#${src_dir}/}"
        local dest="${dest_dir}/${rel}"
        if [ ! -f "$dest" ]; then
            mkdir -p "$(dirname "$dest")"
            cp "$src_file" "$dest"
            info "  NEW (${label}): ${rel}"
            # Can't increment in subshell, track via temp file
            echo "1" >> /tmp/cc_update_new_$$
        fi
    done
}

rm -f /tmp/cc_update_new_$$

# Check hooks for new files
for hook in ${CC_HOOKS:-}; do
    src="${FRAMEWORK_DIR}/core/hooks/${hook}.sh"
    dest="${CLAUDE_DIR}/hooks/${hook}.sh"
    if [ -f "$src" ] && [ ! -f "$dest" ]; then
        cp "$src" "$dest"
        chmod +x "$dest"
        info "  NEW (hook): ${hook}.sh"
        echo "1" >> /tmp/cc_update_new_$$
    fi
done

# Check for updated utilities
for util_name in check-update.sh context-cleanup.sh health-check.sh; do
    UTIL_SRC="${FRAMEWORK_DIR}/core/utilities/${util_name}"
    UTIL_DEST="${CLAUDE_DIR}/cognitive-core/${util_name}"
    if [ -f "$UTIL_SRC" ]; then
        if [ ! -f "$UTIL_DEST" ]; then
            cp "$UTIL_SRC" "$UTIL_DEST"
            chmod +x "$UTIL_DEST"
            info "  NEW (utility): ${util_name}"
            echo "1" >> /tmp/cc_update_new_$$
        else
            local_sha=$(compute_sha256 "$UTIL_DEST")
            source_sha=$(compute_sha256 "$UTIL_SRC")
            if [ "$local_sha" != "$source_sha" ]; then
                cp "$UTIL_SRC" "$UTIL_DEST"
                chmod +x "$UTIL_DEST"
                info "  UPDATED (utility): ${util_name}"
                echo "1" >> /tmp/cc_update_new_$$
            fi
        fi
    fi
done

# Count new files
if [ -f /tmp/cc_update_new_$$ ]; then
    NEW_FILES=$(wc -l < /tmp/cc_update_new_$$ | tr -d ' ')
    rm -f /tmp/cc_update_new_$$
fi

# ---- Update version manifest ----
header "Updating version manifest"

# Regenerate file checksums
INSTALLED_FILES="[]"
if command -v python3 &>/dev/null; then
    INSTALLED_FILES=$(find "${CLAUDE_DIR}" -type f -not -path "*/cognitive-core/*" | sort | python3 -c "
import sys, json, hashlib, os
files = []
project = '${PROJECT_DIR}'
for line in sys.stdin:
    path = line.strip()
    if not path:
        continue
    rel = os.path.relpath(path, project)
    try:
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

# Determine framework version from install.sh
FRAMEWORK_VERSION=$(grep -m1 'CC_VERSION=' "${FRAMEWORK_DIR}/install.sh" 2>/dev/null | sed 's/.*CC_VERSION="//;s/".*//' || echo "$CURRENT_VERSION")

cat > "$VERSION_FILE" << VEOF
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
info "Updated version manifest."

# ---- Make scripts executable ----
find "${CLAUDE_DIR}/hooks" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

# ---- Summary ----
header "Update complete"

echo ""
printf "${BOLD}Results:${RESET}\n"
printf "  Updated:   %d file(s)\n" "$UPDATED"
printf "  New:       %d file(s)\n" "$NEW_FILES"
printf "  Unchanged: %d file(s)\n" "$UNCHANGED"
printf "  Skipped:   %d file(s) (user-modified or unresolvable)\n" "$SKIPPED"
echo ""

if [ "$SKIPPED" -gt 0 ]; then
    warn "Some files were skipped because you modified them."
    warn "Review manually and merge framework changes as needed."
    echo ""
fi

if [ "$UPDATED" -gt 0 ] || [ "$NEW_FILES" -gt 0 ]; then
    info "Commit the updates:"
    printf "  ${CYAN}git add .claude/ && git commit -m \"chore: update cognitive-core to v${FRAMEWORK_VERSION}\"${RESET}\n"
else
    info "Everything is up to date. No changes needed."
fi
echo ""
