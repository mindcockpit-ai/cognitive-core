---
name: acceptance-verification
description: Verify GitHub issue acceptance criteria against codebase evidence. Posts structured verification comments on issues.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob
argument-hint: "<issue-number> [--strict] [--dry-run]"
---

# Acceptance Verification — Issue Criteria Checker

Verify whether acceptance criteria defined in a GitHub issue have been met, partially met, or remain open. Posts a structured verification comment on the issue with evidence.

## Configuration

| Variable | Description | Example |
|----------|-------------|---------|
| `{{CC_GITHUB_OWNER}}` | Repository owner | `myorg` |
| `{{CC_GITHUB_REPO}}` | Repository name | `my-project` |
| `{{CC_PROJECT_NUMBER}}` | GitHub Project number | `3` |
| `{{CC_PROJECT_ID}}` | GitHub Project node ID | `PVT_kwHOA5GKMc4BPDsB` |
| `{{CC_STATUS_DONE_ID}}` | "Done" column option ID | `52a13056` |
| `{{CC_STATUS_FIELD_ID}}` | Status field ID | `PVTSSF_...` |

## Workflow

When invoked with an issue number:

### Step 1: Extract Acceptance Criteria

```bash
gh issue view <number> --repo {{CC_GITHUB_OWNER}}/{{CC_GITHUB_REPO}} --json title,body,labels,state,comments
```

Parse the issue body for acceptance criteria. Look for:
- Checkbox lists: `- [ ] criteria` or `- [x] criteria`
- Numbered lists under headers like "Acceptance Criteria", "Requirements", "Definition of Done"
- Bullet points under "Success Criteria" or "Verification"

Extract each criterion as a separate item. If no structured criteria found, extract key requirements from the issue description.

### Step 2: Gather Evidence

For each criterion, search for evidence across these sources:

**a) Git history** — commits referencing the issue:
```bash
gh api repos/{{CC_GITHUB_OWNER}}/{{CC_GITHUB_REPO}}/commits --jq '.[].commit.message' -X GET -f sha=development -f per_page=50 | grep -i "#<number>"
git log --oneline --all --grep="<keyword>" | head -10
```

**b) Code changes** — files modified for this issue (use Grep and Glob tools)

**c) Test coverage** — tests verifying the criterion (search test directories)

**d) Documentation** — docs addressing the criterion

**e) CI/CD pipeline** — workflow changes if applicable

### Step 3: Assess Each Criterion

| Status | Symbol | Meaning |
|--------|--------|---------|
| **PASS** | :white_check_mark: | Criterion fully satisfied with evidence |
| **PARTIAL** | :large_orange_diamond: | Some aspects met, gaps remain |
| **FAIL** | :x: | No evidence of implementation |
| **N/A** | :heavy_minus_sign: | Criterion not applicable or deferred |

### Step 4: Post Verification Comment

```bash
gh issue comment <number> --repo {{CC_GITHUB_OWNER}}/{{CC_GITHUB_REPO}} --body "$(cat <<'COMMENT'
## Acceptance Criteria Verification

**Verified by**: Claude Code — Acceptance Verification
**Date**: $(date +%Y-%m-%d)
**Branch**: development

### Results

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | <criterion text> | :white_check_mark: PASS | <evidence summary> |
| 2 | <criterion text> | :large_orange_diamond: PARTIAL | <what's done, what's missing> |
| 3 | <criterion text> | :x: FAIL | No implementation found |

### Summary

- **Total criteria**: N
- **Passed**: X / **Partial**: Y / **Failed**: Z
- **Overall**: PASS / PARTIAL / FAIL

### Evidence Details

#### Criterion 1: <text>
- **Commits**: `abc1234` — <commit message>
- **Files**: `path/to/file:42` — <relevant code>
- **Tests**: `t/path/to/test.t` — <test description>

### Recommendation

<If gaps exist: specific actions needed>
<If all pass: ready to move to Done>
COMMENT
)"
```

### Step 5: Update Board Status (if all pass)

If `--strict` is NOT set and all criteria pass:
- Suggest moving the issue to "Done" on the project board
- Ask user for confirmation before executing

If `--strict` IS set:
- Report only, no board changes

## Options

| Flag | Effect |
|------|--------|
| `--strict` | Report only, no board status changes suggested |
| `--dry-run` | Show what would be posted without actually commenting |
| `--quiet` | Minimal output, just the summary table |

## Evidence Search Strategy

Priority order for finding evidence:

1. **Explicit references**: `#<issue-number>` in commit messages, PR titles
2. **Keyword matching**: Key terms from criterion text in code, tests, docs
3. **File path inference**: If criterion mentions specific component, check that directory
4. **Temporal proximity**: Recent commits around issue creation/assignment date
5. **Test naming**: Test descriptions matching criterion intent

## Multiple Issues

```
/verify 19 21 37
```

Process each issue sequentially and post individual comments.

## Integration

This skill can be invoked by:
- Users directly via `/verify <number>`
- The project coordinator agent during sprint reviews
- The code standards reviewer agent after code review
- The issues management skill via `/issues verify <number>`
