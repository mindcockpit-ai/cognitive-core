---
name: fitness
description: Run quality fitness checks using configured thresholds and gates. Scores code against project standards.
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Grep, Glob
catalog_description: Quality fitness checks with configurable thresholds and gates.
---

# Fitness — Quality Gate Evaluation

Evaluates code quality against configurable fitness functions and gates. Reads
thresholds from `cognitive-core.conf` (`CC_FITNESS_*` variables).

## Arguments: `$ARGUMENTS` -- target file/dir, optional `--gate=lint|commit|test|merge|deploy`

## Configuration Reference

From `cognitive-core.conf`:
- `CC_FITNESS_LINT` -- lint gate threshold (default: 60)
- `CC_FITNESS_COMMIT` -- commit gate threshold (default: 80)
- `CC_FITNESS_TEST` -- test gate threshold (default: 85)
- `CC_FITNESS_MERGE` -- merge gate threshold (default: 90)
- `CC_FITNESS_DEPLOY` -- deploy gate threshold (default: 95)
- `CC_LINT_COMMAND` -- lint command
- `CC_TEST_COMMAND` -- test runner

## Fitness Functions

### 1. Code Standards Fitness

| Function | Check | Source |
|----------|-------|--------|
| `lint-pass` | Configured lint command passes | `CC_LINT_COMMAND` |
| `format-pass` | Configured format check passes | `CC_FORMAT_COMMAND` |
| `naming` | File and symbol naming conventions | CLAUDE.md |
| `error-handling` | Proper error handling patterns | CLAUDE.md |

### 2. Architecture Fitness

| Function | Check | Source |
|----------|-------|--------|
| `layer-deps` | Layer dependencies follow pattern | `CC_ARCHITECTURE` |
| `domain-purity` | Domain layer has no infrastructure | Code analysis |
| `no-anti-patterns` | Blocked patterns from CLAUDE.md absent | CLAUDE.md |

### 3. Test Fitness

| Function | Check | Source |
|----------|-------|--------|
| `test-exists` | New modules have corresponding tests | `CC_TEST_PATTERN` |
| `test-passes` | Test suite passes | `CC_TEST_COMMAND` |

### 4. Security Fitness

| Function | Check | Source |
|----------|-------|--------|
| `no-secrets` | No hardcoded credentials | Grep patterns |
| `parameterized-queries` | No raw SQL/query injection | Code analysis |
| `input-validation` | Public interfaces validate input | Code analysis |

## Quality Gates

| Gate | Trigger | Threshold | On Fail |
|------|---------|-----------|---------|
| `lint` | Before staging | `CC_FITNESS_LINT`% | Block |
| `commit` | Pre-commit | `CC_FITNESS_COMMIT`% | Reject |
| `test` | Pre-merge | `CC_FITNESS_TEST`% | Block merge |
| `merge` | Pull request | `CC_FITNESS_MERGE`% | Block merge |
| `deploy` | Pre-deploy | `CC_FITNESS_DEPLOY`% | Abort |

## Output Format

```
FITNESS EVALUATION
==================
Target: [path]
Gate:   [gate name]

CATEGORY SCORES
---------------
Code Standards:  [0.00-1.00]
Architecture:    [0.00-1.00]
Tests:           [0.00-1.00]
Security:        [0.00-1.00]
--------------------------
OVERALL:         [0.00-1.00]

GATE THRESHOLD:  [N]% ([gate] gate)
STATUS: [FIT - PASSED | UNFIT - BLOCKED]

REQUIRED FIXES:
1. [fix description]
```

## See Also

- `/pre-commit` -- Quick lint pass
- `/code-review` -- Detailed review
- `CLAUDE.md` -- Project standards
