---
name: project-board
description: Manage GitHub Project board — issues, sprints, status tracking, and release management. White-labeled template for any project.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob
argument-hint: "[list|create|close|assign|sprint|sprint-plan|triage|board|move] [options]"
---

# Project Board — GitHub Issue & Sprint Management

Manage GitHub Issues and Project board from Claude Code. Provides full lifecycle management from roadmap ideas through sprint execution to completion.

## Configuration

Set these values in your project's `cognitive-core.conf` or replace `{{placeholders}}` after installation:

```bash
CC_GITHUB_REPO="owner/repo"               # e.g., "wolaschka/TIMS"
CC_PROJECT_NUMBER=3                         # GitHub Project number
CC_PROJECT_ID="PVT_xxx"                     # GraphQL Project ID
CC_STATUS_FIELD_ID="PVTSSF_xxx"             # Status field ID
CC_AREA_FIELD_ID="PVTSSF_xxx"               # Area field ID
CC_SPRINT_FIELD_ID="PVTIF_xxx"              # Sprint iteration field ID
```

## Board Structure

### Status (Columns) — Issue Lifecycle

```
Roadmap → Backlog → Todo → In Progress → To Be Tested → Done
```

| Column | Meaning | Sprint Required |
|--------|---------|-----------------|
| **Roadmap** | Feature ideas and future enhancements | No |
| **Backlog** | Accepted work, ready for sprint planning | No |
| **Todo** | Committed to a sprint, not yet started | Yes |
| **In Progress** | Actively being developed | Yes |
| **To Be Tested** | Code complete, needs verification | Yes |
| **Done** | Verified and closed | — |

### Area (Row Grouping)

Customizable per project. Default domains:

| Area | Scope |
|------|-------|
| **CI/CD** | Build pipeline, containers, deployment |
| **Monitoring** | Metrics, alerting, dashboards |
| **Testing** | Test framework, coverage, QA |
| **Security** | Access control, scanning, encryption |
| **Infrastructure** | Servers, backup, networking |

### Sprint (Time-boxed Iterations)

- Default: 14-day iterations
- Issues assigned to sprints should be in Todo or later
- Use `sprint` command to view current sprint progress
- Use `sprint-plan` to assign issues to iterations

## Status Option IDs

Replace with your project's actual IDs after running `setup.sh`:

```
roadmap    → {{STATUS_ROADMAP_ID}}
backlog    → {{STATUS_BACKLOG_ID}}
todo       → {{STATUS_TODO_ID}}
progress   → {{STATUS_PROGRESS_ID}}
testing    → {{STATUS_TESTING_ID}}
done       → {{STATUS_DONE_ID}}
```

## Area Option IDs

```
cicd           → {{AREA_CICD_ID}}
monitoring     → {{AREA_MONITORING_ID}}
testing        → {{AREA_TESTING_ID}}
security       → {{AREA_SECURITY_ID}}
infrastructure → {{AREA_INFRASTRUCTURE_ID}}
```

## Labels

| Type | Values |
|------|--------|
| **Priority** | `priority:p0-critical`, `priority:p1-high`, `priority:p2-medium`, `priority:p3-low` |
| **Area** | `area:cicd`, `area:monitoring`, `area:testing`, `area:security`, `area:infrastructure` |
| **Kind** | `bug`, `enhancement`, `documentation` |

## Commands

Parse the user's arguments to determine which command to run. Default (no args) = `list`.

### `list` (default)

List open issues grouped by priority.

```bash
gh issue list --repo {{CC_GITHUB_REPO}} --state open --label "priority:p0-critical" --json number,title,labels,assignees
gh issue list --repo {{CC_GITHUB_REPO}} --state open --label "priority:p1-high" --json number,title,labels,assignees
gh issue list --repo {{CC_GITHUB_REPO}} --state open --label "priority:p2-medium" --json number,title,labels,assignees
gh issue list --repo {{CC_GITHUB_REPO}} --state open --label "priority:p3-low" --json number,title,labels,assignees
```

Format as priority-grouped table. Support `--area=<area>` and `--state=closed` filters.

### `create`

**Syntax**: `/project-board create "title" [--priority p0|p1|p2|p3] [--area cicd|monitoring|testing|security|infrastructure] [--body "description"]`

1. Create the GitHub issue with labels
2. Add to project board
3. Set Area field
4. Default status: Backlog (unless `--status` specified)

### `close`

**Syntax**: `/project-board close <number> [--comment "reason"]`

1. Close the GitHub issue
2. Update board status to Done

### `assign`

**Syntax**: `/project-board assign <number> <username>`

### `sprint`

Show current sprint progress with completion percentage. Groups items by status.

```
## Sprint: <title> (<date range>)

### In Progress
| # | Title | Area | Assignee |

### To Be Tested
| # | Title | Area | Pending |

### Done
| # | Title | Area |

**Progress**: X/Y items done (Z%)
```

### `sprint-plan`

**Syntax**: `/project-board sprint-plan "<sprint-title>" <issue-numbers...>`

Assign issues to a sprint iteration. Creates the iteration if it doesn't exist.

### `triage`

Find issues without priority or area labels. Analyze and suggest labels for user confirmation.

### `board`

Show board summary with item counts per column.

```
## Project Board
URL: https://github.com/users/<owner>/projects/<number>

| Column         | Count |
|----------------|-------|
| Roadmap        | N     |
| Backlog        | N     |
| Todo           | N     |
| In Progress    | N     |
| To Be Tested   | N     |
| Done           | N     |
```

### `move`

**Syntax**: `/project-board move <number> <roadmap|backlog|todo|progress|testing|done>`

## Error Handling

- If `gh` commands fail with auth errors, suggest: `gh auth refresh -h github.com -s project`
- If an issue number doesn't exist, report it clearly
- Confirm destructive actions (close) when closing more than 2 issues at once

## Integration with Agents

The `project-coordinator` agent can invoke this skill for project planning workflows.
The `solution-architect` agent references the board for feature tracking.
