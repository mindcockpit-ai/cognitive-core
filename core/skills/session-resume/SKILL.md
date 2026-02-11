---
name: session-resume
description: Auto-loads session context at conversation start. Shows latest session doc, recent git activity, and WIP state for development continuity.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob
---

# Session Resume — Automatic Context Recovery

Auto-loads on every session to maintain development continuity. Reads the latest
session document, recent git history, and work-in-progress state so you never
start cold.

## Live Context (auto-injected)

### Latest Session Document
!`ls -t ${CC_SESSION_DOCS_DIR:-docs}/SESSION_*.md 2>/dev/null | head -1`

### Recent Git Activity
!`git log --oneline -10 2>/dev/null`

### Current Branch Status
!`git branch --show-current 2>/dev/null`
!`git status --short 2>/dev/null | head -5`

### Uncommitted Work-in-Progress
!`git diff --name-only 2>/dev/null | head -10`
!`git ls-files --others --exclude-standard 2>/dev/null | head -10`

## Instructions

### Step 1: Check if Context is Fresh

If you already have detailed knowledge of the current work state (e.g., from
MEMORY.md loaded into the system prompt), skip to Step 4.

### Step 2: Read Latest Session Document

Read the most recent session document shown in the live context above. Extract:
- **Completed work**: What was accomplished last session
- **Continuation point**: Exact next step identified
- **Pending tasks**: Any TODO items or planned work
- **Key decisions**: Architectural or design choices made

### Step 3: Check for Work-in-Progress

Look at uncommitted changes and untracked files from the live context:
- **Modified files**: Work started but not committed
- **Untracked files**: New code being developed
- **Staged changes**: Work ready to commit

### Step 4: Greet and Brief

Provide a brief status when the session starts:

```
Welcome back. Here is where we left off:

Branch: [branch] ([clean/dirty])
Last session: [date] - [brief summary]
Continuation point: [next planned task]
[Any uncommitted work or WIP noted]

Ready to continue with [next task], or would you prefer to work on something else?
```

Keep this brief (3-5 lines). Do not dump the entire session doc.

### Step 5: If User Asks to "Remember" or "Refresh"

If the user explicitly asks to refresh context:
1. Read the full latest session document
2. Read MEMORY.md for persistent cross-session notes
3. Check recent commit messages for work stream context
4. Read any referenced implementation plans
5. Provide a comprehensive summary

## Notes

- This skill auto-loads on every session -- keep it lean
- The `!`command`` sections inject live state at load time
- Session docs follow the pattern `SESSION_*.md` in the configured docs directory
- For cross-machine sync, use `/session-sync` separately
