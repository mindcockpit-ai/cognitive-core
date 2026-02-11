#!/bin/bash
# =============================================================================
# cognitive-core: Quick Context Health Check
# =============================================================================
# Reports sizes of skills, agents, CLAUDE.md, and auto-load context estimate.
# Warns if any component exceeds the recommended budget.
#
# Usage:
#   health-check.sh                    # Check current project
#   health-check.sh /path/to/project   # Check specific project
#
# This is a read-only script. Safe to run anytime.
# =============================================================================

set -euo pipefail

# Colors (disabled if not a terminal)
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

# Budget limits
MAX_SKILL_LINES=500
MAX_AGENT_LINES=300
MAX_CLAUDE_LINES=400
MAX_CONTEXT_KB=100

WARNINGS=0
TOTAL_CONTEXT_BYTES=0

echo -e "${BOLD}=== Context Health Check ===${NC}"
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
    while IFS= read -r agent_file; do
        AGENT_NAME=$(basename "$agent_file" .md)
        LINES=$(wc -l < "$agent_file" | tr -d ' ')
        BYTES=$(wc -c < "$agent_file" | tr -d ' ')
        TOTAL_CONTEXT_BYTES=$((TOTAL_CONTEXT_BYTES + BYTES))
        AGENT_COUNT=$((AGENT_COUNT + 1))

        if [ "$LINES" -gt "$MAX_AGENT_LINES" ]; then
            echo -e "  ${YELLOW}[OVER]${NC} $AGENT_NAME: $LINES lines (budget: $MAX_AGENT_LINES)"
            ((WARNINGS++)) || true
        else
            echo -e "  ${GREEN}[OK]${NC}   $AGENT_NAME: $LINES lines"
        fi
    done < <(find "$AGENTS_DIR" -name "*.md" -type f 2>/dev/null | sort)
    echo -e "  Total: $AGENT_COUNT agent(s)"
else
    echo -e "  ${BLUE}[SKIP]${NC} No .claude/agents/ directory"
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
    echo -e "  ${YELLOW}$WARNINGS warning(s)${NC} -- components over budget"
    echo -e "  Tip: Split large skills into SKILL.md + references/"
    echo -e "  Tip: Use disable-model-invocation for manual-only skills"
else
    echo -e "  ${GREEN}All checks passed${NC} -- context is within budget"
fi
echo -e "${BOLD}========================================${NC}"

exit 0
