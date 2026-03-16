# Recipe: Project Coordinator — Autonomous Issue Workflow

> **Time**: ~3 min read | **Level**: Intermediate | **Language**: All

## Goal

Use `@project-coordinator` to pick up a GitHub issue, decompose it into tasks, delegate to specialist agents, implement the solution, verify acceptance criteria, and update the project board — all from a single instruction.

## Prerequisites

- cognitive-core installed with `@project-coordinator` agent
- GitHub issue with defined acceptance criteria
- Project board configured in `cognitive-core.conf` (`CC_PROJECT_NUMBER`, `CC_GITHUB_REPO`)

## The Power Move

Instead of manually coordinating agents, give the coordinator the issue and let it orchestrate:

```
@project-coordinator pick up issue #42 from the board, implement it,
verify acceptance criteria, and move it to Done when complete
```

That's it. The coordinator will:
1. Read the issue and acceptance criteria
2. Decompose into subtasks
3. Delegate to specialist agents
4. Track progress
5. Verify each acceptance criterion
6. Update the board

## Step-by-Step: What Happens Behind the Scenes

### Step 1: Coordinator reads the issue

```
@project-coordinator work on issue #42
```

**Coordinator thinks:**
```
Issue #42: "Add input validation to UserController"
Acceptance criteria:
- [ ] Validate email format on POST /api/users
- [ ] Validate password strength (min 8 chars, 1 uppercase, 1 number)
- [ ] Return 400 with structured error messages
- [ ] Unit tests for all validation rules

Decomposition:
1. Architecture review → @solution-architect (brief)
2. Implementation → direct coding
3. Test creation → @test-specialist
4. Code review → @code-standards-reviewer
5. Acceptance verification → /acceptance-verification #42
```

### Step 2: Coordinator delegates

The coordinator spawns agents in parallel where possible:

```
Delegating to @solution-architect:
  "Review the validation approach for UserController —
   should we use Bean Validation (@Valid) or manual validation?"

Delegating to @test-specialist:
  "Create JUnit 5 tests for email and password validation
   on POST /api/users — cover happy path + edge cases"
```

### Step 3: Coordinator implements

Based on the architect's recommendation, the coordinator writes the code directly or delegates further.

### Step 4: Coordinator verifies

```
Running /acceptance-verification #42

Checking: Validate email format on POST /api/users
Evidence: src/main/java/.../UserController.java:45 — @Email annotation
Result: ✓ PASS

Checking: Validate password strength
Evidence: src/main/java/.../PasswordValidator.java:12 — regex pattern
Result: ✓ PASS

Checking: Return 400 with structured error messages
Evidence: src/main/java/.../GlobalExceptionHandler.java:28
Result: ✓ PASS

Checking: Unit tests for all validation rules
Evidence: src/test/java/.../UserValidationTest.java — 8 test methods
Result: ✓ PASS

All acceptance criteria verified. Posting comment on #42.
```

### Step 5: Coordinator updates the board

```
Moving issue #42: In Progress → Done
Posting verification comment with evidence links
```

## Giving Better Instructions

The more context you give, the better the result:

**Minimal (works but less precise):**
```
@project-coordinator work on issue #42
```

**Better (guided delegation):**
```
@project-coordinator work on issue #42

Approach:
- Use Bean Validation annotations, not manual validation
- Follow our existing error response format in GlobalExceptionHandler
- Tests should use @WebMvcTest, not full integration tests
- Review against Spring Boot conventions in CLAUDE.md
```

**Full control (specify the agents):**
```
@project-coordinator work on issue #42

Plan:
1. @solution-architect: Quick review — Bean Validation vs manual (prefer Bean Validation)
2. Implement: Add @Valid to UserController, create PasswordValidator
3. @test-specialist: Create @WebMvcTest tests for all validation rules
4. @code-standards-reviewer: Review implementation against Spring Boot patterns
5. /acceptance-verification #42
6. Move to Done on board
```

## Managing Multiple Issues

```
@project-coordinator review the board, pick the top 3 issues
from the Todo column, and work through them in priority order
```

The coordinator will:
- Read the board state
- Identify prioritized issues
- Work through them sequentially
- Update board status as each completes

## Reacting to Feedback

After the coordinator finishes, you review and provide feedback:

```
@project-coordinator the validation on #42 looks good but:
- Add a check for disposable email domains
- The error message for password should list which rules failed

Update the implementation and re-verify acceptance criteria.
```

The coordinator adjusts, re-delegates if needed, and re-verifies.

## Common Mistakes

| Mistake | Why | Do This Instead |
|---------|-----|-----------------|
| No acceptance criteria on the issue | Coordinator can't verify completion | Always define checkboxes on the issue first |
| Micromanaging every agent call | Defeats the purpose of coordination | Give goals, not step-by-step tool calls |
| Skipping the review step | Coordinator may implement but not verify quality | Always include `@code-standards-reviewer` in the workflow |
| Not checking the board after | Board may need manual status adjustment | Verify the board reflects the actual state |

## Why This Is Powerful

Traditional workflow: You read the issue, decide the approach, write code, write tests, review, verify, update the board. **~2 hours**.

Coordinator workflow: One instruction. The coordinator reads, plans, delegates, implements, tests, reviews, verifies, and updates. **~15 minutes of your attention**.

You stay in the loop — you see every delegation, every finding, every verification. But you're directing, not executing.

## Next Steps

- [Code Review Workflow](recipe-code-review.md) — understand what `@code-standards-reviewer` does during delegation
- [Wrong Agent?](recipe-wrong-agent.md) — the coordinator's Smart Delegation prevents this
- [Getting Started — Java](getting-started-java.md) — if you haven't installed yet
