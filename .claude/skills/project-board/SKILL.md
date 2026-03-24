---
name: project-board
description: Manage project board — issues, sprints, status tracking, acceptance verification, and release management. Supports GitHub Projects, Jira, and YouTrack via pluggable providers.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob
argument-hint: "[list|create|close|cancel|assign|sprint|sprint-plan|triage|board|move|verify|approve|blocked|unblock|metrics|propose] [options]"
catalog_description: Project board — issues, sprints, releases, and triage. Supports GitHub, Jira, YouTrack.
---

# Project Board — Issue & Sprint Management

Manage issues and project board from Claude Code. Provides full lifecycle management from roadmap ideas through sprint execution to completion, including acceptance criteria verification. Supports multiple issue tracking backends via pluggable providers.

## Provider Architecture

This skill uses a **provider pattern** to support multiple issue tracking systems through a unified interface. Each provider implements the same CLI contract, so all workflow rules (transitions, guards, formatting) work identically regardless of backend.

### Supported Providers

| Provider | Backend | CLI Tool | Status |
|----------|---------|----------|--------|
| `github` | GitHub Projects + Issues | `gh` | Full support |
| `jira` | Jira Cloud / Data Center | `curl` | Full support |
| `youtrack` | YouTrack Cloud / Standalone | `curl` | Full support |

### Using Provider Scripts

All API operations go through provider-specific scripts in this skill's `providers/` directory:

```bash
# Source config to get provider setting
source ./cognitive-core.conf 2>/dev/null || source ./.claude/cognitive-core.conf

# Find and use the active provider script
PB_PROVIDER="${CC_PROJECT_BOARD_PROVIDER:-github}"
PB_SCRIPT=$(find . -path "*/project-board/providers/${PB_PROVIDER}.sh" -type f 2>/dev/null | head -1)

# All providers share the same CLI interface:
$PB_SCRIPT issue list [--priority P] [--area A] [--state S]
$PB_SCRIPT issue create "title" [--labels L] [--body B]
$PB_SCRIPT issue close <N> [--comment C]
$PB_SCRIPT issue reopen <N>
$PB_SCRIPT issue view <N> [--json fields]
$PB_SCRIPT issue comment <N> "body"
$PB_SCRIPT issue assign <N> <user>
$PB_SCRIPT board summary
$PB_SCRIPT board status <N>
$PB_SCRIPT board move <N> <status_key>
$PB_SCRIPT board add <N>
$PB_SCRIPT board approve <N> [--comment C]
$PB_SCRIPT board blocked <N> [--reason R] [--by N2]
$PB_SCRIPT board unblock <N> [--comment C]
$PB_SCRIPT board metrics [--sprint S]
$PB_SCRIPT sprint list [--all]
$PB_SCRIPT sprint assign "sprint-title" <N> [N2 N3...]
$PB_SCRIPT branch create <N> <type> <slug> [--base B]
$PB_SCRIPT provider info
```

All provider output is JSON for consistent parsing. The SKILL.md handles workflow rules, transition validation, and output formatting — providers handle only API translation.

## Architecture — Clean Separation of Concerns

The board workflow is designed as a **three-layer architecture** that keeps vendor-specific logic isolated:

```
┌─────────────────────────────────────────────────┐
│  Layer 1: SKILL.md (Workflow Rules)             │
│  - Transition matrix, WIP limits, approval gate │
│  - Epic decomposition, closure guard            │
│  - Metrics computation, output formatting       │
│  - 100% vendor-agnostic                         │
├─────────────────────────────────────────────────┤
│  Layer 2: _provider-lib.sh (Shared Contract)    │
│  - CLI interface (issue, board, sprint, branch) │
│  - JSON I/O protocol                            │
│  - Provider validation and routing              │
├─────────────────────────────────────────────────┤
│  Layer 3: providers/*.sh (Vendor Adapters)      │
│  - github.sh → GitHub Projects V2 GraphQL API  │
│  - jira.sh → Jira REST API (Cloud + DC)        │
│  - youtrack.sh → YouTrack REST API              │
│  - Future: azure.sh, linear.sh, shortcut.sh    │
└─────────────────────────────────────────────────┘
```

**Key design rules**:
1. **SKILL.md never calls vendor APIs directly** — all operations go through the provider script
2. **Providers return JSON only** — the skill handles presentation and formatting
3. **Workflow rules live in SKILL.md** — providers do NOT enforce transitions, WIP limits, or approval gates
4. **New providers implement the same CLI contract** — no changes to SKILL.md or _provider-lib.sh needed
5. **Configuration is layered** — `CC_*` variables are provider-agnostic; vendor-specific settings use `CC_GITHUB_*`, `CC_JIRA_*`, `CC_YOUTRACK_*` prefixes

**Adding a new provider** (e.g., Azure DevOps):
1. Create `providers/azure.sh` implementing the CLI contract
2. Add `CC_AZURE_*` configuration variables
3. Map Azure work item states to the 7-column model in a `CC_AZURE_STATUS_MAP`
4. Done — all workflow rules, WIP limits, approval gates, and metrics work automatically

## Configuration

### Provider Selection

```bash
# In cognitive-core.conf:
CC_PROJECT_BOARD_PROVIDER="github"         # github|jira|youtrack
```

### GitHub Provider

```bash
CC_GITHUB_OWNER="owner"                    # e.g., "wolaschka"
CC_GITHUB_REPO="owner/repo"               # e.g., "wolaschka/TIMS"
CC_PROJECT_NUMBER=3                         # GitHub Project number
CC_PROJECT_ID="PVT_xxx"                     # GraphQL Project ID
CC_STATUS_FIELD_ID="PVTSSF_xxx"             # Status field ID
CC_AREA_FIELD_ID="PVTSSF_xxx"               # Area field ID (optional)
CC_SPRINT_FIELD_ID="PVTIF_xxx"              # Sprint iteration field ID (optional)
```

### Jira Provider

```bash
CC_JIRA_URL="https://company.atlassian.net" # Jira Cloud or Data Center URL
CC_JIRA_PROJECT="PROJ"                      # Project key
CC_JIRA_EMAIL="user@company.com"            # Account email (Cloud auth)
CC_JIRA_TOKEN="api-token"                   # API token (Cloud) or PAT (Data Center)
CC_JIRA_AUTH_TYPE="basic"                   # basic (Cloud) or bearer (Data Center)
CC_JIRA_BOARD_ID=""                         # Agile board ID (optional, for sprints)
CC_JIRA_STATUS_MAP="roadmap=To Do|backlog=Backlog|todo=To Do|progress=In Progress|testing=In Review|done=Done|canceled=Canceled"
```

