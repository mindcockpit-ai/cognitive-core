#!/bin/bash
# validate-prompt.sh — Deterministic prompt vulnerability checker
# Part of cognitive-core project-board skill (Layer 1: regex linter)
# Reads prompt text from stdin, outputs advisory warnings to stdout.
# Advisory only — exit 0 always. Never blocks prompt generation.
#
# Mid-word matches: POSIX ERE prohibits \b word boundaries.
# Patterns like "consider" will match "reconsider" — accepted by design.
# See issue #163 for the full pattern table and rationale.
#
# Security: matched text is NEVER echoed in output or interpolated
# into subprocess commands. Only line numbers and category labels are emitted.
set -euo pipefail

# Helper: count grep matches safely (returns 0 on no match, no pipefail crash)
_grep_count() {
    local pattern="$1"
    local flags="${2:-}"
    local result
    # shellcheck disable=SC2086
    result=$(grep $flags -c "$pattern" 2>/dev/null) || result="0"
    echo "$result"
}

# ---- Section 1: Input Sanitisation Pipeline ----

# Read stdin with size cap (64KB)
INPUT_RAW=$(head -c 65536)

# Binary guard: reject non-text input cleanly
# Check for non-printable control characters (except newline, tab, carriage return)
if [ -n "$INPUT_RAW" ]; then
    _binary_chars=$(printf '%s' "$INPUT_RAW" | LC_ALL=C tr -d '[:print:][:space:]' | wc -c | tr -d '[:space:]')
    if [ "$_binary_chars" -gt 0 ]; then
        exit 0
    fi
fi

# Empty input guard
if [ -z "$INPUT_RAW" ]; then
    echo "Stochastic vulnerability check: 0 warning(s)"
    echo ""
    echo "Disclaimer: syntactic patterns only — semantic ambiguity requires human review"
    exit 0
fi

# Strip null bytes
INPUT_CLEAN=$(printf '%s' "$INPUT_RAW" | LC_ALL=C tr -d '\0')

# Strip zero-width Unicode characters (raw UTF-8 byte sequences)
# U+200B (e2 80 8b), U+200C (e2 80 8c), U+200D (e2 80 8d),
# U+200E (e2 80 8e), U+200F (e2 80 8f), U+FEFF (ef bb bf)
INPUT_CLEAN=$(printf '%s' "$INPUT_CLEAN" | LC_ALL=C sed \
    -e 's/\xE2\x80\x8B//g' \
    -e 's/\xE2\x80\x8C//g' \
    -e 's/\xE2\x80\x8D//g' \
    -e 's/\xE2\x80\x8E//g' \
    -e 's/\xE2\x80\x8F//g' \
    -e 's/\xEF\xBB\xBF//g' 2>/dev/null) || true

