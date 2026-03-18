# Project Board Recipes

Role-based workflows for enterprise teams. Each recipe shows a complete scenario from start to finish.

## Scrum Master Recipes

### Daily Standup Preparation

Run before standup to get current sprint state:

```
/project-board sprint
```

Follow up with blockers:

```
/project-board list --state=open
```

Look for issues In Progress longer than 3 days — flag for discussion.

### Sprint Planning Session

1. Review backlog by priority:

```
/project-board list
```

2. Triage unlabeled issues:

```
/project-board triage
```

3. Create new sprint and assign issues:

```
/project-board sprint-plan "Sprint 7" 45 46 47 48 49
```

4. Move planned issues to Todo:

```
/project-board move 45 todo
/project-board move 46 todo
```

### Sprint Retrospective Data

Get project status for the sprint period:

```
/project-status --since=14d
```

Review completed vs planned:

```
/project-board sprint
```

Check fitness scores for merged work:

```
/fitness --gate=merge
```

---

## Project Manager Recipes

### Weekly Status Report

Generate a comprehensive status report combining board state and git activity:

```
/project-status --since=7d
```

Then get board overview:

```
/project-board board
```

Combine for stakeholder email:
- Work streams from `/project-status`
- Board column counts from `/project-board board`
- Blockers from sprint review
- Next week priorities from backlog

### Epic Planning for Complex Features

When a feature spans multiple teams or components:

1. Analyze the feature scope:

```
/workflow-analysis "payment gateway integration" --depth=deep
```

2. Decompose into sub-issues (see Epic Decomposition in SKILL.md):

```
/project-board create "feat(payments): Stripe API integration" --priority p1 --area infrastructure
/project-board create "feat(payments): webhook handler" --priority p1 --area infrastructure
/project-board create "feat(payments): invoice PDF generation" --priority p2 --area infrastructure
/project-board create "test(payments): E2E payment flow tests" --priority p1 --area testing
```

3. Create parent epic referencing all sub-issues (use the task list pattern)

4. Assign to sprint:

```
/project-board sprint-plan "Sprint 7" 51 52 53 54
```

### Risk Assessment

Combine workflow analysis with board state:

```
/workflow-analysis "current sprint risks" --depth=standard
```

Identify:
- Issues In Progress without assignees
- High-priority items not in current sprint
- Dependencies between issues
- Items blocked longer than 2 days

---

## QA Lead Recipes

### Pre-Release Verification

Verify all issues tagged for the release:

```
/project-board verify 41
/project-board verify 42
/project-board verify 43
```

Each verification:
- Checks acceptance criteria against codebase evidence
- Posts structured PASS/PARTIAL/FAIL comment on the issue
- Auto-ticks passing checkboxes in issue body
- Blocks closure if any criteria fail

### Test Coverage Check

Run fitness evaluation on the codebase:

```
/fitness --gate=merge
```

Review the Test Fitness section:
- `test-exists`: New modules have corresponding tests
- `test-passes`: Test suite passes
- Overall score vs merge threshold

### Approval Gate Workflow

When `CC_REQUIRE_HUMAN_APPROVAL="true"` (enterprise default):

1. Developer completes work, issue moves to "To Be Tested"
2. QA reviews verification evidence posted by acceptance-verification
3. QA approves:

```
/project-board approve 41 --comment "Verified in staging, all criteria met"
```

This creates an audit trail: who approved, when, and why.

---

## CTO / Engineering Director Recipes

### Portfolio Health Dashboard

Get board-level metrics:

```
/project-board board
```

This shows items per column. Key indicators:
- **In Progress count** — too high = context switching
- **To Be Tested count** — too high = QA bottleneck
- **Backlog count** — growing = capacity problem
- **Done velocity** — items closed per sprint

### Cross-Project Status

For organizations with multiple cognitive-core projects, run status on each:

```
/project-status --since=30d
```

Compare fitness scores across projects:

```
/fitness --gate=deploy
```

### Architecture Decision Review

When evaluating new feature proposals:

```
/workflow-analysis "microservices migration" --depth=deep
```

The deep analysis includes:
- Alternative approaches comparison
- Security and governance implications
- Migration plan with phases
- Success metrics
- Decision log for ADR (Architecture Decision Records)

---

## Business Analyst Recipes

### Requirements Tracing

After requirements are implemented, verify traceability:

```
/project-board verify 35
```

This maps each acceptance criterion to:
- Git commits (code evidence)
- Test files (verification evidence)
- Documentation (spec evidence)

### New Feature Analysis

When a stakeholder requests a new feature:

```
/workflow-analysis "customer self-service portal" --depth=standard
```

Produces:
1. **Business Context** — problem, value, stakeholders
2. **Current State** — what exists today
3. **Proposed Workflow** — flow diagram, state transitions
4. **Architecture Alignment** — how it fits existing system
5. **Implementation Estimate** — phases, effort, dependencies
6. **Risks** — risk matrix with mitigations
7. **Recommendation** — clear next steps

### User Story Decomposition

Break epics into implementable stories:

```
/workflow-analysis "epic: customer onboarding" --depth=quick
```

Then create issues for each identified workflow step:

```
/project-board create "feat(onboarding): email verification flow" --priority p1
/project-board create "feat(onboarding): profile completion wizard" --priority p2
/project-board create "feat(onboarding): welcome email sequence" --priority p3
```

---

## Compliance / Governance Recipes

### Audit Trail Generation

Every issue closure through cognitive-core creates an audit trail:

1. **Acceptance criteria** — defined at issue creation
2. **Verification comment** — automated evidence check
3. **Approval record** — who approved, when, with what comment
4. **Git history** — linked commits and PRs

To generate audit evidence for a specific issue:

```
/project-board verify 41 --strict
```

The `--strict` flag reports only — no state changes — suitable for audit documentation.

### SOX / ISO 27001 Compliance

Key controls mapped to cognitive-core features:

| Control | cognitive-core Feature |
|---------|----------------------|
| Segregation of duties | Human Approval Gate (CC_REQUIRE_HUMAN_APPROVAL) |
| Change management | Board transition rules (no skipping columns) |
| Evidence of testing | Acceptance verification with PASS/FAIL |
| Approval attribution | `/project-board approve` with user identity |
| Audit trail | Issue comments with timestamps |
| Access control | Security hooks (validate-bash, validate-read) |

### Change Advisory Board (CAB) Preparation

Before CAB meeting, generate evidence package:

1. List changes in the release:

```
/project-board sprint
```

2. Verify each change:

```
/project-board verify 41
/project-board verify 42
```

3. Run fitness evaluation:

```
/fitness --gate=deploy
```

4. Present: board status + verification results + fitness score

---

## Cross-Role: Release Management

### Release Checklist

1. **PM**: Confirm all sprint items are Done

```
/project-board sprint
```

2. **QA**: Verify acceptance criteria for all items

```
/project-board verify 41 42 43 44
```

3. **QA**: Run deploy-gate fitness check

```
/fitness --gate=deploy
```

4. **Tech Lead**: Review overall project status

```
/project-status --since=14d
```

5. **PM**: Close the sprint, plan next

```
/project-board sprint-plan "Sprint 8" 55 56 57
```