### YouTrack Provider

```bash
CC_YOUTRACK_URL="https://company.youtrack.cloud"  # YouTrack URL
CC_YOUTRACK_PROJECT="PROJ"                  # Project short name
CC_YOUTRACK_TOKEN="perm:token"              # Permanent token
CC_YOUTRACK_AGILE_ID=""                     # Agile board ID (optional, for sprints)
CC_YOUTRACK_STATUS_MAP="roadmap=No State|backlog=Open|todo=To Do|progress=In Progress|testing=To Verify|done=Done|canceled=Canceled"
```

### Governance & Compliance

```bash
CC_REQUIRE_HUMAN_APPROVAL="true"           # Stop at To Be Tested, require /approve
CC_REQUIRE_DIFFERENT_APPROVER="false"      # SOX: approver must differ from assignee
CC_REQUIRED_APPROVERS="1"                  # Number of approvals needed (1 or 2)
```

### WIP Limits (Kanban)

```bash
CC_WIP_LIMIT_PROGRESS="0"                 # Max issues In Progress (0 = unlimited)
CC_WIP_LIMIT_TESTING="0"                  # Max issues in To Be Tested (0 = unlimited)
CC_WIP_LIMIT_TODO="0"                     # Max issues in Todo (0 = unlimited)
```

### Branching Strategy (all providers)

```bash
CC_BRANCH_AUTO_CREATE="false"              # Auto-create branch on move to In Progress
CC_BRANCH_AUTO_CHECKOUT="true"             # Auto-checkout the created branch locally
CC_BRANCH_BASE="main"                      # Base branch for feature/fix branches
CC_BRANCH_HOTFIX_BASE="main"               # Base branch for hotfix branches
CC_BRANCH_DEFAULT_TYPE="feature"           # Default type when no label matches
CC_BRANCH_SLUG_MAX_LENGTH="40"             # Max slug length in branch names
CC_BRANCH_LABEL_MAP="bug=fix|enhancement=feature|documentation=docs"
```

## Project Guard — Cross-Project Contamination Prevention

**CRITICAL**: Before ANY GraphQL mutation that references a `projectId`, verify it matches the configured `CC_PROJECT_ID` exactly. Users often have multiple GitHub projects and field IDs from the wrong project will silently add/move items to unrelated boards.

**Validation rules**:
1. All `projectId` values in mutations MUST equal `CC_PROJECT_ID`
2. All field IDs (`fieldId`) MUST belong to the configured project — they typically contain a substring of the project ID
3. When discovering field IDs via `gh project field-list`, ALWAYS specify `--owner CC_GITHUB_OWNER` and the correct `CC_PROJECT_NUMBER`
4. If a `gh project field-list` response returns IDs that don't match the expected project ID substring, ABORT and report the mismatch

**If wrong project is detected**: Stop immediately and report: "Wrong project detected — field IDs do not match configured project. Aborting to prevent cross-project contamination."

## Board Structure

### Status (Columns) — Issue Lifecycle

```
Roadmap → Backlog → Todo → In Progress → To Be Tested → Done
                                                       ↘ Canceled
```

| Column | Meaning | Sprint Required |
|--------|---------|-----------------|
| **Roadmap** | Feature ideas and future enhancements | No |
| **Backlog** | Accepted work, ready for sprint planning | No |
| **Todo** | Committed to a sprint, not yet started | Yes |
| **In Progress** | Actively being developed | Yes |
| **To Be Tested** | Code complete, needs verification | Yes |
| **Done** | Verified and closed (terminal) | — |
| **Canceled** | Abandoned or deferred (terminal) | — |

### Blocked Flag

Any active issue (Todo, In Progress, To Be Tested) can be flagged as blocked. Blocked is a **label**, not a column — the issue stays in its current column but is visually marked.

**Set blocked**:
```bash
gh issue edit <N> --repo {{CC_GITHUB_REPO}} --add-label "blocked"
gh issue comment <N> --repo {{CC_GITHUB_REPO}} --body "Blocked: <reason>. Waiting on: <dependency>"
```

**Clear blocked**:
```bash
gh issue edit <N> --repo {{CC_GITHUB_REPO}} --remove-label "blocked"
gh issue comment <N> --repo {{CC_GITHUB_REPO}} --body "Unblocked: <resolution>"
```

**Blocked dependency tracking**: Use the convention `Blocked-by: #N` in the blocking comment. When the blocking issue is resolved, the `move` command should prompt to unblock dependent issues.

**Sprint impact**: Blocked items count against WIP limits but should be flagged in sprint reviews as impediments.

### WIP Limits

When configured, the `move` command enforces Work-in-Progress limits per column. This prevents context-switching overload and makes bottlenecks visible.

| Setting | Column | Default |
|---------|--------|---------|
| `CC_WIP_LIMIT_TODO` | Todo | 0 (unlimited) |
| `CC_WIP_LIMIT_PROGRESS` | In Progress | 0 (unlimited) |
| `CC_WIP_LIMIT_TESTING` | To Be Tested | 0 (unlimited) |

**Enforcement**: Before moving an issue into a WIP-limited column, count current items in that column. If at limit:
- **Warn**: "WIP limit reached for In Progress (3/3). Moving this issue will exceed the limit."
- **Allow with override**: The move proceeds but the warning is logged. Use `--force` to suppress the warning.
- **Blocked items excluded**: Issues with the `blocked` label do not count against WIP limits (they are impediments, not active work).

**Recommended limits** (per team member):
- Solo developer: Progress=3, Testing=5
- Small team (2-4): Progress=6, Testing=8
- Enterprise team (5+): Progress=10, Testing=15

### Human Approval Gate

When `CC_REQUIRE_HUMAN_APPROVAL="true"` (default), automated workflows stop at "To Be Tested" instead of auto-closing to "Done". This provides:

- **Governance**: Enterprise compliance (SOX, ISO 27001, ITIL CAB)
- **Trust**: New users review AI work before acceptance
- **Auditability**: Every closure has an explicit human approval with attribution

The coordinator agent posts verification evidence (acceptance criteria table, deployment screenshots, code references) and leaves the issue open for human review. Use `/project-board approve <number>` to accept and close.

Set `CC_REQUIRE_HUMAN_APPROVAL="false"` for fully autonomous workflows.

#### Segregation of Duties (SOX Compliance)

When `CC_REQUIRE_DIFFERENT_APPROVER="true"`:
- The approver MUST be a different user than the issue assignee
- Blocks approval with: "SOX compliance: approver (@user) cannot be the same as assignee (@user). A different team member must approve."
- This enforces ITIL/SOX segregation of duties without requiring external tools

