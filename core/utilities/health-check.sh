#!/bin/bash
# =============================================================================
# cognitive-core: Context & Security Health Check
# =============================================================================
# Reports sizes of skills, agents, CLAUDE.md, and auto-load context estimate.
# Validates hook integrity against framework source.
# Reviews recent security events.
#
# Usage:
#   health-check.sh                    # Check current project
#   health-check.sh /path/to/project   # Check specific project
#
# This is a read-only script. Safe to run anytime.
# =============================================================================

set -euo pipefail

# Colors (disabled if not a terminal)
# shellcheck disable=SC2034
if [ -t 1 ]; then
    RED="\033[0;31m"
    GREEN="\033[0;32m"
    YELLOW="\033[1;33m"
    BLUE="\033[0;34m"
    BOLD="\033[1m"
    NC="\033[0m"
else
    RED="" GREEN="" YELLOW="" BLUE="" BOLD="" NC=""
fi

# Resolve project directory
PROJECT_DIR="${1:-${CC_PROJECT_DIR:-$(pwd)}}"

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: Directory not found: $PROJECT_DIR"
    exit 1
fi

SKILLS_DIR="$PROJECT_DIR/.claude/skills"
AGENTS_DIR="$PROJECT_DIR/.claude/agents"
HOOKS_DIR="$PROJECT_DIR/.claude/hooks"
CC_DIR="$PROJECT_DIR/.claude/cognitive-core"

# Budget limits
MAX_SKILL_LINES=500
MAX_AGENT_LINES=300
MAX_CLAUDE_LINES=400
MAX_CONTEXT_KB=100

WARNINGS=0
TOTAL_CONTEXT_BYTES=0

echo -e "${BOLD}=== cognitive-core Health Check ===${NC}"
echo -e "  Project: $PROJECT_DIR"
echo ""

# ---------------------------------------------------------------------------
# CLAUDE.md
# ---------------------------------------------------------------------------
echo -e "${BOLD}CLAUDE.md${NC}"
if [ -f "$PROJECT_DIR/CLAUDE.md" ]; then
    LINES=$(wc -l < "$PROJECT_DIR/CLAUDE.md" | tr -d ' ')
    BYTES=$(wc -c < "$PROJECT_DIR/CLAUDE.md" | tr -d ' ')
    TOTAL_CONTEXT_BYTES=$((TOTAL_CONTEXT_BYTES + BYTES))
    KB=$((BYTES / 1024))
    if [ "$LINES" -gt "$MAX_CLAUDE_LINES" ]; then
        echo -e "  ${YELLOW}[OVER]${NC} $LINES lines / ${KB}KB (budget: $MAX_CLAUDE_LINES lines)"
        ((WARNINGS++)) || true
    else
        echo -e "  ${GREEN}[OK]${NC}   $LINES lines / ${KB}KB (budget: $MAX_CLAUDE_LINES lines)"
    fi
else
    echo -e "  ${BLUE}[SKIP]${NC} Not found"
fi
echo ""

# ---------------------------------------------------------------------------
# Skills
# ---------------------------------------------------------------------------
echo -e "${BOLD}Skills${NC}"
if [ -d "$SKILLS_DIR" ]; then
    SKILL_COUNT=0
    while IFS= read -r skill_file; do
        SKILL_NAME=$(echo "$skill_file" | sed "s|$SKILLS_DIR/||;s|/SKILL.md||")
        LINES=$(wc -l < "$skill_file" | tr -d ' ')
        BYTES=$(wc -c < "$skill_file" | tr -d ' ')
        SKILL_COUNT=$((SKILL_COUNT + 1))

        # Check if auto-loaded
        AUTO_LOAD="yes"
        if grep -q "disable-model-invocation: true" "$skill_file" 2>/dev/null; then
            AUTO_LOAD="no"
        else
            TOTAL_CONTEXT_BYTES=$((TOTAL_CONTEXT_BYTES + BYTES))
        fi

        if [ "$LINES" -gt "$MAX_SKILL_LINES" ]; then
            echo -e "  ${YELLOW}[OVER]${NC} $SKILL_NAME: $LINES lines (budget: $MAX_SKILL_LINES) auto-load: $AUTO_LOAD"
            ((WARNINGS++)) || true
        else
            echo -e "  ${GREEN}[OK]${NC}   $SKILL_NAME: $LINES lines, auto-load: $AUTO_LOAD"
        fi
    done < <(find "$SKILLS_DIR" -name "SKILL.md" -type f 2>/dev/null | sort)
    echo -e "  Total: $SKILL_COUNT skill(s)"
