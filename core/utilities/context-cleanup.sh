#!/bin/bash
# =============================================================================
# cognitive-core: Context Cleanup Utility
# =============================================================================
# Generic context cleanup for Claude Code projects. Cleans caches, trims
# history, archives old session docs, and reports context health.
#
# Usage:
#   context-cleanup.sh --all       Full cleanup + context health check
#   context-cleanup.sh --health    Context health check only (read-only)
#   context-cleanup.sh --cache     Clean CLI + MCP caches
#   context-cleanup.sh --history   Trim Claude history only
#   context-cleanup.sh --docs      Archive old sessions + show stats
#
# Crontab example (weekly Monday 13:00):
#   0 13 * * 1 /path/to/context-cleanup.sh --all >> /tmp/cc_cleanup.log 2>&1
# =============================================================================

set -e

# Colors (disabled if not a terminal)
# shellcheck disable=SC2034
if [ -t 1 ]; then
    RED="\033[0;31m"
    GREEN="\033[0;32m"
    YELLOW="\033[1;33m"
    BLUE="\033[0;34m"
    NC="\033[0m"
else
    RED="" GREEN="" YELLOW="" BLUE="" NC=""
fi

# Resolve project directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${CC_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# Look for project root markers
if [ ! -f "$PROJECT_DIR/CLAUDE.md" ] && [ ! -f "$PROJECT_DIR/cognitive-core.conf" ]; then
    # Try parent directories
    SEARCH_DIR="$SCRIPT_DIR"
    while [ "$SEARCH_DIR" != "/" ]; do
        if [ -f "$SEARCH_DIR/CLAUDE.md" ] || [ -f "$SEARCH_DIR/cognitive-core.conf" ]; then
            PROJECT_DIR="$SEARCH_DIR"
            break
        fi
        SEARCH_DIR="$(dirname "$SEARCH_DIR")"
    done
fi

echo -e "${GREEN}=== Cognitive-Core Context Cleanup ===${NC}"
echo -e "  Project: $PROJECT_DIR"
echo -e "  Platform: $(uname -s)"
echo ""

print_status() { echo -e "  ${GREEN}[OK]${NC} $1"; }
print_warning() { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "  ${RED}[FAIL]${NC} $1"; }
print_info() { echo -e "  ${BLUE}[INFO]${NC} $1"; }

# Cross-platform file size helper
get_file_size() {
    if [[ "$(uname)" == "Darwin" ]]; then
        stat -f%z "$1" 2>/dev/null || echo 0
    else
        stat -c%s "$1" 2>/dev/null || echo 0
    fi
}