When `CC_REQUIRED_APPROVERS="2"` (dual approval):
- Two different users must approve before the issue can move to Done
- First approval is recorded as a comment; issue remains in To Be Tested
- Second approval triggers the move to Done
- Both approvers must differ from the assignee (when `CC_REQUIRE_DIFFERENT_APPROVER="true"`)

### Status Option IDs

Replace with your project's actual IDs after running `setup.sh`:

```
roadmap    → {{STATUS_ROADMAP_ID}}
backlog    → {{STATUS_BACKLOG_ID}}
todo       → {{STATUS_TODO_ID}}
progress   → {{STATUS_PROGRESS_ID}}
testing    → {{STATUS_TESTING_ID}}
done       → {{STATUS_DONE_ID}}
canceled   → {{STATUS_CANCELED_ID}}
```

## Workflow Transition Rules

Based on Linear/Jira/Kanban best practices. The `move` command MUST enforce these rules.

### Allowed Transitions Matrix

```
FROM → TO         Roadmap  Backlog  Todo  In Progress  To Be Tested  Done  Canceled
─────────────────────────────────────────────────────────────────────────────────────
Roadmap              -       ✓       ✓        -             -          -      ✓
Backlog              ✓       -       ✓        -             -          -      ✓
Todo                 -       ✓       -        ✓             -          -      ✓
In Progress          -       ✓*      ✓*       -             ✓          -      ✓
To Be Tested         -       -       -        ✓*            -          ✓      ✓
Done                 -       -       -        ✓*            ✓*         -      -
Canceled             -       ✓*     ✓*        -             -          -      -
```

`✓` = Allowed | `✓*` = Allowed but warn (deprioritize/reopen/rework) | `-` = Blocked

### Key Rules

1. **Forward flow is primary**: Roadmap/Backlog → Todo → In Progress → To Be Tested → Done
2. **Backward transitions with warning**: To Be Tested → In Progress (rework), Done → In Progress/To Be Tested (reopen), Canceled → Backlog/Todo (reopen)
3. **Canceled reachable from anywhere** except Done
4. **Reopen from Done/Canceled**: Allowed with warning. The `move` command automatically reopens the GitHub issue when moving out of Done or Canceled.
5. **No skipping**: Cannot jump Backlog → In Progress (must pass through Todo first)
6. **Deprioritize/descope**: In Progress → Todo (with warning: "Deprioritized") and In Progress → Backlog (with warning: "Descoped from sprint") are allowed. Sprint assignment is cleared when moving backward.
6. **Reopen syncs GitHub state**: When moving from Done or Canceled to an active column, the `move` command automatically runs `gh issue reopen` to sync the GitHub issue state with the board status.
7. **Auto-sprint assignment**: When moving to Todo, In Progress, or To Be Tested, the `move` command automatically assigns the issue to the current sprint if it has no sprint set. Requires `CC_SPRINT_FIELD_ID` to be configured.
8. **Auto-assignee**: Sprint items must have an owner. When moving to a sprint-required column and the issue has no assignee, auto-assign to the current user (initiator of the change).

### CI Automation

The `project-board-automation.yml` workflow (in `cicd/workflows/`) handles:
- PR opened with `Closes #N` → issue moves to In Progress (from Todo only)
- PR merged → issue moves to **To Be Tested** (when `REQUIRE_HUMAN_APPROVAL=true`) or Done (when false)
- Issue assigned (from Backlog/Roadmap) → moves to Todo
- New issue opened → added to board in Backlog
- Issue reopened → moves to In Progress
- Issue closed → moves to **To Be Tested** and reopens issue (when `REQUIRE_HUMAN_APPROVAL=true`) or Done (when false)
- Issue closed from "To Be Tested" → moves to Done (approval gate: `/project-board approve` path)

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

**Syntax**: `/project-board create "title" [--priority p0|p1|p2|p3] [--area cicd|monitoring|testing|security|infrastructure] [--body "description"] [--plan <path>]`

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

4. Attach implementation plan (if `--plan` provided or `CC_ISSUE_ATTACH_PLAN=true`):

If `--plan <path>` is provided, read the file and post it as a comment on the newly created issue:
```bash
gh issue comment <number> --repo {{CC_GITHUB_REPO}} --body "$(cat <<'PLAN'
## Implementation Plan

$(cat <plan-path>)

---
*Attached by `/project-board create`. Source: `<plan-path>`*
PLAN
)"
```

If no `--plan` flag but `CC_ISSUE_ATTACH_PLAN=true`, check for an active plan file in `~/.claude/plans/`. If exactly one `.md` file exists, attach it automatically. If multiple exist, skip (ambiguous).

### `close`

**Syntax**: `/project-board close <number> [number2 ...] [--comment "reason"]`

**Closure Guard**: If the issue has acceptance criteria (checkbox list in body), run verification FIRST. **NEVER close an issue that has PARTIAL or FAIL criteria.** If any criteria are not PASS, block the close and report the gaps. This prevents premature closure that hides unfinished work.

1. Check for acceptance criteria — if present, verify all are PASS before proceeding
2. Close the GitHub issue:
```bash
gh issue close <number> --repo {{CC_GITHUB_REPO}} --comment "<comment>"
```

3. Update board status to Done:
```bash
ITEMS=$(gh project item-list {{CC_PROJECT_NUMBER}} --owner {{CC_GITHUB_OWNER}} --format json --limit 500)
ITEM_ID=$(echo "$ITEMS" | jq -r --argjson n <N> '.items[] | select(.content.number == $n) | .id')
gh api graphql -f query='mutation { updateProjectV2ItemFieldValue(input: { projectId: "{{CC_PROJECT_ID}}" itemId: "'$ITEM_ID'" fieldId: "{{CC_STATUS_FIELD_ID}}" value: { singleSelectOptionId: "{{STATUS_DONE_ID}}" } }) { projectV2Item { id } } }'
```

### `cancel`

Cancel one or more issues. Moves to Canceled on the board. Requires a reason.

**Syntax**: `/project-board cancel <number> [number2 ...] --reason "why"`

1. Check current status — block if already Done (create new issue instead)
2. Add comment with cancellation reason
3. Close the issue
4. Move to Canceled on the board

