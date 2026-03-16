# Recipe: Code Review Workflow

> **Time**: ~2 min read | **Level**: Intermediate | **Audience**: Developers choosing between review tools

## Goal

Run a code review using cognitive-core's two review tools — the `/code-review` skill for single files and `@code-standards-reviewer` for multi-file changes — and understand when to use each.

## Prerequisites

- cognitive-core installed (`./install.sh /path/to/project`)
- At least one source file to review
- For multi-file review: a branch with 2+ changed files

## Steps

### Step 1: Choose the right tool

Decide between `/code-review` (single file) and `@code-standards-reviewer` (multi-file) using the table below.

### Step 2: Run the review

See the Single-File Review and Multi-File Review sections for exact commands and expected output.

### Step 3: Fix findings and verify

Follow the Recommended Workflow at the bottom: fix findings, run `/fitness`, then `/pre-commit`.

---

## Quick Decision

| Situation | Tool | Why |
|-----------|------|-----|
| Single file, quick check | `/code-review src/auth.py` | Lightweight skill, forked context, structured report |
| Multi-file review (2-5 files) | `@code-standards-reviewer review the auth module` | Thinking mode, cross-file analysis, single pass |
| Large change (>5 files) | `@code-standards-reviewer review the last 3 commits` | Thinking mode, automatic 3-pass strategy |

**Rule of thumb**: `/code-review` answers "is this file clean?" -- `@code-standards-reviewer` answers "does this change hold together?"

## Single-File Review

```
/code-review src/services/UserService.java
```

Expected output:

```
CODE REVIEW
===========
File: src/services/UserService.java
Layer: Service/Use-case
Language: java

STANDARDS
---------
Naming conventions: PASS
Error handling: FAIL — bare catch at line 47
No hardcoded secrets: PASS
Single responsibility: PASS
Magic numbers: WARN — 3600 at line 82

ARCHITECTURE
------------
Layer dependencies: PASS
No infra in domain: PASS
Thin controllers: N/A (service layer)

ANTI-PATTERNS
-------------
Blocked patterns: PASS

SUMMARY
=======
Category      | Pass | Warn | Fail
--------------|------|------|-----
Standards     |  3   |  1   |  1
Architecture  |  2   |  0   |  0
Anti-patterns |  1   |  0   |  0

VERDICT: NEEDS_CHANGES
```

## Multi-File Review (>5 files)

When `@code-standards-reviewer` sees more than 5 changed files, it automatically switches to a 3-pass strategy. You do not need to ask for it.

```
@code-standards-reviewer review all files changed in the last 2 commits
```

### Pass 1: Per-File Local Analysis

Each file reviewed individually. Output:

| File:Line | Severity | Issue | Fix |
|-----------|----------|-------|-----|
| `UserService.java:47` | critical | Bare `catch` swallows all exceptions | Catch `UserNotFoundException` specifically |
| `UserController.java:23` | warning | 200 OK returned on validation failure | Return 400 with error body |
| `UserRepository.java:61` | info | Unused import `java.util.stream.*` | Remove import |

### Pass 2: Cross-File Integration

Analyzes relationships the per-file pass cannot see:

- **Data flow**: Does `UserController` pass the right DTO shape to `UserService`?
- **API contracts**: Does the service return what the controller expects?
- **Dependency direction**: Service depends on repository (correct), not the reverse?
- **Naming consistency**: `userId` in controller vs `user_id` in repository?

### Pass 3: Consolidated Findings

- Deduplicates: same bare-catch pattern in 4 files becomes 1 finding with 4 locations
- Resolves contradictions: pattern approved in file A but flagged in file B
- Prioritizes: critical first, then warning, then info
- Groups by theme, not by file

## When Multi-Pass Kicks In

| Changed files | Strategy | Passes |
|---------------|----------|--------|
| 1 | Direct review | -- |
| 2-5 | Single-pass review | 1 |
| >5 | Multi-pass review | 3 |

The threshold exists because attention dilution causes inconsistent depth. Reviewing 12 files in one pass leads to thorough analysis of the first 4 and shallow scanning of the rest.

## The `context: fork` Advantage

`/code-review` runs with `context: fork` -- an isolated context that cannot see the conversation that generated the code. This matters because:

- **Self-review is blind**: the same reasoning that wrote a bug will justify it during review
- **Forked context starts fresh**: reads the file as-is, checks against CLAUDE.md, no prior assumptions
- **Result**: catches issues that in-conversation review misses

`@code-standards-reviewer` runs as a subagent with thinking mode instead. Different isolation mechanism, same benefit: separation between generation and review.

## Common Mistakes

| Mistake | Problem | Do This Instead |
|---------|---------|-----------------|
| Review + implement fixes in the same turn | Mixing concerns -- fixes get influenced by review framing | Review in one turn, implement fixes in the next |
| Skip `/fitness` after fixing review findings | Review found issues, but were the fixes adequate? | `/fitness` after implementing review fixes |
| `/code-review` on 15 files | Skill reviews file-by-file without cross-file analysis | `@code-standards-reviewer` for multi-file changes |
| `@code-standards-reviewer` for a quick single-file check | Overkill -- thinking mode + full process for one file | `/code-review path/to/file` |
| Ask `@solution-architect` to review code | Architects design systems, they don't review code standards | `@code-standards-reviewer` for review |

## Recommended Workflow

```
1. [Implement feature across multiple files]
2. /code-review src/critical-file.java          # quick check on the riskiest file
3. @code-standards-reviewer review the feature   # full multi-file review
4. [Fix findings]
5. /fitness                                      # verify quality gates
6. /pre-commit                                   # lint staged files
7. git commit
```

## Expected Output

After a single-file review (`/code-review src/services/UserService.java`), you should see a structured report with Standards, Architecture, and Anti-patterns sections, each with PASS/WARN/FAIL verdicts, and a final VERDICT line (APPROVED, APPROVED with warnings, or NEEDS_CHANGES).

After a multi-file review (`@code-standards-reviewer review the auth module`), you should see per-file findings followed by cross-file integration analysis and a consolidated, deduplicated findings table grouped by theme.

## Next Steps

- [Getting Started with Java](getting-started-java.md) -- full install-to-first-review walkthrough
- [Test Creation](recipe-test-creation.md) -- create tests after fixing review findings
- [Wrong Agent?](recipe-wrong-agent.md) -- what happens when you pick the wrong agent
- `/code-review` skill: `core/skills/code-review/SKILL.md`
- `@code-standards-reviewer` agent: `core/agents/code-standards-reviewer.md`
