# Agent Team Architecture

## Hub-and-Spoke Model

The agent team follows a hub-and-spoke pattern where the **project-coordinator**
acts as the central orchestrator, delegating to specialist agents based on task type.

```
                         ┌───────────────────┐
                         │       USER        │
                         │    (Developer)    │
                         └─────────┬─────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│                  PROJECT-COORDINATOR (Hub)                   │
│                  Smart Orchestrator / Opus                   │
│                                                              │
│  • Analyze incoming requests                                 │
│  • Route to appropriate specialist                           │
│  • Coordinate multi-agent workflows                          │
│  • Synthesize results into unified response                  │
│  • Manage project board and sprint planning                  │
│                                                              │
└────────┬──────────┬──────────┬──────────┬──────────┬─────────┘
         │          │          │          │          │
         ▼          ▼          ▼          ▼          ▼
   ┌──────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
   │ solution │ │  code  │ │  test  │ │research│ │database│
   │ architect│ │reviewer│ │  spec  │ │ analyst│ │  spec  │
   │  (Opus)  │ │(Sonnet)│ │(Sonnet)│ │ (Opus) │ │ (Opus) │
   └──────────┘ └────────┘ └────────┘ └────────┘ └────────┘
```

## Agent Catalog

### project-coordinator (Hub)
- **File**: `project-coordinator.md` | **Model**: opus
- **Role**: Smart orchestrator — analyzes requests and delegates to specialists
- **Use when**: Project planning, multi-agent coordination, sprint planning, risk assessment, TODO creation
- **Don't use for**: Simple single-task requests, direct code implementation, single-domain tasks

### solution-architect
- **File**: `solution-architect.md` | **Model**: opus
- **Role**: Business workflows, architectural decisions, requirements analysis
- **Use when**: New feature design, workflow implementation, integration decisions, technical feasibility
- **Don't use for**: Code fixes, code review, test creation, DB performance, pure research

### code-standards-reviewer
- **File**: `code-standards-reviewer.md` | **Model**: sonnet
- **Role**: Code review, standards compliance, architecture pattern verification
- **Use when**: After code implementation, PR reviews, refactoring validation, standards verification
- **Don't use for**: Writing new code, business analysis, test creation, research
- **Restrictions**: No WebFetch, No WebSearch (reviews code, not web)

### test-specialist
- **File**: `test-specialist.md` | **Model**: sonnet
- **Role**: Unit/integration/UI tests, coverage analysis, QA strategy
- **Use when**: New code needs tests, test failures, coverage gaps, test refactoring
- **Don't use for**: Code implementation without test focus, business analysis, code review

### research-analyst
- **File**: `research-analyst.md` | **Model**: opus
- **Role**: External research, library evaluation, technology assessment, best practices
- **Use when**: Unknown technologies, error investigation, library selection, industry patterns
- **Don't use for**: Internal code questions, code review, test creation
- **Restrictions**: No Write, No Edit (research only, does not modify code)

### database-specialist
- **File**: `database-specialist.md` | **Model**: opus
- **Role**: Database optimization, query tuning, bulk operations, index analysis
- **Use when**: Slow queries, import performance, database design, bulk data operations
- **Don't use for**: Simple CRUD, business logic, code review without performance concerns

### security-analyst (optional)
- **File**: `security-analyst.md` | **Model**: opus
- **Role**: Offensive security, CTF mentoring, vulnerability analysis, forensic investigation
- **Use when**: Pentest, CTF challenges, vulnerability scanning, security code review, breach analysis
- **Don't use for**: General code review, business analysis, non-security tasks

## Keyword → Agent Routing

| Keywords in Request | Route To |
|---------------------|----------|
| "implement feature", "new workflow", "approval process", "design" | solution-architect |
| "review code", "check standards", "CLAUDE.md compliance", "refactor" | code-standards-reviewer |
| "write tests", "test coverage", "failing test", "QA" | test-specialist |
| "research", "best practice", "which library", "error investigation" | research-analyst |
| "slow query", "performance", "bulk import", "database", "index" | database-specialist |
| "plan project", "create TODO", "sprint", "coordinate", "board" | project-coordinator |
| "pentest", "CTF", "vulnerability", "exploit", "security scan" | security-analyst |

## Delegation Flow

1. Request arrives at **project-coordinator**
2. Coordinator analyzes and identifies required expertise
3. Delegates to appropriate specialist(s) with clear scope
4. Specialist completes work and reports back
5. Coordinator synthesizes results
6. **code-standards-reviewer** performs final quality gate (**MANDATORY** for code changes)

## Escalation Paths

```
code-standards-reviewer finds performance issue  → database-specialist
test-specialist finds architectural flaw          → solution-architect
database-specialist needs research                → research-analyst
security-analyst finds systemic vulnerability     → project-coordinator
Any agent blocked or needs cross-cutting work     → project-coordinator
```

## Mandatory Quality Gate

Every code change MUST include a code-standards-reviewer pass before completion:

```
[ ] Implementation tasks...
[ ] Unit tests (test-specialist)
[ ] Integration tests (test-specialist)
[ ] Code Standards Review (code-standards-reviewer) ← MANDATORY
[ ] Automated lint verification ← MANDATORY
[ ] Documentation update
```
