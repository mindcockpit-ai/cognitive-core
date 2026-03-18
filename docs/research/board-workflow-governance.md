# Board Workflow with SOX-Compliant Governance

**Status**: Implemented | **Category**: Differentiated — unique integration for AI-augmented development
**Location**: `core/skills/project-board/SKILL.md`, `cicd/workflows/project-board-automation.yml`

---

## Problem

Enterprise development teams need governed workflows with enforced transitions, approval gates, and compliance controls. Current tools require either:

- **Expensive enterprise tooling**: Jira + plugins (ScriptRunner, JMWE) + Jira Service Management for approval gates and segregation of duties
- **Manual discipline**: GitHub Projects, Linear, Shortcut rely on team discipline for workflow rules — no enforcement
- **Separate systems**: SOX compliance tools (Harness, hoop.dev) handle CI/CD gates but not the issue lifecycle

No tool combines all of these as a single, configurable system designed for AI-augmented development teams.

## Solution

A 7-column board with enforced transition matrix, integrated governance controls, and CI automation that respects the human approval gate.

### Board Lifecycle

```
Roadmap → Backlog → Todo → In Progress → To Be Tested → Done
                                                       ↘ Canceled
```

### Transition Matrix

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

`✓` = Allowed | `✓*` = Allowed with warning (deprioritize/reopen/rework) | `-` = Blocked

### Key Rules

1. **Forward flow is primary** — no skipping columns (Backlog cannot jump to In Progress)
2. **Backward transitions with warnings** — deprioritize (In Progress → Todo/Backlog), rework (To Be Tested → In Progress)
3. **Human Approval Gate** — CI automation stops at "To Be Tested", not "Done"
4. **Closure Guard** — blocks closing issues with PARTIAL/FAIL acceptance criteria
5. **Deprioritize/descope** — In Progress → Todo/Backlog allowed, clears sprint assignment

### Governance Controls

| Control | Configuration | Default |
|---------|--------------|---------|
| Human approval gate | `CC_REQUIRE_HUMAN_APPROVAL` | `true` |
| Different approver (SOX) | `CC_REQUIRE_DIFFERENT_APPROVER` | `false` |
| Dual approval | `CC_REQUIRED_APPROVERS` | `1` |
| WIP limit: In Progress | `CC_WIP_LIMIT_PROGRESS` | `0` (unlimited) |
| WIP limit: To Be Tested | `CC_WIP_LIMIT_TESTING` | `0` (unlimited) |
| WIP limit: Todo | `CC_WIP_LIMIT_TODO` | `0` (unlimited) |

### Blocked State

Any active issue can be flagged as blocked via the `blocked` label. The issue stays in its current column but is visually marked as an impediment. Blocked items do not count against WIP limits.

### CI Automation (Approval-Aware)

| Event | Action (approval gate ON) | Action (approval gate OFF) |
|-------|--------------------------|---------------------------|
| PR opened | Issue → In Progress (from Todo only) | Same |
| PR merged | Issue → **To Be Tested** | Issue → Done |
| Issue closed | Reopens + moves to **To Be Tested** | Issue → Done |
| Issue closed from To Be Tested | Issue → Done (approval path) | Same |
| Issue assigned | Issue → Todo (from Backlog/Roadmap) | Same |
| Issue opened | Added to board in Backlog | Same |

### Agile Metrics

Built-in metrics command computes from issue event history:
- **Cycle time**: Start (In Progress) → Done, per priority
- **Lead time**: Created → Done
- **Throughput**: Issues completed per sprint
- **Flow efficiency**: Active time / (Active + Wait time)
- **Sprint trends**: Velocity across sprints

## Compliance Mapping

| Standard | Requirement | cognitive-core Feature |
|----------|------------|----------------------|
| **SOX 404** | Segregation of duties | `CC_REQUIRE_DIFFERENT_APPROVER` |
| **ISO 27001 A.12** | Change management with authorization | Human approval gate + attribution |
| **ITIL CAB** | Change Advisory Board review | Dual approval (`CC_REQUIRED_APPROVERS=2`) |
| **PCI DSS 6.4** | Separation of test and production | Fitness gates at deploy level |
| **NIST 800-53 CM-3** | Configuration change control | Verification comments as documentation |

## Architecture — Clean Separation

```
Layer 1: SKILL.md         — Workflow rules, WIP limits, approval gate (vendor-agnostic)
Layer 2: _provider-lib.sh  — Shared CLI contract, JSON I/O, command routing
Layer 3: providers/*.sh    — Vendor adapters (GitHub, Jira, YouTrack)
```

New providers (Azure DevOps, Linear, Shortcut) implement the same CLI contract. All workflow rules apply automatically.

## Competitive Analysis

| Capability | cognitive-core | Jira (+plugins) | Azure DevOps | Linear | GitHub Projects |
|---|---|---|---|---|---|
| Transition enforcement | Strict matrix | Configurable | Configurable (CMMI) | None | None |
| Human approval gate | Native, CI-aware | Plugin (Service Mgmt) | Environment only | None | PR reviewers only |
| Different-approver (SOX) | Native config | Plugin (ScriptRunner) | Not native | None | None |
| WIP limits | Per-column config | Plugin | Native | None | Partial |
| Blocked state | Label-based | Status/flag | Tags | Label | None |
| Fitness gates | 5 graduated | None (SonarQube addon) | Branch policies | None | None |
| Acceptance verification | Automated PASS/FAIL | Manual testing | Test plans | None | None |
| Multi-provider | GitHub, Jira, YouTrack | Jira only | Azure only | Linear only | GitHub only |

## Research Sources

| Finding | Source | Authority |
|---------|--------|-----------|
| Jira approval gates require Service Management addon | Atlassian Support KB | T1 |
| Azure DevOps: transition rules + WIP limits native | Microsoft Learn docs | T1 |
| Linear: no transition enforcement, no WIP limits | Linear official docs | T1 |
| GitHub Projects: no native transition enforcement | GitHub Community discussion #4848 | T3 |
| SOX compliance in CI/CD: Harness, hoop.dev (pipeline only) | Harness DevOps Academy | T2 |
| Jira SOX segregation requires ScriptRunner | Cprime blog on Jira compliance | T2 |

## Impact

A single `cognitive-core.conf` file configures enterprise-grade governance that would otherwise require Jira + 3 plugins + Jira Service Management licensing. Teams get SOX compliance, approval gates, WIP limits, transition enforcement, and agile metrics from one framework — across GitHub, Jira, and YouTrack.