```bash
# Check current status first
ITEMS=$(gh project item-list {{CC_PROJECT_NUMBER}} --owner {{CC_GITHUB_OWNER}} --format json --limit 500)
CURRENT=$(echo "$ITEMS" | jq -r --argjson n <N> '.items[] | select(.content.number == $n) | .status')
# Block if Done
if [ "$CURRENT" = "Done" ]; then echo "Cannot cancel a Done issue. Create a new issue instead."; exit 1; fi
# Close with reason
gh issue close <number> --repo {{CC_GITHUB_REPO}} --comment "Canceled: <reason>"
# Set board status to Canceled
ITEM_ID=$(echo "$ITEMS" | jq -r --argjson n <N> '.items[] | select(.content.number == $n) | .id')
gh api graphql -f query='mutation { updateProjectV2ItemFieldValue(input: { projectId: "{{CC_PROJECT_ID}}" itemId: "'$ITEM_ID'" fieldId: "{{CC_STATUS_FIELD_ID}}" value: { singleSelectOptionId: "{{STATUS_CANCELED_ID}}" } }) { projectV2Item { id } } }'
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
| Canceled       | N     |
```

### `move`

Move an issue to a different board column. **Enforces transition rules.**

**Syntax**: `/project-board move <number> <roadmap|backlog|todo|progress|testing|done|canceled>`

Map column names to Status Option IDs and execute.

**Before moving, check the transition is allowed:**

```bash
# 1. Get current status
ITEMS=$(gh project item-list {{CC_PROJECT_NUMBER}} --owner {{CC_GITHUB_OWNER}} --format json --limit 500)
CURRENT=$(echo "$ITEMS" | jq -r --argjson n <N> '.items[] | select(.content.number == $n) | .status')
TARGET="<target_status>"

# 2. Validate transition against allowed matrix
# Allowed transitions (from → to):
#   Roadmap      → Backlog, Todo, Canceled
#   Backlog      → Roadmap, Todo, Canceled
#   Todo         → Backlog, In Progress, Canceled
#   In Progress  → Backlog (descope), Todo (deprioritize), To Be Tested, Canceled
#   To Be Tested → In Progress (rework), Done, Canceled
#   Done         → In Progress (reopen), To Be Tested (reopen)
#   Canceled     → Backlog (reopen), Todo (reopen)

# 3. If transition is blocked, show error with allowed targets
# Example: "Cannot move from Backlog to In Progress. Allowed: Roadmap, Todo, Canceled"

# 4. If To Be Tested → In Progress, warn: "Rework: moving back to In Progress"
#    If Done → *, warn: "Reopening: moving from Done back to active"
#    If Canceled → *, warn: "Reopening: moving from Canceled back to active"

# 5. If moving FROM Done or Canceled, reopen the GitHub issue first:
#    gh issue reopen <N> --repo {{CC_GITHUB_REPO}}

# 6. Execute the move
ITEM_ID=$(echo "$ITEMS" | jq -r --argjson n <N> '.items[] | select(.content.number == $n) | .id')
gh api graphql -f query='mutation { updateProjectV2ItemFieldValue(input: { projectId: "{{CC_PROJECT_ID}}" itemId: "'$ITEM_ID'" fieldId: "{{CC_STATUS_FIELD_ID}}" value: { singleSelectOptionId: "<STATUS_OPTION_ID>" } }) { projectV2Item { id } } }'

# 7. Auto-assign to current sprint if target is sprint-required (Todo, In Progress, To Be Tested)
#    and the issue is NOT already in a sprint. Only applies when CC_SPRINT_FIELD_ID is configured.
if echo "todo progress testing" | grep -qw "$TARGET_KEY"; then
    CURRENT_SPRINT=$(echo "$ITEMS" | jq -r --argjson n <N> '.items[] | select(.content.number == $n) | .sprint // empty')
    if [ -z "$CURRENT_SPRINT" ] && [ -n "{{CC_SPRINT_FIELD_ID}}" ]; then
        # Get current sprint iteration ID (the one whose date range includes today)
        ITERATION_ID=$(gh api graphql -f query='query {
          user(login: "{{CC_GITHUB_OWNER}}") {
            projectV2(number: {{CC_PROJECT_NUMBER}}) {
              field(name: "Sprint") {
                ... on ProjectV2IterationField {
                  configuration { iterations { id title startDate duration } }
                }
              }
            }
          }
        }' --jq '[.data.user.projectV2.field.configuration.iterations[] | select((.startDate | strptime("%Y-%m-%d") | mktime) <= now and ((.startDate | strptime("%Y-%m-%d") | mktime) + (.duration * 86400)) > now)] | .[0].id')

        if [ -n "$ITERATION_ID" ]; then
            gh api graphql -f query='mutation { updateProjectV2ItemFieldValue(input: { projectId: "{{CC_PROJECT_ID}}" itemId: "'$ITEM_ID'" fieldId: "{{CC_SPRINT_FIELD_ID}}" value: { iterationId: "'$ITERATION_ID'" } }) { projectV2Item { id } } }'
            echo "Auto-assigned to current sprint"
        fi
    fi

    # 8. Auto-assign to current user if issue has no assignee
    #    Sprint items must have an owner — default to the initiator of the change
    ASSIGNEES=$(gh issue view <N> --repo {{CC_GITHUB_REPO}} --json assignees --jq '.assignees | length')
    if [ "$ASSIGNEES" = "0" ]; then
        CURRENT_USER=$(gh api user --jq '.login')
        gh issue edit <N> --repo {{CC_GITHUB_REPO}} --add-assignee "$CURRENT_USER"
        echo "Auto-assigned to $CURRENT_USER"
    fi
fi

# 9. Auto-create feature branch when moving to In Progress
#    Only runs when CC_BRANCH_AUTO_CREATE is "true" in cognitive-core.conf
if [ "$TARGET_KEY" = "progress" ] && [ "{{CC_BRANCH_AUTO_CREATE}}" = "true" ]; then
    # Get issue details for branch naming
    ISSUE_JSON=$(gh issue view <N> --repo {{CC_GITHUB_REPO}} --json title,labels)
    ISSUE_TITLE=$(echo "$ISSUE_JSON" | jq -r '.title')
    ISSUE_LABELS=$(echo "$ISSUE_JSON" | jq -r '[.labels[].name] | join(",")')

    # Determine branch type from labels using CC_BRANCH_LABEL_MAP
    # Format: "bug=fix|enhancement=feature|documentation=docs"
    # Falls back to CC_BRANCH_DEFAULT_TYPE (default: "feature")
    BRANCH_TYPE="{{CC_BRANCH_DEFAULT_TYPE}}"
    IFS='|' read -ra LABEL_PAIRS <<< "{{CC_BRANCH_LABEL_MAP}}"
    for pair in "${LABEL_PAIRS[@]}"; do
        LABEL="${pair%%=*}"
        TYPE="${pair##*=}"
        if echo "$ISSUE_LABELS" | grep -q "$LABEL"; then
            BRANCH_TYPE="$TYPE"
            break
        fi
    done

    # Hotfix override: P0 critical bugs branch from hotfix base
    BASE_BRANCH="{{CC_BRANCH_BASE}}"
    if echo "$ISSUE_LABELS" | grep -q "priority:p0-critical" && [ "$BRANCH_TYPE" = "fix" ]; then
        BRANCH_TYPE="hotfix"
        BASE_BRANCH="{{CC_BRANCH_HOTFIX_BASE}}"
        echo "P0 Critical — creating hotfix branch from $BASE_BRANCH"
    fi

    # Generate slug: lowercase, non-alphanum to hyphen, collapse, trim
    SLUG=$(echo "$ISSUE_TITLE" | tr '[:upper:]' '[:lower:]' | \
           sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//' | \
           cut -c1-{{CC_BRANCH_SLUG_MAX_LENGTH}})
    BRANCH_NAME="${BRANCH_TYPE}/<N>-${SLUG}"

    # Check if a branch already exists for this issue
    EXISTING=$(gh issue develop <N> --repo {{CC_GITHUB_REPO}} --list 2>/dev/null | head -1)
    if [ -n "$EXISTING" ]; then
        echo "Branch already exists: $EXISTING"
        if [ "{{CC_BRANCH_AUTO_CHECKOUT}}" = "true" ]; then
            git fetch origin && git checkout "$EXISTING"
            echo "Checked out existing branch: $EXISTING"
        fi
    else
        # Create linked branch via gh issue develop (links branch to issue in GitHub UI)
        CHECKOUT_FLAG=""
        if [ "{{CC_BRANCH_AUTO_CHECKOUT}}" = "true" ]; then
            CHECKOUT_FLAG="--checkout"
        fi
        gh issue develop <N> \
            --repo {{CC_GITHUB_REPO}} \
            --base "$BASE_BRANCH" \
            --name "$BRANCH_NAME" \
            $CHECKOUT_FLAG
        echo "Created branch: $BRANCH_NAME (from $BASE_BRANCH)"
    fi
fi
```

