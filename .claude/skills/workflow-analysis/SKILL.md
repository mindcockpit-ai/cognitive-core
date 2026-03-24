---
name: workflow-analysis
description: Structured business workflow and feature analysis framework. Produces stakeholder maps, flow diagrams, implementation plans, and risk assessments.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, WebSearch
catalog_description: Business workflow analysis — stakeholder maps, flows, and risk assessments.
---

# Workflow Analysis — Business Analysis Framework

Provides structured analysis for new features, workflow changes, and business
process proposals. Language-agnostic; reads architecture pattern from
`CC_ARCHITECTURE` in `cognitive-core.conf`.

## Arguments

- `$ARGUMENTS` -- topic or feature to analyze
- `--depth=quick` -- 15-minute overview (stakeholders + high-level flow)
- `--depth=standard` -- full analysis (default)
- `--depth=deep` -- comprehensive with risk matrix, alternatives, migration plan

## Instructions

### Step 1: Context Gathering

1. Search docs for existing documentation on the topic
2. Search source tree for existing implementation
3. Check session docs for prior work
4. Read CLAUDE.md for architectural constraints

### Step 2: Produce Analysis

#### Quick (`--depth=quick`)

```
WORKFLOW ANALYSIS - [Topic]
===========================
STAKEHOLDERS: [Role]: [Interest/Impact]
CURRENT STATE: [What exists today]
PROPOSED FLOW: [Step 1] -> [Step 2] -> [Step 3]
RECOMMENDATION: [Proceed / needs analysis / blocked by X]
```

#### Standard (default)

```
WORKFLOW ANALYSIS - [Topic]
===========================
1. BUSINESS CONTEXT
   Problem / Value / Stakeholders

2. CURRENT STATE
   Existing modules / Data flow / Limitations

3. PROPOSED WORKFLOW
   Flow diagram / State transitions (if applicable)

4. ARCHITECTURE ALIGNMENT
   Layer mapping per CC_ARCHITECTURE pattern
   Existing patterns to reuse

5. IMPLEMENTATION ESTIMATE
   Phases / Effort / Dependencies

6. RISKS
   Risk / Impact / Likelihood / Mitigation

7. RECOMMENDATION
   Clear next steps with priorities
```

#### Deep (`--depth=deep`)

Adds to Standard:

```
8.  ALTERNATIVE APPROACHES
9.  SECURITY AND GOVERNANCE
10. MIGRATION PLAN
11. SUCCESS METRICS
12. DECISION LOG
```

### Step 3: Cross-Reference

After producing the analysis:
- Verify all referenced modules exist in the codebase
- Ensure proposed patterns align with CLAUDE.md conventions
- Flag gaps that need specialist input (testing, database, security)

## See Also

- `/project-status` -- Current project status
- `/fitness` -- Verify code fitness before commit
- `CLAUDE.md` -- Project standards
