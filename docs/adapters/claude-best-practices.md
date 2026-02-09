# Claude Code Best Practices

Best practices for using Claude Code effectively with cognitive-core skills.

## Commit Standards

### Professional Commits Only

**NO AI/Claude references in commit messages.** Maintain a professional codebase.

### Format

```
type(scope): subject

Types: feat, fix, docs, style, refactor, test, chore
```

### Examples

```bash
# Good
feat(users): add email validation to registration
fix(auth): resolve token expiration issue
docs(api): update endpoint documentation

# Bad - Don't do this
feat: implemented by Claude
fix: AI-assisted bug fix
```

## Context Management

### Weekly Cleanup Script

Run every Monday to maintain optimal performance:

```bash
#!/bin/bash
# cleanup-claude-context.sh

# CLI cache (files older than 7 days)
find ~/.cache/claude -type f -mtime +7 -delete 2>/dev/null

# Debug logs
rm -rf ~/.claude/debug/*.log 2>/dev/null

# Shell snapshots
rm -rf ~/.claude/shell-snapshots/* 2>/dev/null

# History older than 30 days
find ~/.claude/history -type f -mtime +30 -delete 2>/dev/null

# Temporary exports
rm -rf ~/.claude/exports/tmp/* 2>/dev/null

echo "Claude context cleanup complete"
```

### Cron Setup

```bash
# Add to crontab (crontab -e)
0 13 * * 1 /path/to/cleanup-claude-context.sh
```

## Session Best Practices

### Start Fresh

- Start new sessions for unrelated work
- Don't carry over context unnecessarily
- Clear context between major tasks

### Efficient File Reading

- Avoid repeatedly reading files larger than 10KB
- Use targeted reads instead of full-document access
- Let Claude cache file contents within session

### Context Size

- Keep context under ~500KB for optimal performance
- Break complex tasks across multiple sessions
- Summarize findings before context fills

## Skill Integration

### Installing cognitive-core Skills

```bash
# Global skills (all projects)
cp -r cognitive-core/skills/atomic/* ~/.claude/skills/
cp -r cognitive-core/skills/molecular/* ~/.claude/skills/

# Project-specific skills
cp -r cognitive-core/skills/cellular/templates/<your-stack>/* .claude/skills/
```

### Skill Locations

| Scope | Location | Purpose |
|-------|----------|---------|
| Global | `~/.claude/skills/` | Available everywhere |
| Project | `.claude/skills/` | Project-specific |

### Extension Pattern

```yaml
---
name: my-skill
extends: global:base-skill
description: Project-specific extension
---

# Additional instructions...
```

## Tool Usage

### Prefer Specialized Tools

| Task | Use | Not |
|------|-----|-----|
| Read files | `Read` | `cat`, `head`, `tail` |
| Edit files | `Edit` | `sed`, `awk` |
| Search | `Grep` | `grep`, `rg` |
| Find files | `Glob` | `find`, `ls` |

### Parallel Execution

When tasks are independent, request parallel execution:
- "Run these in parallel"
- "Execute simultaneously"

## Performance Tips

### Large Codebases

1. Use `/explore` for codebase navigation
2. Let agents handle multi-file searches
3. Avoid reading entire directories

### Long-Running Tasks

1. Break into smaller subtasks
2. Use TodoWrite for tracking
3. Commit progress incrementally

## See Also

- [cognitive-core README](../../README.md)
- [Skill Format Specification](../../skills/skill-format.yaml)
- [Architecture Examples](../../examples/architecture/)