else
    echo -e "  ${BLUE}[SKIP]${NC} No .claude/skills/ directory"
fi
echo ""

# ---------------------------------------------------------------------------
# Agents
# ---------------------------------------------------------------------------
echo -e "${BOLD}Agents${NC}"
if [ -d "$AGENTS_DIR" ]; then
    AGENT_COUNT=0
    AGENTS_WITH_RESTRICTIONS=0
    while IFS= read -r agent_file; do
        AGENT_NAME=$(basename "$agent_file" .md)
        LINES=$(wc -l < "$agent_file" | tr -d ' ')
        BYTES=$(wc -c < "$agent_file" | tr -d ' ')
        TOTAL_CONTEXT_BYTES=$((TOTAL_CONTEXT_BYTES + BYTES))
        AGENT_COUNT=$((AGENT_COUNT + 1))

        # Check for disallowedTools (least-privilege)
        HAS_RESTRICTIONS=""
        if grep -q "disallowedTools" "$agent_file" 2>/dev/null; then
            HAS_RESTRICTIONS=" [restricted]"
            AGENTS_WITH_RESTRICTIONS=$((AGENTS_WITH_RESTRICTIONS + 1))
        fi

        # Check for YAML frontmatter
        HAS_FRONTMATTER=""
        if head -1 "$agent_file" | grep -q "^---" 2>/dev/null; then
            HAS_FRONTMATTER=""
        else
            HAS_FRONTMATTER=" ${YELLOW}(missing frontmatter)${NC}"
            ((WARNINGS++)) || true
        fi

        if [ "$LINES" -gt "$MAX_AGENT_LINES" ]; then
            echo -e "  ${YELLOW}[OVER]${NC} $AGENT_NAME: $LINES lines (budget: $MAX_AGENT_LINES)${HAS_RESTRICTIONS}${HAS_FRONTMATTER}"
            ((WARNINGS++)) || true
        else
            echo -e "  ${GREEN}[OK]${NC}   $AGENT_NAME: $LINES lines${HAS_RESTRICTIONS}${HAS_FRONTMATTER}"
        fi
    done < <(find "$AGENTS_DIR" -name "*.md" -type f 2>/dev/null | sort)
    echo -e "  Total: $AGENT_COUNT agent(s), $AGENTS_WITH_RESTRICTIONS with tool restrictions"
else
    echo -e "  ${BLUE}[SKIP]${NC} No .claude/agents/ directory"
fi
echo ""

# ---------------------------------------------------------------------------
# Hook Integrity
# ---------------------------------------------------------------------------
echo -e "${BOLD}Hook Integrity${NC}"
if [ -d "$HOOKS_DIR" ]; then
    VERSION_FILE="$CC_DIR/version.json"
    SOURCE_DIR=""
    if [ -f "$VERSION_FILE" ]; then
        SOURCE_DIR=$(grep -o '"source"[[:space:]]*:[[:space:]]*"[^"]*"' "$VERSION_FILE" 2>/dev/null | head -1 | sed 's/.*"source"[[:space:]]*:[[:space:]]*"//;s/"//')
    fi

    HOOK_COUNT=0
    HOOK_MISMATCHES=0
    while IFS= read -r hook_file; do
        HOOK_NAME=$(basename "$hook_file")
        HOOK_COUNT=$((HOOK_COUNT + 1))

        # Check executable
        if [ ! -x "$hook_file" ]; then
            echo -e "  ${YELLOW}[WARN]${NC} $HOOK_NAME: not executable"
            ((WARNINGS++)) || true
        fi

        # Compare against framework source
        if [ -n "$SOURCE_DIR" ] && [ -d "${SOURCE_DIR}/core/hooks" ]; then
            SRC_FILE="${SOURCE_DIR}/core/hooks/${HOOK_NAME}"
            if [ -f "$SRC_FILE" ]; then
                # Cross-platform SHA256
                if command -v shasum &>/dev/null; then
                    INSTALLED_SHA=$(shasum -a 256 "$hook_file" | awk '{print $1}')
                    SOURCE_SHA=$(shasum -a 256 "$SRC_FILE" | awk '{print $1}')
                elif command -v sha256sum &>/dev/null; then
                    INSTALLED_SHA=$(sha256sum "$hook_file" | awk '{print $1}')
                    SOURCE_SHA=$(sha256sum "$SRC_FILE" | awk '{print $1}')
                else
                    INSTALLED_SHA="unknown"
                    SOURCE_SHA="unknown"
                fi

                if [ "$INSTALLED_SHA" = "$SOURCE_SHA" ]; then
                    echo -e "  ${GREEN}[OK]${NC}   $HOOK_NAME: matches framework source"
                else
                    echo -e "  ${YELLOW}[DIFF]${NC} $HOOK_NAME: differs from framework source (user-modified or outdated)"
                    HOOK_MISMATCHES=$((HOOK_MISMATCHES + 1))
                fi
            else
                echo -e "  ${BLUE}[NEW]${NC}  $HOOK_NAME: not in framework source (custom hook)"
            fi
        else
            echo -e "  ${GREEN}[OK]${NC}   $HOOK_NAME: (no source dir for comparison)"
        fi
    done < <(find "$HOOKS_DIR" -name "*.sh" -type f 2>/dev/null | sort)

    echo -e "  Total: $HOOK_COUNT hook(s)"
    if [ "$HOOK_MISMATCHES" -gt 0 ]; then
        echo -e "  ${YELLOW}$HOOK_MISMATCHES hook(s) differ from framework${NC} — run update.sh to refresh or verify changes"
    fi
