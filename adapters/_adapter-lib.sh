#!/bin/bash
# cognitive-core adapter library
# Sourced by each adapter's adapter.sh. Provides default implementations
# and the _adapter_validate() contract check.
#
# Usage (in adapter.sh):
#   # _adapter-lib.sh is sourced BEFORE this file by install.sh
#   _ADAPTER_NAME="my-platform"
#   _ADAPTER_INSTALL_DIR=".my-platform"
#   _adapter_install_hook() { ... }
#   ... (implement required functions)

# ---- Default no-op implementations for optional functions ----

_adapter_post_install() {
    # Override in adapter.sh if needed
    :
}

_adapter_install_dir_structure() {
    local project_dir="$1"
    local install_dir="${project_dir}/${_ADAPTER_INSTALL_DIR}"
    mkdir -p "${install_dir}/hooks"
    mkdir -p "${install_dir}/agents"
    mkdir -p "${install_dir}/skills"
    mkdir -p "${install_dir}/cognitive-core"
}

# Is an installed hook still wired into the platform settings? (update.sh --prune)
# Return 0 to keep the hook. Default: platform has no hook wiring.
_adapter_hook_is_wired() {
    # args: <project_dir> <hook_file e.g. validate-bash.sh>
    return 1
}

# Clean up generated files after update.sh --prune removed components.
_adapter_post_prune() {
    # args: <project_dir> <removed paths relative to install dir...>
    :
}

# ---- Helper: drop references to pruned components from a generated file ----
# Removes YAML list items "  - <install_dir>/<path>" and Markdown agent
# references "- **Name**: `<install_dir>/<path>`" (generate_utils.build_agent_refs).
# Symlinked files are left alone.
# Usage: _adapter_prune_list_entries <file> <paths relative to install dir...>
_adapter_prune_list_entries() {
    local file="$1" rc=0 tmp
    shift
    [ -f "$file" ] && [ ! -L "$file" ] && [ "$#" -gt 0 ] || return 0
    tmp=$(mktemp)
    awk -v dir="$_ADAPTER_INSTALL_DIR" -v paths="$*" '
        BEGIN { n = split(paths, p, " ") }
        {
            for (i = 1; i <= n; i++) {
                ref = dir "/" p[i]
                if ($0 == "  - " ref) next
                if (index($0, "- **") == 1 && substr($0, length($0) - length(ref) - 1) == "`" ref "`") next
            }
            print
        }' "$file" > "$tmp" || rc=$?
    if [ "$rc" -eq 0 ] && ! cmp -s "$tmp" "$file"; then
        cat "$tmp" > "$file"
        info "  CLEANUP: removed pruned references from $(basename "$file")"
    elif [ "$rc" -ne 0 ]; then
        warn "  Could not clean $(basename "$file") (awk exit ${rc}), left unchanged"
    fi
    rm -f "$tmp"
}

# ---- Default implementations for install functions ----
# Adapters override these only when platform-specific behavior is needed.

_adapter_install_hook() {
    # _ADAPTER_LIB_DEFAULT_install_hook
    local source_path="$1" hook_name="$2"
    cp "$source_path" "${CC_INSTALL_DIR}/hooks/${hook_name}"
}

_adapter_install_agent() {
    # _ADAPTER_LIB_DEFAULT_install_agent
    local source_path="$1" agent_name="$2"
    cp "$source_path" "${CC_INSTALL_DIR}/agents/${agent_name}"
}

_adapter_install_skill() {
    # _ADAPTER_LIB_DEFAULT_install_skill
    local source_dir="$1" skill_name="$2"
    mkdir -p "${CC_INSTALL_DIR}/skills/${skill_name}"
    cp -R "${source_dir}/"* "${CC_INSTALL_DIR}/skills/${skill_name}/" 2>/dev/null || true
}

