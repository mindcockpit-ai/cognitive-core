#!/bin/bash
# Shared test helpers for adapter test suites (10, 11, 18)
# Extracted from duplicated blocks across adapter suites (#139 P5)
#
# Requires: test-helpers.sh sourced first (provides _pass, _fail, _skip, assert_*)
# Requires: ROOT_DIR set by calling suite

: "${ROOT_DIR:?ROOT_DIR must be set by the calling suite}"

# ---- Adapter contract validation ----
# Verifies adapter passes _adapter_validate contract check
# Usage: assert_adapter_validates "aider"
assert_adapter_validates() {
    local adapter="$1"
    local adapter_path
    adapter_path="${ROOT_DIR}/adapters/${adapter}/adapter.sh"

    local result
    result=$(bash -c '
        err() { printf "%s\n" "$*" >&2; }
        info() { printf "%s\n" "$*"; }
        warn() { printf "%s\n" "$*"; }
        SCRIPT_DIR="$1"
        FORCE=false
        CC_INSTALL_DIR="/tmp/test-cc"
        source "$1/adapters/_adapter-lib.sh"
        source "$2"
        _adapter_validate && echo "VALID"
    ' -- "${ROOT_DIR}" "${adapter_path}" 2>&1)
    assert_contains "${adapter} adapter: passes validation" "$result" "VALID"
}

# ---- Adapter variable checks ----
# Verifies _ADAPTER_NAME and _ADAPTER_INSTALL_DIR are set correctly
# Usage: assert_adapter_variables "aider" ".cognitive-core"
assert_adapter_variables() {
    local adapter="$1"
    local expected_dir="${2:-.cognitive-core}"
    local adapter_path
    adapter_path="${ROOT_DIR}/adapters/${adapter}/adapter.sh"

    local name
    name=$(bash -c '
        err() { : ; }; info() { : ; }; warn() { : ; }
        SCRIPT_DIR="$1"; FORCE=false; CC_INSTALL_DIR="/tmp/test-cc"
        source "$1/adapters/_adapter-lib.sh"
        source "$2"
        echo "$_ADAPTER_NAME"
    ' -- "${ROOT_DIR}" "${adapter_path}" 2>&1)
    assert_eq "${adapter} adapter: _ADAPTER_NAME=${adapter}" "${adapter}" "$name"

    local install_dir
    install_dir=$(bash -c '
        err() { : ; }; info() { : ; }; warn() { : ; }
        SCRIPT_DIR="$1"; FORCE=false; CC_INSTALL_DIR="/tmp/test-cc"
        source "$1/adapters/_adapter-lib.sh"
        source "$2"
        echo "$_ADAPTER_INSTALL_DIR"
    ' -- "${ROOT_DIR}" "${adapter_path}" 2>&1)
    assert_eq "${adapter} adapter: _ADAPTER_INSTALL_DIR=${expected_dir}" "${expected_dir}" "$install_dir"
}

# ---- Python generator compile check ----
# Verifies generate.py is valid Python that compiles without error
# Usage: assert_adapter_py_compiles "aider"
assert_adapter_py_compiles() {
    local adapter="$1"
    local py_file="${ROOT_DIR}/adapters/${adapter}/generate.py"

    assert_file_exists "${adapter}: generate.py exists" "$py_file"

    if command -v python3 &>/dev/null; then
        local py_check
        py_check=$(python3 -c "import py_compile; py_compile.compile('${py_file}', doraise=True)" 2>&1) || true
        if [ -z "$py_check" ]; then
            _pass "${adapter}: generate.py compiles without error"
        else
            _fail "${adapter}: generate.py compiles without error" "$py_check"
        fi
    else
        _skip "${adapter}: generate.py compile check (python3 not available)"
    fi
}

# ---- Required adapter functions check ----
# Verifies all 5 contract functions are defined after sourcing adapter
# Usage: assert_adapter_required_functions "intellij"
assert_adapter_required_functions() {
    local adapter="$1"
    local adapter_path
    adapter_path="${ROOT_DIR}/adapters/${adapter}/adapter.sh"

    local fn
    for fn in _adapter_install_hook _adapter_install_agent _adapter_install_skill \
              _adapter_generate_settings _adapter_generate_project_readme; do
        local fn_check
        fn_check=$(bash -c '
            err() { : ; }; info() { : ; }; warn() { : ; }
            SCRIPT_DIR="$1"; FORCE=false; CC_INSTALL_DIR="/tmp/test-cc"
            source "$1/adapters/_adapter-lib.sh"
            source "$2"
            type '"$fn"' &>/dev/null && echo "DEFINED"
        ' -- "${ROOT_DIR}" "${adapter_path}" 2>&1)
        assert_eq "${adapter} adapter: ${fn} defined" "DEFINED" "$fn_check"
    done
}