else
    echo -e "  ${BLUE}[SKIP]${NC} No .claude/hooks/ directory"
fi
echo ""

# ---------------------------------------------------------------------------
# Security Log Summary
# ---------------------------------------------------------------------------
echo -e "${BOLD}Security Log${NC}"
SECURITY_LOG="$CC_DIR/security.log"
if [ -f "$SECURITY_LOG" ]; then
    LOG_SIZE=$(du -sh "$SECURITY_LOG" 2>/dev/null | cut -f1)
    LOG_LINES=$(wc -l < "$SECURITY_LOG" | tr -d ' ')
    DENY_COUNT=$(grep -c '\[DENY\]' "$SECURITY_LOG" 2>/dev/null || echo "0")
    WARN_COUNT=$(grep -c '\[WARN\]' "$SECURITY_LOG" 2>/dev/null || echo "0")
    ERROR_COUNT=$(grep -c '\[ERROR\]' "$SECURITY_LOG" 2>/dev/null || echo "0")

    echo -e "  Size: $LOG_SIZE ($LOG_LINES entries)"
    echo -e "  DENY events:  $DENY_COUNT"
    echo -e "  WARN events:  $WARN_COUNT"
    echo -e "  ERROR events: $ERROR_COUNT"

    if [ "$DENY_COUNT" -gt 0 ]; then
        echo -e "  ${BLUE}Recent DENY events:${NC}"
        grep '\[DENY\]' "$SECURITY_LOG" | tail -3 | while read -r line; do
            echo "    $line"
        done
    fi
else
    echo -e "  ${BLUE}[SKIP]${NC} No security.log found (clean)"
fi
echo ""

# ---------------------------------------------------------------------------
# Auto-load context estimate
# ---------------------------------------------------------------------------
echo -e "${BOLD}Auto-Load Context Estimate${NC}"
TOTAL_KB=$((TOTAL_CONTEXT_BYTES / 1024))
if [ "$TOTAL_KB" -gt "$MAX_CONTEXT_KB" ]; then
    echo -e "  ${YELLOW}[OVER]${NC} ${TOTAL_KB}KB (budget: ${MAX_CONTEXT_KB}KB)"
    ((WARNINGS++)) || true
else
    echo -e "  ${GREEN}[OK]${NC}   ${TOTAL_KB}KB (budget: ${MAX_CONTEXT_KB}KB)"
fi
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo -e "${BOLD}========================================${NC}"
if [ "$WARNINGS" -gt 0 ]; then
    echo -e "  ${YELLOW}$WARNINGS warning(s)${NC} — components over budget or issues found"
    echo -e "  Tips:"
    echo -e "    - Split large skills into SKILL.md + references/"
    echo -e "    - Use disable-model-invocation for manual-only skills"
    echo -e "    - Add disallowedTools to agents for least-privilege"
    echo -e "    - Run update.sh if hooks differ from framework"
else
    echo -e "  ${GREEN}All checks passed${NC} — context and security within budget"
fi
echo -e "${BOLD}========================================${NC}"

exit 0
