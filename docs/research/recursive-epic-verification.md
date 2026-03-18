# Recursive Epic Verification

**Status**: Implemented | **Category**: Novel — no tool verifies acceptance criteria hierarchically
**Location**: `core/skills/project-board/SKILL.md`, `core/skills/acceptance-verification/SKILL.md`

---

## Problem

Epics decompose large features into sub-issues. But when it comes time to verify the epic is complete, every tool falls back to a simple check: "Are all child issues closed?" This misses the critical question: **did we actually build what we specified?**

- Jira checks if sub-tasks are open or closed — not whether acceptance criteria are met
- Azure DevOps has parent-child rollup for state — not criteria-level verification
- Linear, monday.com, Asana track completion percentage — done/not-done counts
- No tool recursively gathers evidence from code, tests, and git history to verify what was built against what was specified

## Solution

When `verify` is called on an epic, cognitive-core performs recursive verification:

### Workflow

1. **Detect epic**: Parse the issue body for task list items (`- [ ] #N` or `- [x] #N`)
2. **Verify each sub-issue**: Run `acceptance-verification` on every referenced sub-issue
3. **Gather evidence per criterion**: Search git history, codebase, test files, documentation
4. **Assess PASS / PARTIAL / FAIL** per criterion per sub-issue
5. **Aggregate results**: Roll up across all sub-issues
6. **Verify epic's own criteria**: Then check the epic-level acceptance criteria
7. **Post consolidated report** on the epic issue

### Output

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
- Sub-issues: 3/4 PASS, 1 PARTIAL
- Epic criteria: 1/2 PASS, 1 PARTIAL
- Overall: PARTIAL — #88 blocks epic closure
```

### Closure Rule

**An epic can only be closed when ALL sub-issues are PASS AND all epic-level criteria are PASS.** If any sub-issue is PARTIAL or FAIL, the epic is blocked. This is a hard rule — no exceptions.

## Evidence Gathering

For each acceptance criterion, the system searches:

1. **Git history**: Commits referencing the issue number
2. **Code changes**: Files modified for this issue (Grep/Glob)
3. **Test coverage**: Tests verifying the criterion
4. **Documentation**: Docs addressing the criterion
5. **CI/CD pipeline**: Workflow changes if applicable

Priority order: explicit references (`#N`) > keyword matching > file path inference > temporal proximity.

## Competitive Analysis

| Tool | Epic Completion Check | Criteria-Level Verification | Evidence Gathering | Recursive |
|------|----------------------|---------------------------|-------------------|-----------|
| **cognitive-core** | PASS/PARTIAL/FAIL per criterion | Yes — automated | Code, tests, git, docs | Yes |
| Jira | Sub-tasks open/closed | No | Manual test links | No |
| Azure DevOps | Work item state rollup | Test plans (manual) | Manual | No |
| Linear | Issue completion count | No | No | No |
| monday.com | Progress percentage | No | No | No |
| Asana | Subtask completion | No | No | No |
| GitHub Projects | Tasklist checkbox count | No | No | No |

## Research Sources

| Finding | Source | Authority |
|---------|--------|-----------|
| Jira blocks epic closure only by sub-task state (open/closed) | Atlassian Support KB | T1 |
| Azure DevOps: parent-child rollup for state, not criteria | Microsoft Learn docs | T1 |
| monday.com / Asana: progress percentage from completion count | Official docs | T1 |
| No PM tool performs automated evidence-based criteria verification | Survey of Jira, Azure DevOps, Linear, monday.com, Asana, GitHub docs | T1 |
| Jira criteria-based blocking requires ScriptRunner plugin | Atlassian Community discussion | T3 |

## Impact

Teams using cognitive-core cannot close an epic by simply closing sub-issues. The system verifies — from actual code, tests, and git history — that what was specified was actually built. This eliminates:

- **Premature closure**: Issues closed as "done" when criteria are only partially met
- **Lost requirements**: Acceptance criteria that were specified but never implemented
- **Audit gaps**: No evidence trail between requirement and implementation

The recursive nature means this scales to any epic depth — an epic of epics is verified all the way down.

## Implementation in cognitive-core

### Files

| File | Role |
|------|------|
| [`core/skills/acceptance-verification/SKILL.md`](../../core/skills/acceptance-verification/SKILL.md) | Core verification engine — 6-step workflow, PASS/PARTIAL/FAIL assessment, closure guard, epic-aware recursion |
| [`core/skills/project-board/SKILL.md`](../../core/skills/project-board/SKILL.md) | `verify` command — delegates to acceptance-verification, Epic Verification section with consolidated output format |
| [`core/skills/project-board/references/recipes.md`](../../core/skills/project-board/references/recipes.md) | QA Lead recipes — pre-release verification, approval gate workflow |

### How It Works

1. User invokes `/project-board verify 91` (an epic)
2. Skill parses issue body for task list items: `- [ ] #87`, `- [ ] #88`, etc.
3. For each sub-issue, runs acceptance-verification:
   - Fetches issue body and acceptance criteria via `gh issue view`
   - Searches git history for commits referencing `#N`
   - Searches codebase for keyword matches from criteria
   - Checks test files for verification evidence
   - Assesses each criterion: PASS / PARTIAL / FAIL
4. Aggregates results across all sub-issues
5. Verifies epic's own acceptance criteria
6. Posts consolidated report as comment on the epic
7. **Closure guard**: Blocks epic closure if ANY sub-issue is PARTIAL or FAIL

### Key Design Decisions

- **Auto-tick checkboxes**: When a criterion passes, the issue body checkbox is ticked (`- [ ]` → `- [x]`)
- **PARTIAL stays unchecked**: Only PASS criteria get ticked — never optimistic
- **Evidence sources ranked**: explicit `#N` references > keyword matching > file path inference > temporal proximity
- **Strict mode** (`--strict`): Report only, no state changes — suitable for audit documentation

### Test Coverage

| Suite | Tests | What It Validates |
|-------|-------|-------------------|
| Suite 02 — Skill Frontmatter | 64 | acceptance-verification and project-board SKILL.md have valid frontmatter |
| Suite 04 — Install Dry-Run | 44 | Both skills installed correctly in target project |

### Verification

Applied in production on epic #91 (certification score improvement):
- 4 sub-issues (#87, #88, #89, #90) created with acceptance criteria
- Each implemented by project-coordinator agent
- Verification confirmed all criteria met
- Epic closed after all sub-issues passed
- Score improved from 913 to 959/1000 — verified against 43 exam subtasks