### Branch Naming Convention

When `CC_BRANCH_AUTO_CREATE="true"`, moving to In Progress auto-creates branches using `gh issue develop`:

```
<type>/<issue-number>-<kebab-case-slug>
```

| Type | When | Base Branch |
|------|------|-------------|
| `feature/` | `enhancement` label or default | `CC_BRANCH_BASE` |
| `fix/` | `bug` label | `CC_BRANCH_BASE` |
| `hotfix/` | `bug` + `priority:p0-critical` | `CC_BRANCH_HOTFIX_BASE` |
| `docs/` | `documentation` label | `CC_BRANCH_BASE` |

**Label mapping** is configurable via `CC_BRANCH_LABEL_MAP` (pipe-separated `label=type` pairs).

**Hotfix workflow**: After merging hotfix to production branch, also merge to development branch to keep branches in sync.

**Disabling**: Set `CC_BRANCH_AUTO_CREATE="false"` (default) to skip branch creation entirely.

### `verify`

Verify acceptance criteria for an issue. Delegates to the `acceptance-verification` skill.

**Syntax**: `/project-board verify <number> [--strict] [--dry-run]`

This reads the issue's acceptance criteria, searches the codebase for evidence (commits, code, tests, docs), and posts a structured verification comment on the issue with PASS/PARTIAL/FAIL status per criterion.

See the `acceptance-verification` skill for full workflow details.

#### Epic Verification (Recursive)

When `verify` is called on an **epic** (an issue containing a task list with `- [ ] #N` references), it performs **recursive verification**:

1. **Detect epic**: Parse the issue body for task list items matching `- [ ] #N` or `- [x] #N`
2. **Verify each sub-issue**: Run `acceptance-verification` on every referenced sub-issue
3. **Aggregate results**: Collect PASS/PARTIAL/FAIL status from all sub-issues
4. **Verify epic criteria**: Then verify the epic's own acceptance criteria
5. **Post consolidated comment** on the epic:

```
## Epic Verification

### Sub-Issue Status

| # | Title | Criteria | Passed | Status |
|---|-------|----------|--------|--------|
| #87 | Batch processing skill | 5 | 5 | PASS |
| #88 | Shared MCP server | 6 | 4 | PARTIAL |
| #89 | Information provenance | 4 | 4 | PASS |
| #90 | Session management | 3 | 3 | PASS |

### Epic Criteria

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | All sub-issues completed | PARTIAL | #88 has 2 open criteria |
| 2 | Tests pass (525+) | PASS | 13/13 suites, 530 tests |

### Summary
- **Sub-issues**: 3/4 PASS, 1 PARTIAL
- **Epic criteria**: 1/2 PASS, 1 PARTIAL
- **Overall**: PARTIAL — #88 blocks epic closure
```

**Epic closure rule**: An epic can only be closed when ALL sub-issues are PASS AND all epic-level criteria are PASS. If any sub-issue is PARTIAL or FAIL, the epic is blocked.

### `approve`

Human approval gate. Moves an issue from "To Be Tested" to "Done" after reviewing verification evidence. Only works when `CC_REQUIRE_HUMAN_APPROVAL="true"` (default).

**Syntax**: `/project-board approve <number> [--comment "reason"]`

**Guards**:
1. Issue must be in "To Be Tested" status — blocks otherwise
2. Issue must have at least one verification comment (evidence exists)
3. Approval is attributed to the current GitHub user
4. **SOX guard** (when `CC_REQUIRE_DIFFERENT_APPROVER="true"`): Approver must differ from issue assignee. Block with: "SOX compliance: approver cannot be the same as assignee."
5. **Dual approval** (when `CC_REQUIRED_APPROVERS="2"`): First approval is recorded as comment, issue stays in To Be Tested. Second approval from a different user triggers Done.

**Flow**:
1. Verify issue is in "To Be Tested"
2. Verify evidence comment exists
3. Check SOX guard (if enabled): compare approver with assignee
4. Check dual approval (if enabled): count existing approval comments
5. Close the issue with "Approved by @username" comment
6. Move to Done on the board

### `blocked`

Flag an issue as blocked by an impediment.

**Syntax**: `/project-board blocked <number> --reason "why" [--by #N]`

1. Add `blocked` label to the issue
2. Post comment: "Blocked: <reason>. Waiting on: #N" (if `--by` specified)
3. Issue stays in its current column — blocked is a flag, not a status

### `unblock`

Remove blocked flag from an issue.

**Syntax**: `/project-board unblock <number> [--comment "resolution"]`

1. Remove `blocked` label
2. Post comment: "Unblocked: <resolution>"

