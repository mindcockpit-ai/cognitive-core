---
name: project-status
description: Generate project status report from git history, session docs, and work-in-progress state. Shows work streams, blockers, and next actions.
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Grep, Glob
---

# Project Status — Development Progress Report

Generates a project status report by analyzing git history, session documents,
and code state. Reads `CC_MAIN_BRANCH` and `CC_COMMIT_SCOPES` from
`cognitive-core.conf` to classify work streams.

## Arguments

- `$ARGUMENTS` -- optional: `--stream=<scope>`, `--since=7d|30d|90d`

## Live Repository State

### Recent Commits
!`git log --oneline --since="30 days ago" -20 2>/dev/null || echo "No recent commits"`

### Active Branch
!`git branch --show-current 2>/dev/null`

### Uncommitted Work
!`git status --short 2>/dev/null | head -10`

### Session Documents (Recent)
!`ls -t ${CC_SESSION_DOCS_DIR:-docs}/SESSION_*.md 2>/dev/null | head -5`

## Instructions

### Step 1: Gather Data

1. **Git history**: Analyze commits for the requested time window
2. **Session docs**: Read the most recent 2-3 session documents
3. **Planning docs**: Check for active implementation plans
4. **Code state**: Look for untracked files indicating WIP

### Step 2: Classify Work Streams

Group commits by scope (the `(scope)` in conventional commit messages).
Use `CC_COMMIT_SCOPES` from config as the known scope list. Commits without
a recognized scope go into "Other".

### Step 3: Generate Report

```
PROJECT STATUS REPORT
=====================
Generated: [date]
Branch:    [branch]
Period:    [since] to now

WORK STREAM SUMMARY
--------------------
| Stream     | Status   | Last Activity | Next Action   |
|------------|----------|---------------|---------------|
| [scope]    | [status] | [date]        | [next step]   |

Status values:
  COMPLETE - No remaining work
  ACTIVE   - Work in current period
  PAUSED   - Exists but no recent commits
  BLOCKED  - Has documented blockers
  PLANNED  - Has plan doc but no implementation

DETAILED STATUS: [Stream]
--------------------------
Commits in period: N
  - [hash] [message]

UNTRACKED WORK-IN-PROGRESS
----------------------------
[Untracked files suggesting incomplete work]

RECOMMENDED NEXT ACTIONS
-------------------------
1. [Priority action with rationale]
2. [Secondary action]
```

### Step 4: Continuation Points

For each paused or active stream, identify:
- Last session document with relevant context
- Last commit in that stream
- Next planned task from docs
- Any untracked files indicating WIP

## See Also

- `/session-sync` -- Cross-machine synchronization
- `/workflow-analysis` -- Deep analysis of specific features
