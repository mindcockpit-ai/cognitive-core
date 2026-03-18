---
name: batch-review
description: Batch processing strategies for large-scale code review, migration, and multi-file operations. Selects the optimal execution tier based on workload size and dependency structure.
user-invocable: true
context: fork
allowed-tools: Bash, Read, Grep, Glob
argument-hint: "Number of items or directory to batch-process"
catalog_description: Batch processing — agent swarms, API batches, and sequential chains.
---

# Batch Processing — Scalable Multi-Item Operations

Provides structured strategies for processing large workloads (code reviews,
migrations, refactors, test generation) that exceed single-pass capacity.
Selects the optimal execution tier based on item count, dependency structure,
and required consistency.

## Arguments: `$ARGUMENTS` -- item count, directory, or file list

## Tier Selection

Analyze the workload and select the appropriate processing tier:

```
Item count / dependency structure:
├── 1-5 items, independent        → Direct (single pass, no batching needed)
├── 5-20 items, independent       → Tier 1: Agent Swarms
├── >50 items, independent        → Tier 2: Structured Batch
└── Any count, dependency chain   → Tier 3: Sequential Pipeline
```

| Tier | Strategy | Best For | Parallelism |
|------|----------|----------|-------------|
| Direct | Single-pass review | Small changes | None needed |
| **Tier 1** | Agent Swarms | PR reviews, multi-file refactor | High (5-20 parallel) |
| **Tier 2** | Structured Batch | Migrations, bulk linting, mass updates | Very high (50+ async) |
| **Tier 3** | Sequential Pipeline | Dependency chains, ordered migrations | None (strict order) |

## Tier 1: Agent Swarms (5-20 items)

Spawn parallel agents, each handling one independent unit of work. Aggregate
results after all agents complete.

### When to Use
- Pull request reviews across 5-20 files
- Multi-file refactoring (rename, pattern replacement)
- Test generation for a module
- Documentation updates across related files

### Process

1. **Decompose**: Split work into independent units (one per file or module)
2. **Spawn**: Each unit runs in an isolated `context: fork` agent
3. **Execute**: Agents work in parallel — no shared state between units
4. **Aggregate**: Collect results, deduplicate findings, resolve contradictions
5. **Consolidate**: Produce unified report with cross-cutting analysis

### Output Format

```
BATCH REVIEW — Agent Swarm
===========================
Strategy: Tier 1 (N parallel agents)
Scope: [directory or file list]

UNIT RESULTS
------------
[unit-1]: [file/module] — [PASS/FAIL] — [N findings]
[unit-2]: [file/module] — [PASS/FAIL] — [N findings]
...

CROSS-CUTTING ANALYSIS
----------------------
- [Pattern found across multiple units]
- [Inconsistency between unit-X and unit-Y]

CONSOLIDATED FINDINGS
---------------------
| # | Severity | Finding | Files Affected | Fix |
|---|----------|---------|----------------|-----|

SUMMARY
=======
Units: N processed, N passed, N failed
Findings: N critical, N warning, N info
```

### Integration with Multi-Pass Review

For code review batches, combine with the multi-pass strategy from
`/code-review`:
- **Pass 1** (per-unit): Each swarm agent does local file analysis
- **Pass 2** (cross-file): Aggregator analyzes integration patterns
- **Pass 3** (consolidation): Deduplicate and prioritize findings

## Tier 2: Structured Batch (>50 items)

For large-scale operations exceeding agent swarm capacity, use structured
batch requests with async processing.

### When to Use
- Codebase-wide migrations (API version upgrades, import rewrites)
- Bulk lint/format across 50+ files
- Mass test generation for untested modules
- Large-scale documentation generation

### Process

1. **Inventory**: List all items to process with metadata
2. **Classify**: Group items by type, priority, and processing requirements
3. **Template**: Create a processing template per item class
4. **Submit**: Batch items as structured requests (one per item)
5. **Monitor**: Track completion status, handle failures
6. **Verify**: Validate results against acceptance criteria per item

### Batch Request Structure

Each item in the batch follows a structured format:

```
BATCH ITEM [N/TOTAL]
====================
ID: [unique identifier]
Type: [review|migrate|lint|test|doc]
Input: [file path or content reference]
Template: [processing template name]
Priority: [critical|high|normal|low]
Dependencies: [none | item-IDs that must complete first]

EXPECTED OUTPUT
---------------
Format: [structured finding | diff | report]
Validation: [acceptance criteria for this item]
```

### Output Format

```
BATCH PROCESSING REPORT
========================
Strategy: Tier 2 (structured batch)
Total items: N
Completed: N | Failed: N | Skipped: N

RESULTS BY CLASS
-----------------
[class-1]: N items — N passed, N failed
[class-2]: N items — N passed, N failed

FAILURES
--------
[item-ID]: [error description] — [retry|skip|escalate]

SUMMARY
=======
Success rate: N%
Duration: [wall-clock time]
```