### `metrics`

Show agile health metrics for the current or specified sprint.

**Syntax**: `/project-board metrics [--sprint "Sprint N"] [--since 30d]`

Computes from issue event history:

```
AGILE METRICS
=============
Sprint: Sprint 7 (2026-03-04 → 2026-03-18)

THROUGHPUT
  Completed:     8 issues
  Canceled:      1 issue
  Carried over:  2 issues (from previous sprint)

CYCLE TIME (start → done)
  Average:       3.2 days
  Median:        2.5 days
  P95:           7.1 days
  By priority:
    P1-high:     1.8 days (3 issues)
    P2-medium:   3.5 days (4 issues)
    P3-low:      5.2 days (1 issue)

LEAD TIME (created → done)
  Average:       8.4 days
  Median:        6.0 days

WIP HEALTH
  Current In Progress:  3 (limit: 6)
  Current To Be Tested: 2 (limit: 8)
  Blocked items:        1 (#45 — waiting on external API)

FLOW EFFICIENCY
  Active time:   62% (time in Progress + Testing)
  Wait time:     38% (time in Backlog + Todo)
```

**Data sources**:
- Issue creation timestamps (lead time start)
- Board transition events via issue timeline API (cycle time)
- Current board state via `gh project item-list`
- Blocked label for impediment tracking

**Comparison**: When `--since` spans multiple sprints, show trend:

```
SPRINT TRENDS
  Sprint 5:  6 done, avg cycle 4.1d
  Sprint 6:  7 done, avg cycle 3.8d
  Sprint 7:  8 done, avg cycle 3.2d  ← improving
```

### `propose`

Generate a structured implementation prompt for an issue. Reads the issue, analyzes codebase impact, selects agents, loads conventions, and produces a ready-to-use Claude Code prompt.

**Syntax**: `/project-board propose <number> [--mode=technical|business] [--all] [--dry-run]`

**Options**:

- `--mode=technical`: (default) Developer prompt — agents, file impact, code conventions
- `--mode=business`: Stakeholder prompt — business value, governance, roadmap, risk
- `--all`: Include gitignored files in codebase scan (e.g., build artifacts, vendor)
- `--dry-run`: Show analysis without posting comment

**Template source**: `docs/recipes/recipe-multi-agent-implementation.md`

**Technique basis** (peer-reviewed):

- Least-to-Most decomposition for acceptance criteria (Zhou et al. 2022, ICLR 2023)
- XML structuring for Claude (Anthropic official documentation)
- Position-aware layout: critical constraints at beginning AND end (Liu et al. 2024, TACL)
- Direct imperative mood, no politeness tokens (Yin et al. 2024)
- Specification quality over prompt cleverness (Della Porta et al. 2025, EASE)

#### Step 1: Read the Issue

```bash
ISSUE_JSON=$($PB_SCRIPT issue view <N> --json "title,body,labels,assignees,state")
TITLE=$(echo "$ISSUE_JSON" | jq -r '.title')
BODY=$(echo "$ISSUE_JSON" | jq -r '.body')
LABELS=$(echo "$ISSUE_JSON" | jq -r '[.labels[].name] | join(",")')
STATE=$(echo "$ISSUE_JSON" | jq -r '.state')

# Warn if issue is not open
if [ "$STATE" != "OPEN" ]; then
  echo "Warning: Issue #<N> is $STATE. Generating prompt anyway — verify this is intended."
fi
```

All providers return equivalent JSON via the `issue view` contract.

**Extract acceptance criteria**: Parse checkbox items from the issue body:

```bash
CRITERIA=$(echo "$BODY" | grep -cE '^[[:space:]]*-[[:space:]]*\[[ x]\]')
```

#### Step 2: Complexity Dispatch

Determine prompt strategy from acceptance criteria count:

| Criteria Count | Complexity | Prompt Strategy |
|----------------|-----------|-----------------|
| 0 | Unknown | Confidence: LOW — note "acceptance criteria needed" |
| 1-3 | Simple (S) | Direct task, no decomposition, minimal agent list |
| 4-7 | Moderate (M) | Least-to-Most decomposition, agent suggestions |
| 8+ | Complex (L) | Phase boundaries auto-proposed, full agent team, scope guards |

#### Step 3: Analyze Codebase Impact

Search for files and patterns mentioned in the issue title, body, and labels:

```bash
# Extract keywords from issue title and body (filenames, paths, function names)
# Search codebase for affected files
AFFECTED_FILES=$(grep -rl "<keyword>" --include="*.md" --include="*.sh" --include="*.py" . 2>/dev/null | head -20)

# If --all flag: add --no-ignore to include gitignored files
# grep -rl --no-ignore "<keyword>" . 2>/dev/null

# Count affected files for complexity adjustment
FILE_COUNT=$(echo "$AFFECTED_FILES" | grep -c '.' || echo 0)
```

If `FILE_COUNT > 10` AND complexity is not already Complex, upgrade to Complex (L).

#### Step 4: Select Agents

Map issue labels and affected file types to agents:

| Signal | Agent | Reason |
|--------|-------|--------|
| `security` label OR `hooks/` files touched | `@security-analyst` | Security review required |
| `area:skills` OR `area:agents` label | `@code-standards-reviewer` | Framework convention compliance |
| Acceptance criteria mention "test" | `@test-specialist` | Test creation/verification needed |
| `research` label OR `docs/research/` files | `@research-analyst` | External research required |
| Database files or SQL patterns in body | `@database-specialist` | Database changes |
| Architecture decisions or new workflows | `@solution-architect` | Design review needed |
| `area:cicd` label | `@project-coordinator` | CI/CD pipeline coordination |

Always include `@code-standards-reviewer` for final review regardless of other selections.

#### Step 5: Load Conventions

Read project standards from:

1. `CLAUDE.md` — commit format, naming rules, encoding standards
2. `cognitive-core.conf` — language, lint command, test command, architecture

```bash
# Extract key conventions
CC_LANGUAGE=$(grep 'CC_LANGUAGE=' cognitive-core.conf | cut -d'"' -f2)
CC_LINT_COMMAND=$(grep 'CC_LINT_COMMAND=' cognitive-core.conf | cut -d'"' -f2)
CC_TEST_COMMAND=$(grep 'CC_TEST_COMMAND=' cognitive-core.conf | cut -d'"' -f2)
CC_COMMIT_FORMAT=$(grep 'CC_COMMIT_FORMAT=' cognitive-core.conf | cut -d'"' -f2)
```

#### Step 6: Search for Related Evidence

Search `workspace/reports/` and `docs/research/` for references to the issue number or keywords from the title:

