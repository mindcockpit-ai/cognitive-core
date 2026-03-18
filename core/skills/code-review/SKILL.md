---
name: code-review
description: Language-agnostic code review skill. Reads project conventions from CLAUDE.md and applies parameterized quality checks.
user-invocable: true
context: fork
allowed-tools: Read, Grep, Glob
argument-hint: "File or directory to review"
catalog_description: Language-agnostic code review with project-aware convention checks.
---

# Code Review — Project-Aware Quality Checks

Provides structured code review by reading conventions from your project's
CLAUDE.md and `cognitive-core.conf`. All checks are parameterized.

## Arguments: `$ARGUMENTS` -- file or directory to review

## Instructions

### Step 1: Load Project Conventions

1. Read `CLAUDE.md` at the project root for coding standards
2. Source `cognitive-core.conf` for language and architecture settings:
   - `CC_LANGUAGE` -- primary language
   - `CC_ARCHITECTURE` -- architecture pattern (ddd, mvc, clean, etc.)
   - `CC_LINT_COMMAND` -- configured lint command
3. Check for a code checklist doc referenced in CLAUDE.md

### Step 2: Identify File Type and Layer

Determine the architectural layer of the file being reviewed based on its path
and the configured `CC_ARCHITECTURE` pattern. Common layers:
- **Domain/Model** -- pure business logic, no infrastructure
- **Repository/Data** -- data access, DB queries
- **Service/Use-case** -- business orchestration
- **Controller/Handler** -- HTTP/API interface
- **Mapper/DTO** -- data transformation

### Step 3: Apply Checks

#### General Checks (all languages)

| Check | Severity |
|-------|----------|
| File follows project naming conventions | ERROR |
| Error handling present (not bare catch/rescue/except) | ERROR |
| No hardcoded secrets or credentials | ERROR |
| Functions/methods have clear single responsibility | WARN |
| Magic numbers or strings extracted to constants | WARN |
| Input validation on public interfaces | WARN |

#### Architecture Checks

| Check | Severity |
|-------|----------|
| Layer dependencies follow configured pattern | ERROR |
| No infrastructure code in domain/model layer | ERROR |
| Controllers delegate to services (thin controllers) | WARN |
| Data access goes through repository layer | ERROR |

#### Anti-Pattern Checks

Read CLAUDE.md for project-specific anti-patterns and blocked patterns.
Flag any matches as ERROR.

### Step 4: Output Report

Each finding must include its provenance source for traceability:

```
CODE REVIEW
===========
File: [path]
Layer: [detected layer]
Language: [from CC_LANGUAGE]

STANDARDS
---------
[check]: [PASS/FAIL] [detail if failed] — Source: [documented|verified|inferred|automated]

ARCHITECTURE
------------
[check]: [PASS/FAIL] [detail if failed] — Source: [documented|verified|inferred|automated]

ANTI-PATTERNS
-------------
[check]: [PASS/FAIL] [detail if failed] — Source: [documented|verified|inferred|automated]

SUMMARY
=======
Category     | Pass | Warn | Fail
-------------|------|------|-----
Standards    |  N   |  N   |  N
Architecture |  N   |  N   |  N
Anti-patterns|  N   |  N   |  N

PROVENANCE
==========
- documented: N findings from CLAUDE.md / language standards
- automated: N findings from lint tool
- inferred: N findings from pattern analysis
- verified: N findings from code inspection

VERDICT: [APPROVED | NEEDS_CHANGES]
```

## Multi-Pass Review Strategy

For reviews involving more than 5 changed files, use a multi-pass approach to prevent attention dilution:

### Pass 1: Per-File Local Analysis
Review each file individually for:
- Code style and convention violations
- Bugs and logic errors
- Security issues
- Missing error handling

Output format per file:
| File | Line | Severity | Issue | Fix | Source |
|------|------|----------|-------|-----|--------|

### Pass 2: Cross-File Integration Analysis
After completing all per-file reviews, analyze cross-cutting concerns:
- Data flow consistency across files
- API contract alignment (are callers and implementations in sync?)
- Dependency direction (no circular dependencies, proper layering)
- Naming consistency across related files
- Contradictory patterns (same logic handled differently in different files)

### Pass 3: Consolidated Findings
- Deduplicate findings: same pattern in multiple files → single finding with all locations
- Resolve contradictions from Pass 1 (flagging pattern in file A but approving in file B)
- Prioritize: critical → warning → info
- Group by theme, not by file

### When to Use
- **>5 changed files**: Always use multi-pass
- **<=5 changed files**: Single-pass is sufficient
- **Single file**: Direct review, no passes needed

### Independent Review
Use `context: fork` to run the review in an isolated context. This prevents the reviewing agent from being influenced by its own prior generation reasoning — a fresh perspective catches issues that self-review misses.

## See Also

- `/pre-commit` -- Quick lint before staging
- `/fitness` -- Quality fitness scoring
- `CLAUDE.md` -- Project standards reference