# ---------------------------------------------------------------------------
# Clean Claude CLI cache
# ---------------------------------------------------------------------------
clean_claude_cache() {
    echo "Cleaning Claude cache..."

    CLAUDE_CACHE_DIRS=(
        "$HOME/.cache/claude"
        "$HOME/.claude/debug"
        "$HOME/.claude/shell-snapshots"
    )

    for dir in "${CLAUDE_CACHE_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            SIZE=$(du -sh "$dir" 2>/dev/null | cut -f1)
            find "$dir" -type f -mtime +7 -delete 2>/dev/null || true
            print_status "Cleaned old files in: $dir ($SIZE before)"
        fi
    done

    # Clean MCP cache
    if [ -d "$HOME/.cache/context7-mcp" ]; then
        rm -rf "$HOME/.cache/context7-mcp"/* 2>/dev/null || true
        print_status "Cleared Context7 MCP cache"
    fi
}

# ---------------------------------------------------------------------------
# Trim Claude history
# ---------------------------------------------------------------------------
clean_claude_history() {
    echo "Cleaning Claude history..."

    HISTORY_FILE="$HOME/.claude/history.jsonl"
    if [ -f "$HISTORY_FILE" ]; then
        SIZE=$(du -sh "$HISTORY_FILE" 2>/dev/null | cut -f1)
        FILE_SIZE=$(get_file_size "$HISTORY_FILE")
        if [ "$FILE_SIZE" -gt 10485760 ]; then
            tail -1000 "$HISTORY_FILE" > /tmp/cc_history_trimmed.jsonl
            mv /tmp/cc_history_trimmed.jsonl "$HISTORY_FILE"
            print_status "Trimmed history.jsonl (was $SIZE)"
        else
            print_status "History file size OK ($SIZE)"
        fi
    else
        print_info "No history.jsonl found"
    fi
}

# ---------------------------------------------------------------------------
# Clean temporary files
# ---------------------------------------------------------------------------
clean_temp_files() {
    echo "Cleaning temporary files..."

    # Clean log files older than 7 days
    find /tmp -maxdepth 1 -type f \( -name "claude*.log" -o -name "cc_*.log" \) -mtime +7 -delete 2>/dev/null || true

    # Clean old exports older than 14 days
    find /tmp -maxdepth 1 -type f \( -name "*.csv" -o -name "*.tsv" \) -mtime +14 -delete 2>/dev/null || true

    print_status "Cleaned temporary files"
}

# ---------------------------------------------------------------------------
# Archive old session documents
# ---------------------------------------------------------------------------
archive_old_sessions() {
    echo "Archiving old session documents..."

    DOCS_DIR="$PROJECT_DIR/docs"
    if [ ! -d "$DOCS_DIR" ]; then
        print_info "No docs/ directory found, skipping"
        return
    fi

    ARCHIVE_DIR="$DOCS_DIR/archive"
    mkdir -p "$ARCHIVE_DIR" 2>/dev/null || true

    ARCHIVED=0
    while IFS= read -r file; do
        if [[ "$file" != *"/archive/"* ]] && [[ -n "$file" ]]; then
            FILENAME=$(basename "$file")
            mv "$file" "$ARCHIVE_DIR/" 2>/dev/null && {
                print_status "Archived: $FILENAME"
                ((ARCHIVED++)) || true
            }
        fi
    done < <(find "$DOCS_DIR" -maxdepth 1 -type f -name "SESSION_*.md" -mtime +30 2>/dev/null)

    if [ $ARCHIVED -eq 0 ]; then
        print_status "No old sessions to archive (all < 30 days)"
    fi
}

# ---------------------------------------------------------------------------
# Context health check
# ---------------------------------------------------------------------------
check_context_health() {
    echo "Checking context health..."

    SKILLS_DIR="$PROJECT_DIR/.claude/skills"
    AGENTS_DIR="$PROJECT_DIR/.claude/agents"
    MAX_SKILL_LINES=500
    MAX_AGENT_LINES=300
    WARNINGS=0

    # Check SKILL.md sizes
    if [ -d "$SKILLS_DIR" ]; then
        while IFS= read -r skill_file; do
            SKILL_NAME=$(echo "$skill_file" | sed "s|$SKILLS_DIR/||;s|/SKILL.md||")
            LINES=$(wc -l < "$skill_file" | tr -d ' ')
            if [ "$LINES" -gt "$MAX_SKILL_LINES" ]; then
                print_warning "Skill '$SKILL_NAME' is $LINES lines (max $MAX_SKILL_LINES) -- split into references/"
                ((WARNINGS++)) || true
            else
                print_status "Skill '$SKILL_NAME': $LINES lines"
            fi
        done < <(find "$SKILLS_DIR" -name "SKILL.md" -type f 2>/dev/null | sort)
    else
        print_info "No .claude/skills/ directory found"
    fi

    # Check agent definition sizes
    if [ -d "$AGENTS_DIR" ]; then
        while IFS= read -r agent_file; do
            AGENT_NAME=$(basename "$agent_file" .md)
            LINES=$(wc -l < "$agent_file" | tr -d ' ')
            if [ "$LINES" -gt "$MAX_AGENT_LINES" ]; then
                print_warning "Agent '$AGENT_NAME' is $LINES lines (max $MAX_AGENT_LINES)"
                ((WARNINGS++)) || true
            else
                print_status "Agent '$AGENT_NAME': $LINES lines"
            fi
        done < <(find "$AGENTS_DIR" -name "*.md" -type f 2>/dev/null | sort)
    else
        print_info "No .claude/agents/ directory found"
    fi

    # Check CLAUDE.md size
    if [ -f "$PROJECT_DIR/CLAUDE.md" ]; then
        CLAUDE_LINES=$(wc -l < "$PROJECT_DIR/CLAUDE.md" | tr -d ' ')
        CLAUDE_SIZE=$(du -sh "$PROJECT_DIR/CLAUDE.md" 2>/dev/null | cut -f1)
        if [ "$CLAUDE_LINES" -gt 400 ]; then
            print_warning "CLAUDE.md is $CLAUDE_LINES lines ($CLAUDE_SIZE) -- consider trimming"
            ((WARNINGS++)) || true
        else
            print_status "CLAUDE.md: $CLAUDE_LINES lines ($CLAUDE_SIZE)"
        fi
    else
        print_info "No CLAUDE.md found"
    fi

    # Calculate total auto-load context estimate
    TOTAL_CONTEXT=0
    if [ -f "$PROJECT_DIR/CLAUDE.md" ]; then
        TOTAL_CONTEXT=$((TOTAL_CONTEXT + $(wc -c < "$PROJECT_DIR/CLAUDE.md" | tr -d ' ')))
    fi
    if [ -d "$AGENTS_DIR" ]; then
        while IFS= read -r f; do
            TOTAL_CONTEXT=$((TOTAL_CONTEXT + $(wc -c < "$f" | tr -d ' ')))
        done < <(find "$AGENTS_DIR" -name "*.md" -type f 2>/dev/null)
    fi
    if [ -d "$SKILLS_DIR" ]; then
        while IFS= read -r f; do
            # Skills with disable-model-invocation don't auto-load
            if ! grep -q "disable-model-invocation: true" "$f" 2>/dev/null; then
                TOTAL_CONTEXT=$((TOTAL_CONTEXT + $(wc -c < "$f" | tr -d ' ')))
            fi
        done < <(find "$SKILLS_DIR" -name "SKILL.md" -type f 2>/dev/null)
    fi

    TOTAL_KB=$((TOTAL_CONTEXT / 1024))
    echo ""
    if [ "$TOTAL_KB" -gt 100 ]; then
        print_warning "Estimated auto-load context: ${TOTAL_KB}KB (target: <100KB)"
        ((WARNINGS++)) || true
    else
        print_status "Estimated auto-load context: ${TOTAL_KB}KB (OK)"
    fi

    if [ "$WARNINGS" -gt 0 ]; then
        echo ""
        print_warning "$WARNINGS context health warnings found"
    else
        echo ""
        print_status "All context health checks passed"
    fi
}

# ---------------------------------------------------------------------------
# Documentation statistics
# ---------------------------------------------------------------------------
show_doc_statistics() {
    echo ""
    echo "Documentation Statistics:"

    DOCS_DIR="$PROJECT_DIR/docs"
    if [ ! -d "$DOCS_DIR" ]; then
        print_info "No docs/ directory"
        return
    fi

    TOTAL_DOCS=$(find "$DOCS_DIR" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    SESSION_DOCS=$(find "$DOCS_DIR" -maxdepth 1 -type f -name "SESSION_*.md" 2>/dev/null | wc -l | tr -d ' ')
    ARCHIVED_DOCS=0
    [ -d "$DOCS_DIR/archive" ] && ARCHIVED_DOCS=$(find "$DOCS_DIR/archive" -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    SKILL_COUNT=0
    [ -d "$PROJECT_DIR/.claude/skills" ] && SKILL_COUNT=$(find "$PROJECT_DIR/.claude/skills" -name "SKILL.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    AGENT_COUNT=0
    [ -d "$PROJECT_DIR/.claude/agents" ] && AGENT_COUNT=$(find "$PROJECT_DIR/.claude/agents" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')

    echo "  Total docs:       $TOTAL_DOCS"
    echo "  Active sessions:  $SESSION_DOCS"
    echo "  Archived:         $ARCHIVED_DOCS"
    echo "  Skills:           $SKILL_COUNT"
    echo "  Agents:           $AGENT_COUNT"
}

# ---------------------------------------------------------------------------
# Rotate security log
# ---------------------------------------------------------------------------
rotate_security_log() {
    echo "Rotating security log..."

    SEC_LOG="$PROJECT_DIR/.claude/cognitive-core/security.log"
    if [ -f "$SEC_LOG" ]; then
        SIZE=$(du -sh "$SEC_LOG" 2>/dev/null | cut -f1)
        FILE_SIZE=$(get_file_size "$SEC_LOG")
        if [ "$FILE_SIZE" -gt 1048576 ]; then
            # Keep last 500 lines, archive the rest
            ARCHIVE_FILE="${SEC_LOG}.$(date +%Y%m%d)"
            cp "$SEC_LOG" "$ARCHIVE_FILE" 2>/dev/null || true
            tail -500 "$SEC_LOG" > "${SEC_LOG}.tmp" && mv "${SEC_LOG}.tmp" "$SEC_LOG"
            print_status "Rotated security.log (was $SIZE, archived to $(basename "$ARCHIVE_FILE"))"
        else
            print_status "Security log size OK ($SIZE)"
        fi

        # Clean old archived logs (>90 days)
        find "$(dirname "$SEC_LOG")" -name "security.log.*" -mtime +90 -delete 2>/dev/null || true
    else
        print_info "No security.log found"
    fi
}

# ---------------------------------------------------------------------------
# Setup cron
# ---------------------------------------------------------------------------
setup_cron() {
    echo "Setting up weekly cleanup cron..."

    SELF_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    CRON_ENTRY="0 13 * * 1 ${SELF_PATH} --all >> /tmp/cc_cleanup.log 2>&1"

    # Check if already installed
    if crontab -l 2>/dev/null | grep -q "context-cleanup.sh"; then
        print_warning "Crontab entry already exists:"
        crontab -l 2>/dev/null | grep "context-cleanup.sh" | while read -r line; do
            echo "    $line"
        done
        return
    fi

    (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
    print_status "Installed weekly cron: $CRON_ENTRY"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
case "${1:-}" in
    --all)
        clean_claude_cache
        clean_claude_history
        clean_temp_files
        archive_old_sessions
        rotate_security_log
        check_context_health
        show_doc_statistics
        ;;
    --health)
        check_context_health
        show_doc_statistics
        ;;
    --cache)
        clean_claude_cache
        ;;
    --history)
        clean_claude_history
        ;;
    --docs)
        archive_old_sessions
        show_doc_statistics
        ;;
    --security)
        rotate_security_log
        ;;
    --setup-cron)
        setup_cron
        ;;
    *)
        echo "Usage: $0 [--all|--health|--cache|--history|--docs|--security|--setup-cron]"
        echo ""
        echo "  --all          Full cleanup + context health check"
        echo "  --health       Context health check only (read-only, safe anytime)"
        echo "  --cache        Clean CLI + MCP caches"
        echo "  --history      Trim Claude history only"
        echo "  --docs         Archive old sessions + show stats"
        echo "  --security     Rotate security log"
        echo "  --setup-cron   Install weekly cleanup crontab entry"
        echo ""
        echo "Crontab (weekly Monday 13:00):"
        echo "  0 13 * * 1 $0 --all >> /tmp/cc_cleanup.log 2>&1"
        exit 0
        ;;
esac

echo ""
echo -e "${GREEN}=== Cleanup Complete ===${NC}"