## Tier 3: Sequential Pipeline (dependency chains)

For workloads where items depend on each other, process in strict dependency
order. Each step's output feeds the next step's input.

### When to Use
- Database migration sequences (must run in order)
- Multi-step refactoring (rename type, then update all references, then update tests)
- Ordered deployment steps
- Chained data transformations

### Process

1. **Map dependencies**: Build a dependency graph of all items
2. **Topological sort**: Determine execution order
3. **Validate chain**: Ensure no circular dependencies
4. **Execute sequentially**: Process each item, pass output to next
5. **Gate each step**: Verify step N succeeded before starting step N+1
6. **Rollback plan**: Define rollback actions if a step fails mid-chain

### Pipeline Definition

```
SEQUENTIAL PIPELINE
====================
Steps: N (strict order)
Rollback: [available|not-available]

STEP 1: [description]
  Input: [source]
  Action: [what to do]
  Gate: [success criteria before proceeding]
  Rollback: [how to undo if later steps fail]

STEP 2: [description]
  Input: [output of step 1]
  Action: [what to do]
  Gate: [success criteria]
  Rollback: [undo action]

...
```

## Examples

**User**: "Review all 12 changed files in this PR."
**Skill**: Selecting Tier 1 (Agent Swarm) — 12 independent files.

Decomposition:
- 12 parallel review agents (one per file)
- Each agent applies `/code-review` checks independently
- Aggregator runs cross-file integration analysis

```
BATCH REVIEW — Agent Swarm
===========================
Strategy: Tier 1 (12 parallel agents)
Scope: PR #142 — feat(auth): add OAuth2 provider

UNIT RESULTS
------------
src/auth/provider.ts    — FAIL — 2 findings (1 critical, 1 warning)
src/auth/callback.ts    — PASS — 0 findings
src/auth/types.ts       — PASS — 0 findings
src/config/oauth.ts     — FAIL — 1 finding (1 warning)
tests/auth/provider.test.ts — PASS — 0 findings
... (7 more units)

CROSS-CUTTING ANALYSIS
----------------------
- Token handling inconsistency: provider.ts uses raw strings, callback.ts uses typed TokenResponse
- Missing error propagation: OAuth errors in provider.ts not caught in callback.ts

CONSOLIDATED FINDINGS
---------------------
| # | Severity | Finding | Files | Fix |
|---|----------|---------|-------|-----|
| 1 | critical | SQL injection in token storage | provider.ts:87 | Use parameterized query |
| 2 | warning  | Inconsistent token types | provider.ts, callback.ts | Unify on TokenResponse |
| 3 | warning  | Magic string "bearer" | oauth.ts:12 | Extract to AUTH_SCHEME constant |

SUMMARY: 12 units, 9 passed, 3 findings (1 critical)
```

**User**: "Migrate 200 files from CommonJS to ESM imports."
**Skill**: Selecting Tier 2 (Structured Batch) — 200 independent items, uniform transformation.

```
BATCH PROCESSING REPORT
========================
Strategy: Tier 2 (structured batch)
Total items: 200

RESULTS BY CLASS
-----------------
Source files (src/):  142 items — 140 passed, 2 failed
Test files (tests/):   48 items — 48 passed, 0 failed
Config files:          10 items — 10 passed, 0 failed

FAILURES
--------
src/legacy/compat.js: Circular require() — cannot auto-migrate (escalate to human)
src/plugins/loader.js: Dynamic require() — needs manual review (escalate to human)

SUMMARY: 198/200 succeeded (99%), 2 escalated for manual review
```

**User**: "Run the 5-step database migration for the schema upgrade."
**Skill**: Selecting Tier 3 (Sequential Pipeline) — ordered dependency chain.

```
SEQUENTIAL PIPELINE
====================
Steps: 5 (strict order)
Rollback: available

STEP 1: Add new columns (non-breaking)
  Gate: All ALTER TABLE statements succeed
  Rollback: DROP COLUMN for each added column
  Status: COMPLETE

STEP 2: Backfill data from legacy columns
  Gate: Row count matches, no NULL in required fields
  Rollback: UPDATE to restore original values
  Status: COMPLETE

STEP 3: Update application code to use new columns
  Gate: All tests pass with new schema
  Rollback: git revert
  Status: COMPLETE

STEP 4: Drop legacy columns
  Gate: No references to old column names in codebase
  Rollback: NOT AVAILABLE (data loss) — snapshot taken before step
  Status: PENDING

STEP 5: Update indexes and constraints
  Gate: EXPLAIN shows expected query plans
  Status: BLOCKED (waiting on step 4)
```

## See Also

- `/code-review` -- Single-file and multi-pass code review
- `/fitness` -- Quality fitness scoring
- `@project-coordinator` -- Orchestrates batch work across agents
