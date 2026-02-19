---
name: session-sync
description: Cross-machine sync verification. Checks that agents, skills, MCP config, and project standards are in sync with the remote repository.
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Grep, Glob
catalog_description: Cross-machine sync — verifies agents, skills, and config match remote.
---

# Session Sync — Cross-Machine Development Synchronization

Verifies consistency of Claude Code configuration (agents, skills, MCP servers,
project standards) across development machines using the git remote as the single
source of truth.

## When To Use

- At session start on any machine
- After switching between machines
- Before starting work to verify clean state
- After someone else pushes changes

## Arguments

- `$ARGUMENTS` -- optional flags: `--pull` (auto-pull), `--verbose`

## Live Repository State

### Current Branch and Remote Status
!`git branch --show-current 2>/dev/null`
!`git fetch --all --quiet 2>&1; git status --branch --short 2>/dev/null | head -5`

### Tracked Config Files — Local vs Remote Diff
!`git diff --name-status origin/$(git branch --show-current 2>/dev/null)..HEAD -- .claude/ .mcp.json CLAUDE.md 2>/dev/null || echo "No remote tracking branch found"`

### Remote Changes Not Yet Pulled
!`git diff --name-status HEAD..origin/$(git branch --show-current 2>/dev/null) -- .claude/ .mcp.json CLAUDE.md 2>/dev/null || echo "No remote tracking branch found"`

### Uncommitted Changes in Config
!`git diff --name-status -- .claude/ .mcp.json CLAUDE.md 2>/dev/null`

### Agent Inventory (Local)
!`ls -1 .claude/agents/*.md 2>/dev/null | xargs -I{} basename {} .md`

### Skill Inventory (Local)
!`ls -d .claude/skills/*/SKILL.md 2>/dev/null | sed 's|.claude/skills/||;s|/SKILL.md||'`

### MCP Server Config
!`cat .mcp.json 2>/dev/null | grep -o '"[^"]*":' | tr -d '":' || echo "No .mcp.json found"`

## Instructions

Analyze the live repository state above and produce a **sync report**:

### 1. Branch and Sync Status
- Current branch name, ahead/behind remote, clean or dirty

### 2. Configuration Drift Report

| Category | Files | Status |
|----------|-------|--------|
| Agents | `.claude/agents/*.md` | Synced / Local changes / Remote changes |
| Skills | `.claude/skills/*/SKILL.md` | Synced / Local changes / Remote changes |
| MCP Config | `.mcp.json` | Synced / Local changes / Remote changes |
| Standards | `CLAUDE.md` | Synced / Local changes / Remote changes |

### 3. Inventory Check
List agents and skills. Flag untracked or missing items.

### 4. Action Summary
- If `--pull` passed: execute `git pull` and report changes
- Otherwise: list recommended actions with exact commands

### 5. Health Check
Verify essentials exist: `CLAUDE.md`, `.mcp.json`, `.claude/settings.json`,
expected agents and skills.

## Output Format

```
SESSION SYNC REPORT
===================
Machine: [hostname]
Branch:  [branch] ([ahead/behind])
Status:  [SYNCED | DRIFT DETECTED | ACTION REQUIRED]

CONFIGURATION DRIFT
--------------------
[category]: [status]

INVENTORY
---------
Agents (N): [list]
Skills (N): [list]

ACTIONS
-------
1. [action]
```
