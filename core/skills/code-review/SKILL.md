---
name: code-review
description: Language-agnostic code review skill. Reads project conventions from CLAUDE.md and applies parameterized quality checks.
user-invocable: true
allowed-tools: Read, Grep, Glob
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

```
CODE REVIEW
===========
File: [path]
Layer: [detected layer]
Language: [from CC_LANGUAGE]

STANDARDS
---------
[check]: [PASS/FAIL] [detail if failed]

ARCHITECTURE
------------
[check]: [PASS/FAIL] [detail if failed]

ANTI-PATTERNS
-------------
[check]: [PASS/FAIL] [detail if failed]

SUMMARY
=======
Category     | Pass | Warn | Fail
-------------|------|------|-----
Standards    |  N   |  N   |  N
Architecture |  N   |  N   |  N
Anti-patterns|  N   |  N   |  N

VERDICT: [APPROVED | NEEDS_CHANGES]
```

## See Also

- `/pre-commit` -- Quick lint before staging
- `/fitness` -- Quality fitness scoring
- `CLAUDE.md` -- Project standards reference