```bash
# Search by issue number
grep -rlE "#<N>([^0-9]|$)" workspace/reports/ docs/research/ 2>/dev/null
# Search by title keywords
grep -rl "<keyword>" workspace/reports/ docs/research/ 2>/dev/null
```

Include discovered evidence as context references in the generated prompt.

#### Step 7: Generate Prompt

Build the implementation prompt following the structure from `docs/recipes/recipe-multi-agent-implementation.md`. Apply all five research-backed techniques.

**Prompt template** (under 400 words of instruction, reference material excluded):

```text
Implement GitHub issue #<N>: <TITLE>

<scope>
[IF COMPLEX: "Phase 1 only — <phase_description>"]

[Numbered list derived from acceptance criteria using Least-to-Most decomposition:
 each item builds on the previous, ordered from foundational to integrative]
</scope>

<constraints>
[CRITICAL — positioned first per Liu et al. 2024 "Lost in the Middle":]
- Follow existing <ARCHITECTURE_PATTERN> architecture
- <KEY_CONSTRAINT_FROM_ISSUE>
[Additional constraints from CLAUDE.md and cognitive-core.conf:]
- Commit format: <CC_COMMIT_FORMAT>
- Language: <CC_LANGUAGE>
[Phase boundaries if Complex:]
- Do NOT implement <PHASE_2_ITEMS> (Phase 2)
- Do NOT implement <PHASE_3_ITEMS> (Phase 3)
[Total instruction word count target: under 400 words]
</constraints>

<agents>
[Selected agents with one-line justification each:]
- @<agent>: <reason based on label/file match>
</agents>

<acceptance_criteria>
[Verbatim checkbox list from issue body — preserves user's exact wording]
</acceptance_criteria>

<context>
[Auto-discovered evidence references:]
- Research: <path> (if found)
- Related issues: <links> (if referenced in body)
- Affected files: <list from Step 3>
</context>

<after_implementation>
[Verification steps — reiterate key constraints per position-aware layout:]
- Run: <CC_TEST_COMMAND> (if configured)
- Run: <CC_LINT_COMMAND> (if configured)
- Verify: <CRITICAL_CONSTRAINT_REPEATED>
- Commit to <branch>, push, open PR
</after_implementation>
```

**Prompt quality rules** (machine-validatable):

1. Total instruction word count < 400 (excludes quoted acceptance criteria and context references)
2. Imperative mood throughout — no "please", "could you", "it would be nice"
3. `<constraints>` section appears BOTH before `<context>` AND key constraints reiterated in `<after_implementation>`
4. Every acceptance criterion from the issue appears in `<acceptance_criteria>`
5. At least one agent in `<agents>` section (minimum: `@code-standards-reviewer`)

#### Step 7b: Business Mode Prompt (when `--mode=business`)

When `--mode=business` is specified, skip the technical prompt template (Step 7) and generate a stakeholder-oriented summary instead. This mode replaces code-level detail with business context, governance implications, and roadmap positioning.

**What changes compared to technical mode**:
- Steps 3-5 (codebase impact, agent selection, convention loading) are **skipped** — not relevant for stakeholders
- Step 6 (evidence discovery) is **kept** — business decisions need supporting research
- Complexity dispatch (Step 2) maps to **effort estimation** instead of phase boundaries

**Business prompt template**:

```text
Issue #<N>: <TITLE>

## Business Value

[Why this matters — derive from issue body, labels, and linked epic:]
- Problem being solved (from issue Summary/Problem section)
- Who benefits (users, team, customers, compliance)
- What happens if we don't do this (risk of inaction)

## Roadmap Position

- Status: <CURRENT_BOARD_STATUS> (Roadmap/Backlog/Todo/In Progress)
- Priority: <PRIORITY_LABEL> — <justification from labels or epic>
- Size: <SIZE_LABEL> (<criteria_count> acceptance criteria)
- Epic: <PARENT_EPIC_TITLE> (if issue body references an epic)
- Dependencies: <issues referenced in body with "blocked by" or "depends on">

## Governance & Compliance

[Auto-populated from labels — include section only if relevant signals exist:]

IF labels contain "eu-ai-act" or "compliance" or "needs-human-review":
  - Regulatory driver: <derived from label and issue body>
  - Human review required: Yes/No (from "needs-human-review" label)
  - Compliance area: <e.g., Art. 50 transparency, Art. 9 risk management>

IF labels contain "security" or area:security:
  - Security impact: <derived from issue body>
  - Review gate: Security analyst sign-off required before merge

IF issue is size:XL or epic:
  - Phased delivery: <number of phases from acceptance criteria grouping>
  - Approval checkpoints: After each phase

[If no governance signals detected, omit this section entirely.]

## Success Criteria (Non-Technical)

[Rewrite acceptance criteria in business language:]
- Instead of "validate-bash.sh handles edge case" → "Safety hooks cover all identified scenarios"
- Instead of "tests pass in CI" → "Automated quality checks confirm correctness"
- Instead of "SKILL.md updated" → "Documentation reflects new capability"

[Group criteria by outcome, not by file or function:]
1. Capability delivered: [what users/stakeholders can now do]
2. Quality assured: [how we know it works]
3. Documentation complete: [what's updated for future reference]

## Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| [Derived from issue Risk section if present] | | | |
| Scope creep (if Complex/L) | Medium | High | Phased delivery with gates |
| [If no risks in issue body] | — | — | "No explicit risks identified — review with team" |

## Evidence & Research

[From Step 6 evidence discovery:]
- <path_to_research_paper> (if found)
- <related_issue_links> (if referenced)
- "No supporting research found" (if none discovered)

## Recommendation

[One paragraph: should this proceed, be reprioritized, or needs more definition?]
- HIGH confidence: "Ready for implementation. Acceptance criteria are clear, priority is justified."
- MEDIUM confidence: "Proceed with clarification needed on: <missing_areas>"
- LOW confidence: "Not ready — acceptance criteria missing. Define success criteria before starting."
```

**Business mode quality rules**:

1. No file paths, function names, or code snippets in the output
2. No agent names (replace with role descriptions: "security review" not "@security-analyst")
3. Acceptance criteria rewritten in outcome language, not implementation language
4. Governance section only appears when compliance/security labels are present
5. Recommendation section always present — gives a clear go/no-go signal

#### Step 8: Confidence Scoring

| Score | Condition |
|-------|-----------|
| **HIGH** | Has acceptance criteria (>0) AND has labels AND scope is clear (body > 100 chars) |
| **MEDIUM** | Has acceptance criteria but missing labels OR body is short |
| **LOW** | No acceptance criteria (criteria count = 0) — append note: "Acceptance criteria needed — add checkbox items to the issue body before implementing" |

