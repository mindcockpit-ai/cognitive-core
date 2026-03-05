#!/bin/bash
# cognitive-core branding — shared ASCII banner, color constants, and status helpers
# Source this file in scripts, agents, and skills for consistent branding.
#
# Usage:
#   source "$(dirname "$0")/core/brand.sh"       # from repo root (install.sh, update.sh)
#   source "${CC_FRAMEWORK_DIR}/core/brand.sh"   # from hooks/skills via framework path
#
# Functions:
#   _cc_banner                    # full banner — nested squares logo + version + tagline
#   _cc_banner_compact            # one-liner   — ◻ ◻ ◻ • cognitive-core v1.0.0
#   _cc_divider [label]           # section divider with optional label
#   _cc_info   "message"          # [+] green success message
#   _cc_warn   "message"          # [!] yellow warning message
#   _cc_err    "message"          # [x] red error message (to stderr)
#   _cc_header "title"            # === Section Title === (bold cyan)
#
# All output functions are tty-aware: colors are emitted only when stdout is a terminal.
# When piped or redirected, plain text is output for clean log files.

# ---- Guard against double-sourcing ----
[ -n "${_CC_BRAND_LOADED:-}" ] && return 0
_CC_BRAND_LOADED=1

# ---- Colors (tty-aware) ----
if [ -t 1 ] 2>/dev/null; then
    _CC_BOLD='\033[1m'
    _CC_DIM='\033[2m'
    _CC_CYAN='\033[0;36m'
    _CC_BLUE='\033[0;34m'
    _CC_PURPLE='\033[0;35m'
    _CC_GREEN='\033[0;32m'
    _CC_YELLOW='\033[0;33m'
    _CC_RED='\033[0;31m'
    _CC_RESET='\033[0m'
else
    _CC_BOLD='' _CC_DIM='' _CC_CYAN='' _CC_BLUE='' _CC_PURPLE=''
    _CC_GREEN='' _CC_YELLOW='' _CC_RED='' _CC_RESET=''
fi

# ---- Full ASCII Banner ----
# Nested squares with center dot and cardinal lines — matches the SVG logo.
# Prints: logo art (cyan), name (bold cyan, spaced), version (dim purple), tagline (dim).
_cc_banner() {
    local version="${CC_VERSION:-}"
    local ver_str=""
    [ -n "$version" ] && ver_str=" v${version}"
    printf "${_CC_CYAN}"
    cat << 'LOGO'

    ┌─────────────────────────┐
    │   ┌─────────────────┐   │
    │   │   ┌─────────┐   │   │
    │   │   │   ┌─┐   │   │   │
    │───│───│───│•│───│───│───│
    │   │   │   └─┘   │   │   │
    │   │   └─────────┘   │   │
    │   └─────────────────┘   │
    └─────────────────────────┘
LOGO
    printf "${_CC_RESET}"
    printf "${_CC_BOLD}${_CC_CYAN}    c o g n i t i v e - c o r e${_CC_RESET}"
    printf "${_CC_DIM}${_CC_PURPLE}%s${_CC_RESET}\n" "$ver_str"
    printf "${_CC_DIM}    AI-native development framework${_CC_RESET}\n\n"
}

# ---- Compact One-Liner ----
# Three nested squares + dot glyph as brand mark, followed by name and version.
# Use for: skill headers, agent startup, hook output, log prefixes.
_cc_banner_compact() {
    printf "${_CC_CYAN}◻${_CC_BLUE}◻${_CC_PURPLE}◻${_CC_CYAN}•${_CC_RESET} "
    printf "${_CC_BOLD}cognitive-core${_CC_RESET}"
    local version="${CC_VERSION:-}"
    [ -n "$version" ] && printf "${_CC_DIM} v${version}${_CC_RESET}"
    printf "\n"
}

# ---- Section Divider ----
# With label:    ──── Section Name ────
# Without label: ─────────────────────────────────
_cc_divider() {
    local label="${1:-}"
    if [ -n "$label" ]; then
        printf "${_CC_DIM}──── ${_CC_CYAN}%s${_CC_DIM} ────${_CC_RESET}\n" "$label"
    else
        printf "${_CC_DIM}─────────────────────────────────${_CC_RESET}\n"
    fi
}

# ---- Status Helpers ----
# Consistent with install.sh / update.sh style. Use these instead of raw echo/printf.
_cc_info()   { printf "${_CC_GREEN}[+]${_CC_RESET} %s\n" "$*"; }
_cc_warn()   { printf "${_CC_YELLOW}[!]${_CC_RESET} %s\n" "$*"; }
_cc_err()    { printf "${_CC_RED}[x]${_CC_RESET} %s\n" "$*" >&2; }
_cc_header() { printf "\n${_CC_BOLD}${_CC_CYAN}=== %s ===${_CC_RESET}\n" "$*"; }
