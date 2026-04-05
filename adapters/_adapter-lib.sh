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
