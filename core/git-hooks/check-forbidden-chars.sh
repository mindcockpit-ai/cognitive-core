#!/usr/bin/env bash
#
# Forbidden-Character Pre-commit Check
#
# Two enforcement modes, extension-driven:
#
#   ASCII-ONLY  (source code): rejects ANY non-ASCII byte (>0x7F)
#               Default extensions: pm, pl, t, sh, bash, js, ts, tsx, jsx,
#                 css, scss, less, html, tx, yml, yaml, json, toml, ini, conf,
#                 sql, py, rb, go, java, c, h, cpp, hpp, psgi, pod
#               Rationale: any non-ASCII in code is suspect (smart-quote
#                 artifacts, copy-paste from AI, locale strings that should
#                 live in data files). Stricter than a blocklist; future-proof.
#
#   BLOCKLIST   (docs): rejects only the configured AI-tell characters
#               Default extensions: md, markdown, txt, rst, adoc
#               Rationale: docs legitimately contain German, math notation,
#                 customer-source data; only ban known AI tells.
#
# Default blocklist:
#   U+2014 EM DASH                  -> "-"
#   U+2013 EN DASH                  -> "-"
#   U+2026 HORIZONTAL ELLIPSIS      -> "..."
#   U+2018 LEFT SINGLE QUOTATION    -> "'"
#   U+2019 RIGHT SINGLE QUOTATION   -> "'"
#   U+201C LEFT DOUBLE QUOTATION    -> '"'
#   U+201D RIGHT DOUBLE QUOTATION   -> '"'
#   U+2192 RIGHTWARDS ARROW         -> "->"
#   U+00A0 NO-BREAK SPACE           -> " "
#   U+200B ZERO-WIDTH SPACE         -> remove
#   U+200C ZERO-WIDTH NON-JOINER    -> remove
#
# Configuration (per-project overrides):
#   .husky/forbidden-chars.conf   (preferred)
#   bin/hooks/forbidden-chars.conf (fallback)
#
# Config directives:
#   CODE_EXT = pm pl t sh js ...        # space-separated; override code extensions
#   DOC_EXT  = md txt rst ...           # space-separated; override doc extensions
#   ALLOW_DEFAULT = 0                   # blocklist: start from empty list
#   <hex> <NAME> [-> <repl>]            # add/override a blocklist rule
#   !<hex>                              # remove a default blocklist rule
#
# Bypass (not recommended): git commit --no-verify
#
# Trust boundary
# --------------
# The per-repo config file (.husky/forbidden-chars.conf or
# bin/hooks/forbidden-chars.conf) is parsed line-by-line and the resulting
# codepoint/name pairs are interpolated verbatim into an inline Perl
# `BEGIN { our %FN = (...) }` block (see PERL_HASH below). A hostile config
# (e.g., `2014" => "x"; system("..."); my $f = "`) could inject arbitrary
# Perl code that runs with the user's commit privileges.
#
# This is **acceptable** under the same trust assumption as `.gitignore`,
# `.editorconfig`, or any other per-repo config: a compromised repo's local
# config is out of scope for this hook. Mitigation: configs are typically
# committed to the repo and reviewed alongside other code changes.
#
# See `core/skills/pre-commit/SKILL.md` section "Security model" for the
# adopter-facing version of this note.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

DEFAULT_CODE_EXT="pm pl t sh bash js ts tsx jsx css scss less html tx yml yaml json toml ini conf sql py rb go java c h cpp hpp psgi pod"
DEFAULT_DOC_EXT="md markdown txt rst adoc"

DEFAULT_FORBIDDEN=(
    "2014|EM DASH|-"
    "2013|EN DASH|-"
    "2026|HORIZONTAL ELLIPSIS|..."
    "2018|LEFT SINGLE QUOTATION MARK|'"
    "2019|RIGHT SINGLE QUOTATION MARK|'"
    "201C|LEFT DOUBLE QUOTATION MARK|\""
    "201D|RIGHT DOUBLE QUOTATION MARK|\""
    "2192|RIGHTWARDS ARROW|->"
    "00A0|NO-BREAK SPACE| "
    "200B|ZERO-WIDTH SPACE|REMOVE"
    "200C|ZERO-WIDTH NON-JOINER|REMOVE"
)

