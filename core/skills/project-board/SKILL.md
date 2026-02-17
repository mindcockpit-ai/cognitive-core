---
name: project-board
description: Manage GitHub Project board — issues, sprints, status tracking, acceptance verification, and release management. White-labeled template for any project.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob
argument-hint: "[list|create|close|assign|sprint|sprint-plan|triage|board|move|verify] [options]"
---

# Project Board — GitHub Issue & Sprint Management

Manage GitHub Issues and Project board from Claude Code. Provides full lifecycle management from roadmap ideas through sprint execution to completion, including acceptance criteria verification.

## Configuration

Set these values in your project's `cognitive-core.conf` or replace `{{placeholders}}` after installation:

```bash
CC_GITHUB_OWNER="owner"                    # e.g., "wolaschka"
CC_GITHUB_REPO="owner/repo"               # e.g., "wolaschka/TIMS"
CC_PROJECT_NUMBER=3                         # GitHub Project number
CC_PROJECT_ID="PVT_xxx"                     # GraphQL Project ID
CC_STATUS_FIELD_ID="PVTSSF_xxx"             # Status field ID
CC_AREA_FIELD_ID="PVTSSF_xxx"               # Area field ID (optional)
CC_SPRINT_FIELD_ID="PVTIF_xxx"              # Sprint iteration field ID (optional)
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

### Status Option IDs

Replace with your project's actual IDs after running `setup.sh`:

```
roadmap    → {{STATUS_ROADMAP_ID}}
backlog    → {{STATUS_BACKLOG_ID}}
todo       → {{STATUS_TODO_ID}}
progress   → {{STATUS_PROGRESS_ID}}
testing    → {{STATUS_TESTING_ID}}
done       → {{STATUS_DONE_ID}}
```

### Area (Row Grouping)

Customizable per project. Default domains:

| Area | Scope | Option ID |
|------|-------|-----------|
| **CI/CD** | Build pipeline, containers, deployment | `{{AREA_CICD_ID}}` |
| **Monitoring** | Metrics, alerting, dashboards | `{{AREA_MONITORING_ID}}` |
| **Testing** | Test framework, coverage, QA | `{{AREA_TESTING_ID}}` |
| **Security** | Access control, scanning, encryption | `{{AREA_SECURITY_ID}}` |
| **Infrastructure** | Servers, backup, networking | `{{AREA_INFRASTRUCTURE_ID}}` |

### Sprint (Time-boxed Iterations)

- Default: 14-day iterations
- Issues assigned to sprints should be in Todo or later
- Use `sprint` command to view current sprint progress
- Use `sprint-plan` to assign issues to iterations

### Labels

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

Format as priority-grouped table:
```
## Open Issues

### P0 — Critical
| # | Title | Area | Assignee |
|---|-------|------|----------|

### P1 — High
...
```

Support `--area=<area>` filter (adds `--label "area:<area>"`) and `--state=closed` (changes to `--state closed --limit 10`).

### `create`

**Syntax**: `/project-board create "title" [--priority p0|p1|p2|p3] [--area cicd|monitoring|testing|security|infrastructure] [--body "description"]`

Map `--priority pN` to labels: p0→`priority:p0-critical`, p1→`priority:p1-high`, p2→`priority:p2-medium`, p3→`priority:p3-low`.
Map `--area` to label `area:<value>`.

1. Create the GitHub issue with labels:
```bash
gh issue create --repo {{CC_GITHUB_REPO}} --title "<title>" --label "<labels>" --body "<body>"
```

2. Add to project board and set Area field:
```bash
ISSUE_ID=$(gh issue view <number> --repo {{CC_GITHUB_REPO}} --json id --jq '.id')
ITEM_ID=$(gh api graphql -f query='mutation { addProjectV2ItemById(input: { projectId: "{{CC_PROJECT_ID}}" contentId: "'$ISSUE_ID'" }) { item { id } } }' --jq '.data.addProjectV2ItemById.item.id')
# Set Area field (map --area value to the matching Area Option ID)
gh api graphql -f query='mutation { updateProjectV2ItemFieldValue(input: { projectId: "{{CC_PROJECT_ID}}" itemId: "'$ITEM_ID'" fieldId: "{{CC_AREA_FIELD_ID}}" value: { singleSelectOptionId: "<AREA_OPTION_ID>" } }) { projectV2Item { id } } }'
```

3. Default status: Backlog (unless `--status` specified)

### `close`

**Syntax**: `/project-board close <number> [number2 ...] [--comment "reason"]`

1. Close the GitHub issue:
```bash
gh issue close <number> --repo {{CC_GITHUB_REPO}} --comment "<comment>"
```

2. Update board status to Done:
```bash
ITEM_ID=$(gh api graphql -f query='query { user(login: "{{CC_GITHUB_OWNER}}") { projectV2(number: {{CC_PROJECT_NUMBER}}) { items(first: 100) { nodes { id content { ... on Issue { number } } } } } } }' --jq '.data.user.projectV2.items.nodes[] | select(.content.number == <N>) | .id')
gh api graphql -f query='mutation { updateProjectV2ItemFieldValue(input: { projectId: "{{CC_PROJECT_ID}}" itemId: "'$ITEM_ID'" fieldId: "{{CC_STATUS_FIELD_ID}}" value: { singleSelectOptionId: "{{STATUS_DONE_ID}}" } }) { projectV2Item { id } } }'
```

### `assign`

**Syntax**: `/project-board assign <number> <username>`

```bash
gh issue edit <number> --repo {{CC_GITHUB_REPO}} --add-assignee <username>
```

### `sprint`

Show current sprint progress. Query the Sprint iteration field, filter items, group by status.

```bash
# Get sprint iterations
gh api graphql -f query='query {
  user(login: "{{CC_GITHUB_OWNER}}") {
    projectV2(number: {{CC_PROJECT_NUMBER}}) {
      field(name: "Sprint") {
        ... on ProjectV2IterationField {
          configuration { iterations { id title startDate duration } }
        }
      }
    }
  }
}'