# Homoglyph normalisation (Cyrillic/Greek confusables → ASCII)
INPUT_CLEAN=$(printf '%s' "$INPUT_CLEAN" | iconv -f UTF-8 -t ASCII//TRANSLIT//IGNORE 2>/dev/null || printf '%s' "$INPUT_CLEAN")

# Save full text for structural checks
FULL_TEXT="$INPUT_CLEAN"

# ---- Section 2: XML Section Stripping ----
# Remove content between non-instruction XML tags to prevent false positives.
# Keep <scope> and <constraints>; strip <context>, <acceptance_criteria>,
# <after_implementation>, <agents>, and any other tagged sections.

INSTRUCTION_TEXT="$INPUT_CLEAN"

# Strip known non-instruction sections (delete lines between open/close tags)
for _tag in context acceptance_criteria after_implementation agents; do
    INSTRUCTION_TEXT=$(printf '%s\n' "$INSTRUCTION_TEXT" | sed "/<${_tag}>/,/<\/${_tag}>/d" 2>/dev/null) || true
done

# Fallback: if stripping removed everything, analyse entire text
if [ -z "$INSTRUCTION_TEXT" ]; then
    INSTRUCTION_TEXT="$INPUT_CLEAN"
fi

# ---- Section 3: Pattern Matching ----

WARN_COUNT=0
WARNINGS=""

# Pattern arrays (7 categories, 12 total patterns)
# POSIX ERE only — no \s, \b, \w
PATTERNS=(
    'please[[:space:]]|could you|would you|it would be nice|feel free to'
    'consider[[:space:]]|might[[:space:]]|possibly[[:space:]]|perhaps[[:space:]]|maybe[[:space:]]'
    'adequate[[:space:]]|reasonable[[:space:]]|appropriate[[:space:]]|sufficient[[:space:]]'
    'where possible|as appropriate|as needed'
    'etc[.]|and so on|including but not limited to'
    'soon[[:space:]]|eventually[[:space:]]|shortly[[:space:]]'
    'several[[:space:]]|multiple[[:space:]]|various[[:space:]]|a number of'
)

MESSAGES=(
    'politeness — use imperative mood'
    'hedging — be direct'
    'vague term — be specific'
    'escape clause — remove qualifier'
    'open-ended — enumerate explicitly'
    'temporal vague — specify timeline or remove'
    'ambiguous quantifier — use exact count'
)

LINENUM=0
while IFS= read -r line || [ -n "$line" ]; do
    LINENUM=$((LINENUM + 1))
    # Skip empty lines
    [ -z "$line" ] && continue
    for i in "${!PATTERNS[@]}"; do
        if printf '%s' "$line" | grep -qiE "${PATTERNS[$i]}" 2>/dev/null; then
            WARN_COUNT=$((WARN_COUNT + 1))
            WARNINGS="${WARNINGS}$(printf '  WARN  line %d: %s\n' "$LINENUM" "${MESSAGES[$i]}")"
            WARNINGS="${WARNINGS}
"
        fi
    done
done <<< "$INSTRUCTION_TEXT"

# ---- Section 4: Structural Checks ----
# Run against FULL text (not stripped)

# S1: Word count >400 in instruction sections only
INSTRUCTION_WC=$(printf '%s' "$INSTRUCTION_TEXT" | wc -w | tr -d '[:space:]')
if [ "$INSTRUCTION_WC" -gt 400 ] 2>/dev/null; then
    WARN_COUNT=$((WARN_COUNT + 1))
    WARNINGS="${WARNINGS}  WARN  structure: instruction word count ${INSTRUCTION_WC} exceeds 400 limit
"
fi

# S2: Missing <constraints> section
_has_constraints=$(printf '%s' "$FULL_TEXT" | _grep_count '<constraints>')
if [ "$_has_constraints" -eq 0 ]; then
    WARN_COUNT=$((WARN_COUNT + 1))
    WARNINGS="${WARNINGS}  WARN  structure: missing <constraints> section
"
fi

# S3: Missing Do NOT boundaries (only when >200 instruction words)
if [ "${INSTRUCTION_WC:-0}" -gt 200 ] 2>/dev/null; then
    _has_donot=$(printf '%s' "$FULL_TEXT" | _grep_count 'do not' '-iE')
    if [ "$_has_donot" -eq 0 ]; then
        WARN_COUNT=$((WARN_COUNT + 1))
        WARNINGS="${WARNINGS}  WARN  structure: no \"Do NOT\" boundaries in >200-word prompt — add scope guards
"
    fi
fi

# S4: Missing file paths (no path-like strings in instruction text)
_has_paths=$(printf '%s' "$INSTRUCTION_TEXT" | _grep_count '[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+' '-E')
if [ "$_has_paths" -eq 0 ]; then
    WARN_COUNT=$((WARN_COUNT + 1))
    WARNINGS="${WARNINGS}  WARN  structure: no file paths found — specify affected files
"
fi

# S5: Dangling "the following" without subsequent content
FOLLOWING_LINE=$(printf '%s\n' "$FULL_TEXT" | { grep -n 'the following' 2>/dev/null || true; } | head -1 | cut -d: -f1)
if [ -n "$FOLLOWING_LINE" ]; then
    NEXT_LINE=$((FOLLOWING_LINE + 1))
    # Strip whitespace and XML tags — a line with only "</scope>" is not real content
    NEXT_CONTENT=$(printf '%s\n' "$FULL_TEXT" | sed -n "${NEXT_LINE}p" 2>/dev/null | sed 's/<[^>]*>//g' | tr -d '[:space:]')
    if [ -z "$NEXT_CONTENT" ]; then
        WARN_COUNT=$((WARN_COUNT + 1))
        WARNINGS="${WARNINGS}  WARN  line ${FOLLOWING_LINE}: dangling reference — \"the following\" without subsequent list
"
    fi
fi

# ---- Section 5: Output ----

echo "Stochastic vulnerability check: ${WARN_COUNT} warning(s)"
if [ -n "$WARNINGS" ]; then
    echo ""
    printf '%s' "$WARNINGS"
fi
echo ""
echo "Disclaimer: syntactic patterns only — semantic ambiguity requires human review"

exit 0
