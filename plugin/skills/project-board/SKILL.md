---
name: project-board
description: Manage GitHub Project board — issues, sprints, status tracking, acceptance verification, and release management. White-labeled template for any project.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob
argument-hint: "[list|create|close|cancel|assign|sprint|sprint-plan|triage|board|move|verify] [options]"
catalog_description: GitHub Project board — issues, sprints, releases, and triage.
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

# Branching strategy (optional — set CC_BRANCH_AUTO_CREATE="true" to enable)
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
In Progress          -       -       -        -             ✓          -      ✓
To Be Tested         -       -       -        ✓*            -          ✓      ✓
Done                 -       -       -        ✓*            ✓*         -      -
Canceled             -       ✓*     ✓*        -             -          -      -
```

`✓` = Allowed | `✓*` = Allowed but warn (reopen/rework) | `-` = Blocked

### Key Rules

1. **Forward flow is primary**: Roadmap/Backlog → Todo → In Progress → To Be Tested → Done
2. **Backward transitions with warning**: To Be Tested → In Progress (rework), Done → In Progress/To Be Tested (reopen), Canceled → Backlog/Todo (reopen)
3. **Canceled reachable from anywhere** except Done
4. **Reopen from Done/Canceled**: Allowed with warning. The `move` command automatically reopens the GitHub issue when moving out of Done or Canceled.
5. **No skipping**: Cannot jump Backlog → In Progress (must pass through Todo first)
6. **Reopen syncs GitHub state**: When moving from Done or Canceled to an active column, the `move` command automatically runs `gh issue reopen` to sync the GitHub issue state with the board status.
7. **Auto-sprint assignment**: When moving to Todo, In Progress, or To Be Tested, the `move` command automatically assigns the issue to the current sprint if it has no sprint set. Requires `CC_SPRINT_FIELD_ID` to be configured.
8. **Auto-assignee**: Sprint items must have an owner. When moving to a sprint-required column and the issue has no assignee, auto-assign to the current user (initiator of the change).

### CI Automation

The `project-board-automation.yml` workflow (in `cicd/workflows/`) handles:
- PR opened with `Closes #N` → issue moves to In Progress (from Todo only)
- PR merged → issue moves to Done
- Issue assigned (from Backlog/Roadmap) → moves to Todo
- New issue opened → added to board in Backlog
- Issue reopened → moves to In Progress
- Issue closed → moves to Done

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
#   In Progress  → To Be Tested, Canceled
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