#### Step 9: Post as Issue Comment

Post the generated prompt as a comment on the issue. Format varies by provider and mode.

**Common metadata block** (used by all providers):

```text
if [ "$MODE" = "business" ]; then
  LABEL="Business Summary"
  TECHNIQUES="Stakeholder-oriented analysis, governance-first framing"
else
  LABEL="Implementation Prompt"
  TECHNIQUES="Zhou 2022 (decomposition), Liu 2024 (position), Yin 2024 (imperative), Della Porta 2025 (specification)"
fi

METADATA_BLOCK="$LABEL — Generated by /project-board propose

Generated:  <TIMESTAMP_UTC>
Mode:       <technical|business>
Confidence: <HIGH/MEDIUM/LOW>
Complexity: <S/M/L> (<criteria_count> criteria, <file_count> files)
Techniques: $TECHNIQUES"
```

**Provider-specific formatting**:

```bash
PB_PROVIDER=$(grep 'CC_BOARD_PROVIDER=' cognitive-core.conf 2>/dev/null | cut -d'"' -f2)
PB_PROVIDER="${PB_PROVIDER:-github}"

case "$PB_PROVIDER" in
  github)
    # GitHub supports <details> for collapsible sections
    COMMENT_BODY=$(cat <<COMMENT
<details>
<summary>$LABEL — Generated by /project-board propose</summary>

$METADATA_BLOCK

## Prompt

<THE_GENERATED_PROMPT>

</details>
COMMENT
    )
    ;;
  jira)
    # Jira ADF renders markdown in comments but not HTML tags.
    # Use a heading + code block to preserve prompt formatting.
    COMMENT_BODY=$(cat <<COMMENT
h2. Implementation Prompt — Generated by /project-board propose

$METADATA_BLOCK

{code:title=Prompt|language=none}
<THE_GENERATED_PROMPT>
{code}
COMMENT
    )
    ;;
  youtrack)
    # YouTrack supports markdown in comments but not <details> HTML.
    # Use a header + fenced code block.
    COMMENT_BODY=$(cat <<COMMENT
## Implementation Prompt — Generated by /project-board propose

$METADATA_BLOCK

\`\`\`
<THE_GENERATED_PROMPT>
\`\`\`
COMMENT
    )
    ;;
esac

$PB_SCRIPT issue comment <N> "$COMMENT_BODY"
```

If `--dry-run` is specified, display the prompt in the terminal instead of posting.

#### Provider Support

| Provider | Status | Notes |
|----------|--------|-------|
| GitHub | Full | Collapsible `<details>` with markdown metadata table |
| Jira | Full | Jira wiki heading + `{code}` block for prompt formatting |
| YouTrack | Full | Markdown heading + fenced code block |

## Epic Decomposition

When a problem is too complex for a single issue, decompose it into an **epic** (parent) with **sub-issues** (children). This keeps the board clean and progress trackable.

### When to Decompose

- Issue requires work across multiple domains or components
- Estimated effort exceeds size:L (2+ days)
- Multiple independent work streams can proceed in parallel
- Different specialists or teams own different parts

### Structure

```
Epic (parent issue)
├── Sub-issue #1 — specific deliverable
├── Sub-issue #2 — specific deliverable
├── Sub-issue #3 — specific deliverable
└── Verification phase (in epic acceptance criteria)
```

### Workflow

**Step 1 — Create sub-issues first** (they need issue numbers for the task list):

```bash
gh issue create --title "scope(area): sub-task title" \
  --label "enhancement,area:hooks,priority:p2-medium,size:M" \
  --body "## Context
...
**Parent**: TBD (will be linked from epic)

## Acceptance Criteria
- [ ] ..."
```

**Step 2 — Create the epic** with a task list referencing sub-issues:

```bash
gh issue create --title "epic(scope): high-level objective" \
  --label "enhancement,priority:p2-medium,size:XL" \
  --body "## Objective
...

## Sub-Issues

- [ ] #101 — sub-task 1 description
- [ ] #102 — sub-task 2 description
- [ ] #103 — sub-task 3 description

## Plan

### Phase 1 — ...
### Phase 2 — ...

## Acceptance Criteria
- [ ] All sub-issues completed
- [ ] Integration verified
- [ ] Tests pass"
```

GitHub automatically tracks task list progress (checked/unchecked) and shows a progress bar on the epic.

**Step 3 — Back-link sub-issues to parent**:

Update each sub-issue body to replace `TBD` with the epic number:

```bash
# Update sub-issue body to reference parent
gh issue edit 101 --body "$(gh issue view 101 --json body -q .body | \
  python3 -c "import sys; print(sys.stdin.read().replace('**Parent**: TBD', '**Parent**: #100'))")"
```

### Epic Rules

1. **Epic title prefix**: Use `epic(scope):` to distinguish from regular issues
2. **Sub-issues are independent**: Each sub-issue must be completable and testable on its own
3. **Epic has no implementation**: The epic only tracks, coordinates, and verifies — it never contains code changes itself
4. **Close order**: Sub-issues close first, epic closes last after all sub-issues pass
5. **Board placement**: Epic goes to In Progress when first sub-issue starts, To Be Tested when all sub-issues are done, Done after verification
6. **Size label**: Epic gets `size:XL` regardless — the effort is in the sub-issues

### Example

```
epic(certification): improve score from 913 to 950+ / 1000
├── #87 — cert(D4): add batch processing skill (+14 pts)
├── #88 — cert(D2): expose MCP server for Claude Code (+13 pts)
├── #89 — cert(D5): formalize information provenance (+10 pts)
└── #90 — cert(D1): strengthen session management (+8 pts)
```

## Error Handling

- If `gh` commands fail with auth errors, suggest: `gh auth refresh -h github.com -s project`
- If an issue number doesn't exist, report it clearly
- Confirm destructive actions (close, cancel) when affecting more than 2 issues at once
- If a move is blocked by transition rules, explain WHY and show allowed targets
- **CRITICAL: Wrong project guard** — Before every GraphQL mutation, verify `projectId` matches `CC_PROJECT_ID`. If field IDs don't match the configured project, ABORT immediately. See "Project Guard" section above.

## CI Automation

The `project-board-automation.yml` workflow requires a `PROJECT_PAT` repository secret (classic PAT with `repo` + `project` scopes). Without it, the automation jobs will fail silently.

## Integration with Agents

The `project-coordinator` agent can invoke this skill for project planning workflows.
The `solution-architect` agent references the board for feature tracking.
The `skill-updater` agent can verify board status during sprint reviews.