CONFIG_FILE=""
if [ -f "$REPO_ROOT/.husky/forbidden-chars.conf" ]; then
    CONFIG_FILE="$REPO_ROOT/.husky/forbidden-chars.conf"
elif [ -f "$REPO_ROOT/bin/hooks/forbidden-chars.conf" ]; then
    CONFIG_FILE="$REPO_ROOT/bin/hooks/forbidden-chars.conf"
fi

CODE_EXT="$DEFAULT_CODE_EXT"
DOC_EXT="$DEFAULT_DOC_EXT"
declare -a EFFECTIVE
EFFECTIVE=("${DEFAULT_FORBIDDEN[@]}")

# Note: `${arr[@]+"${arr[@]}"}` idiom is required for bash 3.2 (macOS default)
# safety under `set -u`: expanding `"${arr[@]}"` on an empty array errors as
# "unbound variable" on bash 3.2 (fixed in 4.4+). The `+` form expands to
# nothing when the array is unset/empty, avoiding the trap.

if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    while IFS= read -r line; do
        line="${line%%#*}"
        line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "$line" ] && continue

        case "$line" in
            CODE_EXT*=*)
                CODE_EXT="$(echo "$line" | sed -E 's/^CODE_EXT[[:space:]]*=[[:space:]]*//')"
                continue
                ;;
            DOC_EXT*=*)
                DOC_EXT="$(echo "$line" | sed -E 's/^DOC_EXT[[:space:]]*=[[:space:]]*//')"
                continue
                ;;
            ALLOW_DEFAULT*=*0*)
                EFFECTIVE=()
                continue
                ;;
            ALLOW_DEFAULT*=*1*)
                EFFECTIVE=("${DEFAULT_FORBIDDEN[@]}")
                continue
                ;;
        esac

        if [ "${line#!}" != "$line" ]; then
            hex=$(echo "${line#!}" | awk '{print toupper($1)}')
            new=()
            for entry in ${EFFECTIVE[@]+"${EFFECTIVE[@]}"}; do
                [ "${entry%%|*}" != "$hex" ] && new+=("$entry")
            done
            EFFECTIVE=(${new[@]+"${new[@]}"})
            continue
        fi

        hex=$(echo "$line" | awk '{print toupper($1)}')
        rest=$(echo "$line" | sed -E 's/^[^[:space:]]+[[:space:]]+//')
        if echo "$rest" | grep -q '\->'; then
            name=$(echo "$rest" | sed -E 's/[[:space:]]*->.*//')
            repl=$(echo "$rest" | sed -E 's/^.*-> ?//')
        else
            name="$rest"
            repl="REMOVE"
        fi
        EFFECTIVE+=("$hex|$name|$repl")
    done < "$CONFIG_FILE"
fi

build_regex() {
    local exts="$1"
    local r=""
    for e in $exts; do
        [ -n "$r" ] && r+="|"
        r+="\\.$e\$"
    done
    echo "$r"
}
CODE_REGEX=$(build_regex "$CODE_EXT")
DOC_REGEX=$(build_regex "$DOC_EXT")
ALL_REGEX="${CODE_REGEX}|${DOC_REGEX}"

STAGED=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E "$ALL_REGEX" || true)
[ -z "$STAGED" ] && exit 0

PERL_HASH=""
for entry in ${EFFECTIVE[@]+"${EFFECTIVE[@]}"}; do
    [ -z "$entry" ] && continue
    hex="${entry%%|*}"
    rest="${entry#*|}"
    name="${rest%%|*}"
    PERL_HASH+="\"\\x{$hex}\" => \"U+$hex $name\","
done

VIOLATIONS=0
SCRIPT_FILE="$(cd "$(dirname "$0")" && pwd -P)/$(basename "$0")"
ABS_CONFIG_FILE="${CONFIG_FILE:+$(cd "$(dirname "$CONFIG_FILE")" && pwd -P)/$(basename "$CONFIG_FILE")}"