_adapter_generate_settings() {
    # _ADAPTER_LIB_DEFAULT_generate_settings
    warn "Adapter '${_ADAPTER_NAME:-unknown}' has no platform-specific settings generator."
}

_adapter_generate_project_readme() {
    # _ADAPTER_LIB_DEFAULT_generate_project_readme
    warn "Adapter '${_ADAPTER_NAME:-unknown}' has no platform-specific readme generator."
}

# ---- Safety rules from shared data file ----

_adapter_common_safety_rules() {
    local rules_file="${SCRIPT_DIR}/adapters/_shared/safety-rules.txt"
    if [ ! -f "$rules_file" ]; then
        echo "(Safety rules file not found -- see cognitive-core/adapters/_shared/safety-rules.txt)"
        return 0
    fi
    local n=0
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        n=$((n + 1))
        printf '%d. %s\n' "$n" "$line"
    done < "$rules_file"
}

# ---- Shared MCP server: copy source files only, never __pycache__ ----
# Returns 1 when the framework has no MCP server, 2 when the copy fails.

_adapter_install_mcp_server() {
    local src="${SCRIPT_DIR}/adapters/_shared/mcp-server"
    local dst="$1"
    [ -d "$src" ] || return 1
    if ! mkdir -p "${dst}/tools" || ! cp "$src/server.py" "${dst}/"; then
        warn "MCP server not installed: copy to ${dst} failed"
        return 2
    fi
    cp "$src/requirements.txt" "${dst}/" 2>/dev/null || true
    cp "$src/TOOLS.md" "${dst}/" 2>/dev/null || true
    cp "$src/tools/"*.py "${dst}/tools/" 2>/dev/null || true
}


# ---- sed escaping helper ----
# Escape a string for safe use as a sed replacement value with | delimiter.
# Handles: | & \ / and newlines. POSIX-compatible (BSD + GNU sed).
_sed_escape_replacement() {
    printf '%s' "$1" | sed -e 's/[|&\\/]/\\&/g'
}

# ---- Contract validation ----

_adapter_validate() {
    local errors=0

    # Check required variables
    if [ -z "${_ADAPTER_NAME:-}" ]; then
        err "Adapter missing required variable: _ADAPTER_NAME"
        errors=$((errors + 1))
    fi

    if [ -z "${_ADAPTER_INSTALL_DIR:-}" ]; then
        err "Adapter missing required variable: _ADAPTER_INSTALL_DIR"
        errors=$((errors + 1))
    fi

    # Check required functions
    local required_fns="_adapter_install_hook _adapter_install_agent _adapter_install_skill _adapter_generate_settings _adapter_generate_project_readme"
    for fn in $required_fns; do
        if ! type "$fn" &>/dev/null; then
            err "Adapter '${_ADAPTER_NAME:-unknown}' missing required function: ${fn}"
            errors=$((errors + 1))
        fi
    done

    if [ "$errors" -gt 0 ]; then
        err "Adapter validation failed with ${errors} error(s)."
        return 1
    fi

    info "Adapter '${_ADAPTER_NAME}' validated (install dir: ${_ADAPTER_INSTALL_DIR})"
    return 0
}

# ---- Helper: resolve CC_INSTALL_DIR ----
# Call after adapter is loaded to set the canonical install directory

_adapter_resolve_install_dir() {
    local project_dir="$1"
    CC_INSTALL_DIR="${project_dir}/${_ADAPTER_INSTALL_DIR}"
    # Backwards compatibility alias
    CLAUDE_DIR="$CC_INSTALL_DIR"
    export CC_INSTALL_DIR CLAUDE_DIR
}

# ---- Agent name mapping ----
# Maps a CC_AGENTS short name to its file in core/agents/.
# Shared by install.sh and update.sh (--prune).

