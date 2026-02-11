# Customization Guide

cognitive-core is designed to be extended. This guide covers how to add custom hooks, create project-specific agents, write custom skills, add fitness checks, override framework defaults, and work with the update system.

## Adding Custom Hooks

### Hook Lifecycle Events

| Event | Matcher | Receives | Returns |
|-------|---------|----------|---------|
| SessionStart | `startup\|resume` | Session metadata | `additionalContext` (injected text) |
| PreToolUse | Tool name (e.g., `Bash`) | Tool input JSON | `permissionDecision` (allow/deny) |
| PostToolUse | Tool name (e.g., `Edit\|Write`) | Tool input + output JSON | `additionalContext` (feedback) |
| Notification | Event type (e.g., `compact`) | Notification data | `additionalContext` |

### Creating a Custom Hook

1. Write a bash script in `.claude/hooks/`. Source `_lib.sh`, call `_cc_load_config`, read stdin JSON, and use `_cc_json_pretool_deny` to block or exit 0 to allow. Example pattern:

```bash
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_lib.sh"
_cc_load_config
INPUT=$(cat)
CMD=$(echo "$INPUT" | _cc_json_get ".tool_input.command")
# Your validation logic here
# _cc_json_pretool_deny "reason" to block, or exit 0 to allow
exit 0
```

2. Register in `.claude/settings.json` under the appropriate event and matcher.

### Hook Development Tips

- Read stdin once (it is consumed on first read)
- Use `_cc_json_get` for field extraction (works with or without jq)
- No output = allow; JSON deny output = block
- Test manually: `echo '{"tool_input":{"command":"..."}}' | bash .claude/hooks/my-hook.sh`

## Creating Project-Specific Agents

### Agent Definition Format

Agent definitions are markdown files in `.claude/agents/`. The filename (minus `.md`) becomes the agent name.

```markdown
---
name: api-specialist
model: sonnet
description: REST API design and implementation specialist
---

# API Specialist

You are an API design specialist. [Responsibilities, standards, workflow...]
```

Use `opus` for complex reasoning/orchestration, `sonnet` for focused tasks (review, testing). If you use the hub-and-spoke model, update `.claude/AGENTS_README.md` to include your custom agent:

```markdown
| API design or review | api-specialist |
```

The project-coordinator agent will reference this guide when delegating tasks.

## Writing Custom Skills

Create `.claude/skills/<name>/SKILL.md` with YAML front matter (`name`, `description`, `user-invocable`, `disable-model-invocation`) followed by the skill content. Optionally add a `references/` subdirectory for detailed material.

| Option | Values | Effect |
|--------|--------|--------|
| `user-invocable` | `true` / `false` | Whether the user can invoke via `/skill-name` |
| `disable-model-invocation` | `true` / `false` | If `true`, Claude will not auto-load at session start (manual only) |

Keep auto-load skills under 500 lines. Use `references/` for detail. Total auto-load budget: under 100KB.

## Adding Fitness Checks

Add custom checks to `run_core_checks()` in `cicd/scripts/fitness-check.sh` using `record_check`:

```bash
record_check "Check name" WEIGHT SCORE "optional detail"
# Example: record_check "License file" 5 "$license_score"
```

For language-specific checks, create `language-packs/<lang>/scripts/fitness-check.sh`. Output format: `SCORE DESCRIPTION` on the first line (e.g., `85 All lint checks passed`). The main fitness script discovers and runs pack scripts automatically.

## Overriding Framework Defaults

### cognitive-core.conf

The primary way to customize behavior. All `CC_*` variables can be changed:

```bash
# Override lint command for stricter checking
CC_LINT_COMMAND="ruff check --select ALL \$1"

# Add project-specific safety rules
CC_BLOCKED_PATTERNS="docker\s+system\s+prune npm\s+publish"

# Custom compaction rules
CC_COMPACT_RULES="
1. All API responses use the standard envelope format
2. Database migrations must be reversible
3. Feature flags required for new user-facing features
"
```

### settings.json

The `.claude/settings.json` file controls which hooks are wired to which events. You can:

- Add custom hooks to existing events
- Change matchers to narrow or broaden when hooks trigger
- Add permissions (allow/deny lists for tools)

### CLAUDE.md

The project's `CLAUDE.md` is the primary source of truth for Claude Code's behavior. Customize it extensively with project-specific rules, architecture decisions, and coding standards. The installer generates a scaffold, but you should replace most of the content with your actual project documentation.

## update.sh Behavior with Customized Files

The updater uses SHA-256 checksums to detect modifications:

### Three-Way Comparison

For each tracked file, `update.sh` compares:

1. **Original checksum** (from `version.json` at install time)
2. **Current checksum** (of the file on disk)
3. **Latest checksum** (of the file in the framework repo)

### Decision Matrix

| Original vs. Current | Original vs. Latest | Action |
|---------------------|--------------------|----|
| Same | Same | Skip (unchanged) |
| Same | Different | **Update** (safe, you haven't modified it) |
| Different | Same | Skip (framework hasn't changed) |
| Different | Different | **Preserve** (your modifications kept, warning printed) |

### Files Never Updated

- `settings.json` -- Always treated as user-managed
- `cognitive-core.conf` -- Not tracked in the manifest
- `CLAUDE.md` -- Not tracked in the manifest

### Resolving Skipped Files

When the updater preserves a modified file, it prints a `diff` command you can run to see framework changes. Manually merge the changes, then run `update.sh` again to update the manifest checksums.

To discard all customizations: `./install.sh /path/to/your-project --force`

## Customization Patterns

### Pattern: Hook Chain

Wire multiple hooks to the same event for layered validation:

```json
{
  "PreToolUse": [{
    "matcher": "Bash",
    "hooks": [
      ".claude/hooks/validate-bash.sh",
      ".claude/hooks/check-branch.sh",
      ".claude/hooks/audit-log.sh"
    ]
  }]
}
```

Hooks execute in order. If any hook returns a deny, the command is blocked.

### Pattern: Environment-Specific Config

Maintain separate config files per environment (e.g., `cognitive-core.prod.conf` with `CC_FITNESS_MERGE="95"`).

### Pattern: Team-Wide Defaults

Create `$HOME/.cognitive-core/defaults.conf` as a user-level fallback. This lets developers share common settings without modifying the project config.

### Pattern: Layered Compact Rules

The compact-reminder hook combines three layers: `CC_COMPACT_RULES` (project), language pack `compact-rules.md`, and database pack `compact-rules.md`. All are injected together after compaction.