# Read line-by-line: paths from `git diff --cached --name-only` are NL-separated.
# Avoids word-splitting on spaces in filenames (e.g., "docs/My Notes.md").
while IFS= read -r file; do
    [ -z "$file" ] && continue
    [ ! -f "$file" ] && continue
    abs_file="$(cd "$(dirname "$file")" && pwd -P)/$(basename "$file")"
    [ "$abs_file" = "$SCRIPT_FILE" ] && continue
    [ -n "$ABS_CONFIG_FILE" ] && [ "$abs_file" = "$ABS_CONFIG_FILE" ] && continue

    OUTPUT=""
    MODE=""

    if echo "$file" | grep -qE "$CODE_REGEX"; then
        MODE="ASCII"
        # `|| true`: under `set -e`, a failing perl (e.g., file disappeared
        # between the existence check and the read) would abort the script.
        # An empty capture is the natural "no violation" signal here.
        OUTPUT=$(perl -ne '
            while (/([^\x00-\x7F]+)/g) {
                my $ln = $.;
                my $bad = $1;
                my @cps = map { sprintf("U+%04X", ord) } split //, $bad;
                my $cp_str = join(" ", @cps);
                my $excerpt = $_;
                chomp $excerpt;
                if (length $excerpt > 80) { $excerpt = substr($excerpt, 0, 77) . "..."; }
                print "    line $ln [non-ASCII: $cp_str]: $excerpt\n";
                last;
            }
        ' "$file" 2>/dev/null || true)
    elif echo "$file" | grep -qE "$DOC_REGEX"; then
        MODE="BLOCK"
        if [ "${#EFFECTIVE[@]}" = "0" ]; then
            continue
        fi
        # `|| true`: see ASCII-mode comment above. Identical rationale.
        OUTPUT=$(perl -CSD -ne "
            BEGIN { our %FN = ($PERL_HASH); our @KEYS = sort keys %FN; }
            for my \$c (@KEYS) {
                while (/\\Q\$c\\E/g) {
                    my \$ln = \$.;
                    my \$excerpt = \$_;
                    chomp \$excerpt;
                    if (length \$excerpt > 80) { \$excerpt = substr(\$excerpt, 0, 77) . '...'; }
                    print \"    line \$ln [\$FN{\$c}]: \$excerpt\\n\";
                    last;
                }
            }
        " "$file" 2>/dev/null || true)
    fi

    if [ -n "$OUTPUT" ]; then
        if [ $VIOLATIONS -eq 0 ]; then
            echo "Forbidden characters detected in staged files:"
            [ -n "$CONFIG_FILE" ] && echo "  (config: $CONFIG_FILE)"
            echo ""
        fi
        echo "  $file [mode: $MODE]:"
        echo "$OUTPUT"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done <<< "$STAGED"

if [ $VIOLATIONS -gt 0 ]; then
    echo ""
    echo "Source code (CODE_EXT) must be pure ASCII. Docs (DOC_EXT) must avoid AI-tell characters."
    echo ""
    echo "Auto-fix doc files (default replacement table):"
    echo "    perl -i -CSD -pe '"
    for entry in ${EFFECTIVE[@]+"${EFFECTIVE[@]}"}; do
        [ -z "$entry" ] && continue
        hex="${entry%%|*}"
        rest="${entry#*|}"
        name="${rest%%|*}"
        repl="${rest#*|}"
        if [ "$repl" = "REMOVE" ]; then
            echo "        s/\\x{$hex}//g;       # $name"
        else
            esc_repl="${repl//\'/\'\\\'\'}"
            echo "        s/\\x{$hex}/$esc_repl/g;       # $name"
        fi
    done
    echo "    ' \$(git diff --cached --name-only --diff-filter=ACM | grep -E '\\.(md|markdown|txt|rst|adoc)\$')"
    echo ""
    echo "Source code with non-ASCII must be edited manually (move locale strings to data files,"
    echo "or escape via \\x{NNNN} in Perl, \\uNNNN in JS, etc.)"
    echo ""
    echo "To bypass (not recommended): git commit --no-verify"
    exit 1
fi

exit 0