agent_file_for() {
    case "$1" in
        coordinator) echo "project-coordinator.md" ;;
        reviewer)    echo "code-standards-reviewer.md" ;;
        architect)   echo "solution-architect.md" ;;
        tester)      echo "test-specialist.md" ;;
        researcher)  echo "research-analyst.md" ;;
        database)          echo "database-specialist.md" ;;
        security-analyst)       echo "security-analyst.md" ;;
        skill-updater)          echo "skill-updater.md" ;;
        angular-specialist)     echo "angular-specialist.md" ;;
        spring-boot-specialist) echo "spring-boot-specialist.md" ;;
        *) echo "" ;;
    esac
}

# ---- Skill dependencies ----
# A skill names the core skills it needs in its SKILL.md frontmatter:
#   requires-skills: [grounding]
# install.sh and update.sh resolve the selection through these helpers, so a
# required skill is installed, updated, and kept by --prune while a skill that
# needs it is selected, even when CC_SKILLS does not list it.

# Print the requires-skills entries of <SKILL.md>, one per line.
# Only the frontmatter is read; names must be lowercase skill directory names.
_cc_skill_requires() {
    [ -f "$1" ] || return 0
    awk 'NR == 1 && $0 != "---" { exit }
         NR > 1 && $0 == "---" { exit }
         /^requires-skills:/ { sub(/^requires-skills:[[:space:]]*/, ""); gsub(/[][,]/, " "); print }' "$1" \
        | tr -s ' \t' '\n' | grep -E '^[a-z0-9][a-z0-9-]*$' || true
}

# True if the skill at <SKILL.md> supports CC_LANGUAGE (supported-languages
# frontmatter field; a skill without the field supports every language).
_cc_skill_supports_language() {
    local supported
    [ -f "$1" ] && [ -n "${CC_LANGUAGE:-}" ] || return 0
    supported=$(grep '^supported-languages:' "$1" 2>/dev/null | head -1 \
        | sed 's/supported-languages:[[:space:]]*//' | tr -d '[]' || true)
    [ -z "$supported" ] && return 0
    printf '%s\n' "$supported" | tr ',' ' ' | grep -qw "$CC_LANGUAGE"
}

# Print <skills> plus every core skill they require, transitively, as one
# space separated line (selection order first, then dependencies). Names that
# are not lowercase skill directory names (globs, "..", paths) are dropped
# with a warning, so they never reach a path.
# Usage: _cc_expand_skill_deps "<skills>" <framework dir>
_cc_expand_skill_deps() {
    local fw="$2" seen=" " pending="$1" next s dep noglob=0
    case "$-" in *f*) noglob=1 ;; esac
    set -f
    while [ -n "${pending// /}" ]; do
        next=""
        for s in $pending; do
            if ! printf '%s\n' "$s" | grep -qE '^[a-z0-9][a-z0-9-]*$'; then
                # stderr: callers capture stdout as the skill list
                type warn &>/dev/null && warn "Ignored invalid skill name: ${s}" >&2
                continue
            fi
            case "$seen" in *" ${s} "*) continue ;; esac
            seen="${seen}${s} "
            for dep in $(_cc_skill_requires "${fw}/core/skills/${s}/SKILL.md"); do
                case "$seen" in *" ${dep} "*) ;; *) next="${next} ${dep}" ;; esac
            done
        done
        pending="$next"
    done
    [ "$noglob" = 1 ] || set +f
    seen="${seen# }"
    printf '%s\n' "${seen% }"
}

# True if cognitive-core is also installed as a Claude Code plugin for
# <project dir>. The plugin then provides hooks, agents, and skills, and
# update.sh must not add core skills to .claude/ (#336). install.sh runs the
# same check inline because it detects the plugin before loading this library.
_cc_plugin_detected() {
    [ -d "${1}/.claude/plugins" ] || [ -f "${1}/.claude/settings.json" ] || return 1
    grep -q '"cognitive-core"' "${1}/.claude/settings.json" 2>/dev/null \
        || [ -d "${HOME}/.claude/plugins/cache/cognitive-core" ]
}
