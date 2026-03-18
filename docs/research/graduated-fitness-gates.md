# Graduated Fitness Gates (60 → 95%)

**Status**: Implemented | **Category**: Novel — no unified progressive model exists
**Location**: `core/skills/fitness/SKILL.md`, `cicd/scripts/fitness-check.sh`, `cognitive-core.conf`

---

## Problem

Code quality enforcement in CI/CD pipelines is typically binary: pass or fail against a single threshold. SonarQube defines one quality gate per project. Azure DevOps branch policies are pass/fail. This creates a problem:

- A strict threshold (95%) blocks developers from committing experimental code early
- A lenient threshold (60%) lets low-quality code reach production
- Teams compromise with a single "good enough" threshold that serves neither purpose well

Neal Ford's "Building Evolutionary Architectures" introduced architectural fitness functions — objective integrity checks for architectural characteristics. But the book does not prescribe graduated numeric thresholds across pipeline stages.

## Solution

Five configurable quality thresholds that increase as code moves toward production:

```
Lint     →  Commit   →  Test     →  Merge    →  Deploy
 60%         80%         85%         90%         95%
```

| Gate | Threshold | Trigger | On Fail | Rationale |
|------|-----------|---------|---------|-----------|
| **Lint** | 60% | Before staging | Block | Low bar — allows iteration and exploration |
| **Commit** | 80% | Pre-commit | Reject | Moderate — code should be reviewable |
| **Test** | 85% | Pre-merge | Block merge | Higher — must pass integration |
| **Merge** | 90% | Pull request | Block merge | Near-production quality |
| **Deploy** | 95% | Pre-deploy | Abort | Production-ready, minimal risk |

### Fitness Functions

Each gate evaluates 4 categories:

**Code Standards Fitness**: lint pass, format check, naming conventions, error handling patterns
**Architecture Fitness**: layer dependencies, domain purity, no anti-patterns
**Test Fitness**: test existence for new modules, test suite passes
**Security Fitness**: no hardcoded credentials, parameterized queries, input validation

### Scoring

```
FITNESS EVALUATION
==================
Target: src/
Gate:   merge

CATEGORY SCORES
  Code Standards:  0.92
  Architecture:    0.88
  Tests:           0.91
  Security:        0.95
  ─────────────────
  OVERALL:         0.92

GATE THRESHOLD:  90% (merge gate)
STATUS: FIT — PASSED
```

## Configuration

```bash
# cognitive-core.conf
CC_FITNESS_LINT=60       # Lint gate threshold
CC_FITNESS_COMMIT=80     # Commit gate threshold
CC_FITNESS_TEST=85       # Test gate threshold
CC_FITNESS_MERGE=90      # Merge gate threshold
CC_FITNESS_DEPLOY=95     # Deploy gate threshold
```

Teams can adjust thresholds to match their maturity level. A new team might start with 50/70/75/80/90 and gradually increase.

## Competitive Analysis

| Tool | Quality Gates | Progressive Thresholds | Unified Scoring |
|------|-------------|----------------------|-----------------|
| **cognitive-core** | 5 gates across pipeline | Yes — 60/80/85/90/95 | Yes — single 0-1 score |
| SonarQube | 1 per project | No — same threshold everywhere | Partial — per-metric |
| JetBrains Qodana | 1 per pipeline | No — single pass/fail | Yes |
| Azure DevOps | Branch policies per PR | No — binary pass/fail | No |
| GitLab | Code quality in MRs | No — single report | Partial |
| Neal Ford (concept) | Fitness functions | Conceptual — no prescribed model | No |
| AWS (blog) | Fitness in CI/CD | Single-threshold pass/fail | No |

## Research Sources

| Finding | Source | Authority |
|---------|--------|-----------|
| SonarQube quality gates: single threshold per project | SonarQube official docs | T1 |
| Qodana: single pass/fail threshold | JetBrains Qodana docs | T1 |
| Neal Ford fitness functions: no graduated thresholds | O'Reilly "Building Evolutionary Architectures" | T1 |
| AWS fitness functions: single-threshold pass/fail | AWS Architecture Blog | T1 |
| No tool combines fitness functions + progressive thresholds | Survey of SonarQube, Qodana, Azure DevOps, GitLab docs | T1 |
| InfoQ: quality gates at multiple stages are configured independently | InfoQ article on pipeline quality gates | T2 |

## Impact

The graduated model creates a quality ramp that matches the increasing confidence required at each stage. Developers can iterate freely at the lint stage (60%) while the deploy gate ensures production-ready quality (95%). The 5-point spread between gates (80/85/90/95) creates meaningful differentiation — if all gates used the same threshold, the intermediate gates would add no value.

## Implementation in cognitive-core

### Files

| File | Role |
|------|------|
| [`core/skills/fitness/SKILL.md`](../../core/skills/fitness/SKILL.md) | Skill definition — 4 fitness categories, 5 gates, scoring output format |
| [`cognitive-core.conf`](../../cognitive-core.conf) | Configuration — `CC_FITNESS_LINT=60`, `CC_FITNESS_COMMIT=80`, etc. |
| [`cicd/scripts/fitness-check.sh`](../../cicd/scripts/fitness-check.sh) | CI script — evaluates fitness score against gate threshold |
| [`cicd/scripts/push-metrics.sh`](../../cicd/scripts/push-metrics.sh) | Metrics — pushes fitness scores to monitoring (Prometheus) |
| [`cicd/workflows/evolutionary-cicd.yml`](../../cicd/workflows/evolutionary-cicd.yml) | CI pipeline — runs fitness checks at each stage |

### How It Works

1. Developer invokes `/fitness --gate=merge` (or CI runs it automatically)
2. Skill evaluates 4 categories:
   - **Code Standards** — lint pass, format check, naming, error handling
   - **Architecture** — layer dependencies, domain purity, anti-pattern absence
   - **Tests** — test existence for new modules, test suite passes
   - **Security** — no hardcoded credentials, parameterized queries, input validation
3. Each category produces a 0.00-1.00 score
4. Overall score is compared against the gate threshold
5. Output: `FIT — PASSED` or `UNFIT — BLOCKED` with required fixes

### Configuration

```bash
# cognitive-core.conf — adjustable per project maturity
CC_FITNESS_LINT=60       # Low bar for local iteration
CC_FITNESS_COMMIT=80     # Moderate for reviewable code
CC_FITNESS_TEST=85       # Higher for merge readiness
CC_FITNESS_MERGE=90      # Near-production quality
CC_FITNESS_DEPLOY=95     # Production-ready
CC_LINT_COMMAND="bash -n" # Shell syntax check (default for bash projects)
CC_TEST_COMMAND="bash tests/run-all.sh"
```

### Test Coverage

| Suite | Tests | What It Validates |
|-------|-------|-------------------|
| Suite 02 — Skill Frontmatter | 64 | fitness SKILL.md has valid YAML frontmatter (name, description, allowed-tools, context:fork) |
| Suite 01 — ShellCheck | 39 | fitness-check.sh passes shell syntax validation |
| Suite 04 — Install Dry-Run | 44 | fitness skill installed correctly in target project |

### Verification

The fitness skill is installed in the cognitive-core repo itself and used in CI. The reference implementation TIMS scored 4.2/5 in an independent workflow audit, with "Code Quality 5.0/5" directly attributed to the multi-layer enforcement including fitness gates.