# List all items with sprint and status
gh project item-list {{CC_PROJECT_NUMBER}} --owner {{CC_GITHUB_OWNER}} --format json
```

Filter items matching current iteration. Group by status:

```
## Sprint: <title> (<date range>)

### In Progress
| # | Title | Area | Assignee |

### To Be Tested
| # | Title | Area | Pending |

### Done
| # | Title | Area |

### Not started
| # | Title | Area |

**Progress**: X/Y items done (Z%)
```

Support `--all` (show all sprints) and `--backlog` (include unassigned items).

### `sprint-plan`

**Syntax**: `/project-board sprint-plan "<sprint-title>" <issue-numbers...>`

Example: `/project-board sprint-plan "Sprint 2" 22 23 24`

1. Get the iteration ID for the sprint title:
```bash
gh api graphql -f query='query {
  user(login: "{{CC_GITHUB_OWNER}}") {
    projectV2(number: {{CC_PROJECT_NUMBER}}) {
      field(name: "Sprint") {
        ... on ProjectV2IterationField {
          configuration { iterations { id title startDate duration } }
        }
      }
    }
  }
}' --jq '.data.user.projectV2.field.configuration.iterations[] | select(.title == "<SPRINT_TITLE>") | .id'
```

2. If sprint doesn't exist, create a new iteration via `updateProjectV2` mutation. New iterations get startDate = previous sprint endDate, same duration (14 days).

3. For each issue, get its project item ID and assign the sprint:
```bash
ITEM_ID=$(gh project item-list {{CC_PROJECT_NUMBER}} --owner {{CC_GITHUB_OWNER}} --format json --jq '.items[] | select(.content.number == <N>) | .id')
gh api graphql -f query='mutation { updateProjectV2ItemFieldValue(input: { projectId: "{{CC_PROJECT_ID}}" itemId: "'$ITEM_ID'" fieldId: "{{CC_SPRINT_FIELD_ID}}" value: { iterationId: "<ITERATION_ID>" } }) { projectV2Item { id } } }'
```

### `triage`

Find issues without priority or area labels and suggest labels.

```bash
gh issue list --repo {{CC_GITHUB_REPO}} --state open --json number,title,labels,body
```

For each issue missing `priority:*` or `area:*` labels, analyze the title and body to suggest appropriate labels. Present suggestions for the user to confirm before applying.

### `board`

Show the project board URL and a summary of items per column.

```bash
gh project item-list {{CC_PROJECT_NUMBER}} --owner {{CC_GITHUB_OWNER}} --format json
```

Output:
```
## Project Board
URL: https://github.com/users/{{CC_GITHUB_OWNER}}/projects/{{CC_PROJECT_NUMBER}}

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

Move an issue to a different board column.

**Syntax**: `/project-board move <number> <roadmap|backlog|todo|progress|testing|done>`

Map column names to Status Option IDs and execute:

```bash
ITEM_ID=$(gh api graphql -f query='query { user(login: "{{CC_GITHUB_OWNER}}") { projectV2(number: {{CC_PROJECT_NUMBER}}) { items(first: 100) { nodes { id content { ... on Issue { number } } } } } } }' --jq '.data.user.projectV2.items.nodes[] | select(.content.number == <N>) | .id')
gh api graphql -f query='mutation { updateProjectV2ItemFieldValue(input: { projectId: "{{CC_PROJECT_ID}}" itemId: "'$ITEM_ID'" fieldId: "{{CC_STATUS_FIELD_ID}}" value: { singleSelectOptionId: "<STATUS_OPTION_ID>" } }) { projectV2Item { id } } }'
```

### `verify`

Verify acceptance criteria for an issue. Delegates to the `acceptance-verification` skill.

**Syntax**: `/project-board verify <number> [--strict] [--dry-run]`

This reads the issue's acceptance criteria, searches the codebase for evidence (commits, code, tests, docs), and posts a structured verification comment on the issue with PASS/PARTIAL/FAIL status per criterion.

See the `acceptance-verification` skill for full workflow details.

## Error Handling

- If `gh` commands fail with auth errors, suggest: `gh auth refresh -h github.com -s project`
- If an issue number doesn't exist, report it clearly
- Confirm destructive actions (close) when closing more than 2 issues at once

## Integration with Agents

The `project-coordinator` agent can invoke this skill for project planning workflows.
The `solution-architect` agent references the board for feature tracking.
The `skill-updater` agent can verify board status during sprint reviews.
