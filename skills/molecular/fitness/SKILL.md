---
name: fitness
description: Evaluate code fitness against quality gates. Use before commits, merges, and deployments to ensure code survival.
argument-hint: [target] [--gate=lint|commit|test|merge|deploy]
allowed-tools: Bash, Read, Grep, Glob
---

# Fitness

Molecular skill for evaluating code fitness against evolutionary quality gates.

## The Evolutionary Model

```
MUTATION           SELECTION              SURVIVAL
(Development)      (Fitness Gates)        (Production)

┌──────────┐      ┌──────────┐           ┌──────────┐
│ Code     │ ───▶ │ Fitness  │ ───▶      │ Deployed │
│ Change   │      │ Eval     │           │ Code     │
└──────────┘      └────┬─────┘           └──────────┘
                       │
                  FAIL │
                       ▼
                 ┌──────────┐
                 │ Rejected │
                 │(extinct) │
                 └──────────┘
```

## Quality Gates

| Gate | Threshold | Selection Pressure | Trigger |
|------|-----------|-------------------|---------|
| `lint` | 0.60 | Low | Before git add |
| `commit` | 0.80 | Medium | Pre-commit hook |
| `test` | 0.85 | Medium-High | CI pipeline |
| `merge` | 0.90 | High | Pull request |
| `deploy` | 0.95 | Critical | Pre-deployment |

## Fitness Categories

| Category | Weight | Checks |
|----------|--------|--------|
| **Security** | 25% | Vulnerabilities, secrets, injection |
| **Architecture** | 25% | Patterns, coupling, layers |
| **Quality** | 25% | Complexity, duplication, coverage |
| **Performance** | 15% | Response time, memory, queries |
| **Operational** | 10% | Logging, monitoring, recovery |

## Usage

```bash
# Evaluate single file
/fitness lib/MyModule.pm

# Evaluate directory
/fitness src/

# Specific gate
/fitness --gate=commit lib/MyModule.pm

# Full report
/fitness --gate=deploy --report src/
```

## Output Format

```
FITNESS EVALUATION
==================
Target: lib/MyModule.pm
Gate: commit
Timestamp: 2026-02-09T23:30:00Z

SECURITY (25%)
--------------
[✓] No hardcoded secrets: 1.00
[✓] Input validation: 1.00
[✓] No SQL injection: 1.00
    Subtotal: 1.00

ARCHITECTURE (25%)
------------------
[✓] Layer compliance: 1.00
[✓] Pattern adherence: 0.90
[⚠] Coupling score: 0.75
    Subtotal: 0.88

QUALITY (25%)
-------------
[✓] Complexity (cyclomatic): 0.85
[✓] No duplication: 0.95
[⚠] Test coverage: 0.70
    Subtotal: 0.83

PERFORMANCE (15%)
-----------------
[✓] No N+1 queries: 1.00
[✓] Efficient algorithms: 0.90
    Subtotal: 0.95

OPERATIONAL (10%)
-----------------
[✓] Logging present: 1.00
[✓] Error handling: 1.00
    Subtotal: 1.00

═══════════════════════════════════════════════════
CATEGORY SCORES
---------------
Security:      1.00
Architecture:  0.88
Quality:       0.83
Performance:   0.95
Operational:   1.00
---------------
WEIGHTED TOTAL: 0.91

GATE THRESHOLD: 0.80 (commit)
STATUS: ✓ FIT - PROCEED
═══════════════════════════════════════════════════
```

## Failure Output

```
═══════════════════════════════════════════════════
WEIGHTED TOTAL: 0.72

GATE THRESHOLD: 0.80 (commit)
STATUS: ✗ UNFIT - BLOCKED

REQUIRED FIXES:
1. [Security] Hardcoded API key found at line 42
   → Move to environment variable
2. [Quality] Test coverage 45% (minimum 70%)
   → Add tests for untested functions
3. [Architecture] Direct database access in controller
   → Use repository pattern
═══════════════════════════════════════════════════
```

## Fitness Functions

### Security Functions
- `no_secrets` - No hardcoded credentials
- `input_validation` - All inputs validated
- `no_injection` - No SQL/command injection
- `dependency_audit` - No vulnerable dependencies

### Architecture Functions
- `layer_compliance` - Correct layer dependencies
- `pattern_adherence` - Design patterns followed
- `coupling_score` - Low coupling between modules
- `cohesion_score` - High cohesion within modules

### Quality Functions
- `complexity` - Cyclomatic complexity < threshold
- `duplication` - No significant code duplication
- `test_coverage` - Coverage meets minimum
- `documentation` - Public APIs documented

### Performance Functions
- `query_efficiency` - No N+1 queries
- `algorithm_complexity` - O(n) or better
- `resource_usage` - Memory/CPU within bounds

### Operational Functions
- `logging` - Appropriate logging present
- `error_handling` - Errors handled gracefully
- `observability` - Metrics/traces available

## Project Extension

Projects extend this skill with domain-specific fitness functions:

```yaml
---
name: fitness
extends: global:fitness
---

# Project Fitness

## Additional Functions
- `moose_structure` - Moose best practices
- `oracle_datetime` - Correct DateTime handling
- `ddd_layers` - DDD architecture compliance
```

## Integration

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit
/fitness --gate=commit $(git diff --cached --name-only)
```

### CI Pipeline

```yaml
# .github/workflows/ci.yml
- name: Fitness Check
  run: /fitness --gate=test src/
```

## See Also

- `/pre-commit` - Pre-commit quality checks
- `/code-review` - Comprehensive code review
- `/deploy` - Evolutionary deployment
