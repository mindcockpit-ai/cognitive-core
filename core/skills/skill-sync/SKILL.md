---
name: skill-sync
description: Check for and apply cognitive-core framework updates. Compares installed agents, skills, and hooks against the framework source, shows available updates, and safely applies them.
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep
argument-hint: "check | update [--auto] | install <name> | list | status"
featured: true
featured_description: Checksum-based framework updater that preserves your customizations.
---

# Skill Sync — Framework Component Synchronization

Manages the synchronization of cognitive-core components (agents, skills, hooks) between the framework source and the project installation.

## Arguments

- `$ARGUMENTS` — subcommand: `check`, `update`, `install <name>`, `list`, `status`

## Prerequisites

### Version Manifest
!`cat .claude/cognitive-core/version.json 2>/dev/null | head -20 || echo "ERROR: No version.json found. Run install.sh first."`

### Framework Source
!`SOURCE=$(cat .claude/cognitive-core/version.json 2>/dev/null | grep '"source"' | sed 's/.*"source"[[:space:]]*:[[:space:]]*"//;s/".*//' ); if [ -d "$SOURCE" ]; then echo "Framework: $SOURCE"; git -C "$SOURCE" log --oneline -3 2>/dev/null; else echo "ERROR: Framework source not found at $SOURCE"; fi`

### Installed Components
!`echo "=== Agents ==="; ls -1 .claude/agents/*.md 2>/dev/null | xargs -I{} basename {} .md; echo "=== Skills ==="; ls -d .claude/skills/*/SKILL.md 2>/dev/null | sed 's|.claude/skills/||;s|/SKILL.md||'; echo "=== Hooks ==="; ls -1 .claude/hooks/*.sh 2>/dev/null | xargs -I{} basename {} .sh`

## Commands

### `check` — Compare Installed vs Framework

Analyze the live state above plus the version manifest. For each tracked file:

1. Read the `sha256` from `version.json` (original checksum at install/update)
2. Compute current checksum of the installed file
3. Compute checksum of the latest framework source file
4. Classify:

| Current vs Original | Framework vs Original | Status | Action |
|---------------------|----------------------|--------|--------|
| Same | Same | :white_check_mark: Up to date | None |
| Same | Different | :arrow_up: Update available | Safe to update |
| Different | Same | :pencil2: User modified | Skip (no upstream change) |
| Different | Different | :warning: Conflict | Manual review needed |

Also scan for **new framework files** not in the manifest:
- New agents in `core/agents/`
- New skills in `core/skills/`
- New hooks in `core/hooks/`

Output format:
```
SKILL SYNC CHECK
================
Framework: /path/to/cognitive-core (commit abc1234)
Installed: v1.0.0 (updated 2026-02-17)

TRACKED FILES
─────────────
:white_check_mark: .claude/agents/project-coordinator.md — Up to date
:arrow_up: .claude/skills/code-review/SKILL.md — Update available
:pencil2: .claude/hooks/setup-env.sh — User modified (no upstream change)
:warning: .claude/agents/test-specialist.md — CONFLICT (both modified)

NEW IN FRAMEWORK
────────────────
:new: Agent: skill-updater (not installed)
:new: Skill: skill-sync (not installed)

SUMMARY
───────
Up to date: 12 | Updates: 2 | Modified: 1 | Conflicts: 0 | New: 2
```

### `update [--auto]` — Apply Safe Updates

1. Run `check` logic first
2. For files with status "Update available" (current == original, framework != original):
   - Copy framework file to installed location
   - Update checksums in version manifest
   - Make hook scripts executable
3. For conflicts: warn and skip
4. Report results

If `--auto` flag: suppress interactive output, only report errors/conflicts.

Execute update using the framework's updater:
```bash
SOURCE=$(cat .claude/cognitive-core/version.json 2>/dev/null | grep '"source"' | sed 's/.*"source"[[:space:]]*:[[:space:]]*"//;s/".*//');
# Pull latest framework source first
git -C "$SOURCE" pull origin main --quiet 2>/dev/null || true
# Run the checksum-based updater
"$SOURCE/update.sh" "$(pwd)"
```

### `install <name>` — Install a Specific Component

Install a component from the framework that isn't currently installed:

```bash
SOURCE=$(cat .claude/cognitive-core/version.json 2>/dev/null | grep '"source"' | sed 's/.*"source"[[:space:]]*:[[:space:]]*"//;s/".*//');
```

- **Agent**: `cp "$SOURCE/core/agents/<name>.md" .claude/agents/`
- **Skill**: `cp -R "$SOURCE/core/skills/<name>/" .claude/skills/<name>/`
- **Hook**: `cp "$SOURCE/core/hooks/<name>.sh" .claude/hooks/ && chmod +x .claude/hooks/<name>.sh`

After installing, run `"$SOURCE/update.sh"` to update the version manifest.

### `list` — Show All Available Components

Compare what's in the framework vs what's installed:

```
COMPONENT INVENTORY
===================

AGENTS
──────
  [installed] project-coordinator    — Hub orchestrator, delegation
  [installed] code-standards-reviewer — Code review, compliance
  [installed] solution-architect     — Business workflows, architecture
  [available] security-analyst       — Offensive security, pentest
  [available] skill-updater          — Framework synchronization

SKILLS
──────
  [installed] session-resume         — Auto-load session context
  [installed] code-review            — Code review patterns
  [available] skill-sync             — Framework component sync
  [available] ctf-pentesting         — CTF challenge assistance

HOOKS
─────
  [installed] setup-env              — Environment setup at session start
  [installed] validate-bash          — Block dangerous commands
  [available] validate-read          — URL validation for reads
  [available] validate-fetch         — URL validation for web fetches
```

### `status` — Version Manifest and Health

Display comprehensive status:

```
FRAMEWORK STATUS
================
Version:     v1.0.0
Installed:   2026-02-15T10:30:00Z
Last Update: 2026-02-17T14:00:00Z
Source:      /path/to/cognitive-core
Project:     TIMS
Language:    perl
Database:    oracle

HEALTH
──────
Agents:  7 installed, 245 lines total (budget: 300/agent)
Skills:  14 installed, 890 lines total (budget: 500/skill)
Hooks:   5 installed, all checksums valid
Context: ~45KB auto-load estimate (budget: 100KB)

LAST CHECK
──────────
Checked: 2026-02-17 (0 days ago)
Result:  Up to date (no pending updates)
```

## Error Handling

| Error | Recovery |
|-------|----------|
| No `version.json` | Run `install.sh` first to set up cognitive-core |
| Framework source missing | Re-clone cognitive-core or update `source` path in `version.json` |
| Git fetch fails | Check network, continue with local comparison |
| Checksum mismatch | Report as conflict, never auto-resolve |

## See Also

- `check-update.sh` — Automatic session-start update detection
- `update.sh` — Checksum-based safe updater (used by `update` command)
- `health-check.sh` — Context health validation
- `/session-sync` — Cross-machine configuration sync (git-based)
- `skill-updater` agent — Automated orchestration of this skill
