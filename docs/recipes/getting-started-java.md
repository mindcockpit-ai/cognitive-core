# Recipe: Getting Started with Java / Spring Boot

> **Time**: ~5 min | **Level**: Beginner | **Language**: Java / Spring Boot

## Goal

Install cognitive-core on your Spring Boot project and run your first code review in under 5 minutes.

## Prerequisites

- A Spring Boot project with git initialized
- Claude Code CLI installed
- cognitive-core cloned: `git clone https://github.com/mindcockpit-ai/cognitive-core.git`

## Steps

### Step 1: Install

```bash
./cognitive-core/install.sh /path/to/your-spring-boot-project
```

When prompted:
- **Language**: `spring-boot`
- **Database**: your DB (or `none`)
- **Architecture**: `ddd` (or your pattern)
- Accept defaults for agents, skills, hooks

**Expected output:**
```
✓ Installed 7 hooks
✓ Installed 6 agents
✓ Installed 8 skills + 4 Spring Boot skills
✓ Generated CLAUDE.md
✓ Generated .claude/AGENTS_README.md
Installation complete!
```

### Step 2: Start a Claude Code session

```bash
cd /path/to/your-spring-boot-project
claude
```

**First session output:**
```
FIRST SESSION: Welcome to cognitive-core!
Agents (6): coordinator reviewer architect tester researcher skill-updater
Skills (12): session-resume skill-sync code-review pre-commit fitness ...
Quick start: '@code-standards-reviewer review my code', '/code-review'
```

### Step 3: Run your first code review

```
/code-review src/main/java/com/example/
```

**Expected output:**
```
CODE REVIEW — src/main/java/com/example/
Standards:    3 PASS, 1 WARNING
Architecture: 2 PASS
Anti-patterns: 1 PASS
VERDICT: APPROVED with warnings
```

### Step 4: Create tests for a service

```
@test-specialist create unit tests for UserService
```

The agent generates complete JUnit 5 tests with:
- `@WebMvcTest` for controllers
- `@DataJpaTest` for repositories
- Mockito for service layer
- Testcontainers for integration tests

### Step 5: Check quality gates

```
/fitness
```

**Expected output:**
```
QUALITY FITNESS
Lint:     78% (target: 60%) ✓
Tests:    87% (target: 85%) ✓
VERDICT: PASS
```

### Step 6: Pre-commit check

```
/pre-commit
```

Runs `./mvnw checkstyle:check` (or `./gradlew checkstyleMain`) on staged files.

## What Got Installed

| Component | Count | Examples |
|-----------|-------|---------|
| **Hooks** | 8 | validate-bash, validate-write, spring-boot-version-guard |
| **Agents** | 6 | @code-standards-reviewer, @test-specialist, @solution-architect |
| **Core Skills** | 8 | /code-review, /pre-commit, /fitness, /project-board |
| **Spring Skills** | 4 | spring-boot-testing, spring-boot-patterns, spring-boot-migration |
| **Rules** | 2 | testing.md (test files only), spring-conventions.md (Java files only) |

## Your Agent Team

| Agent | Use When |
|-------|----------|
| `@code-standards-reviewer` | "Review my code" — multi-file review with findings |
| `@test-specialist` | "Create tests" — generates complete, runnable tests |
| `@solution-architect` | "Design this feature" — architecture trade-off analysis |
| `@project-coordinator` | "Plan the sprint" — task breakdown and delegation |
| `@research-analyst` | "Which library for X?" — external research and comparison |
| `@skill-updater` | "/skill-sync" — update skills from framework |

## Common Mistakes

| Mistake | Why It's Wrong | Do This Instead |
|---------|---------------|-----------------|
| `@solution-architect review my code` | Wrong agent — solution-architect does architecture, not code review | `@code-standards-reviewer review my code` |
| `@test-specialist fix the bug` | Test specialist creates tests, doesn't fix code | Fix code directly, then `@test-specialist create tests` |
| Skip `/fitness` before commit | Bypasses quality gates | Always `/fitness` before `git commit` |
| Review + implement in one prompt | Mixing concerns — review should be independent | Separate turns: review first, then implement fixes |

## Complete Feature Workflow

```
1. @solution-architect design a new /api/users endpoint with pagination
2. [Implement UserController.java, UserService.java, UserRepository.java]
3. /test-scaffold src/main/java/.../UserController.java
4. @test-specialist complete the test scaffold with edge cases
5. /pre-commit
6. @code-standards-reviewer review the user endpoint implementation
7. /fitness
8. git commit -m "feat(api): add user endpoint with pagination"
```

## Next Steps

- [Code Review Workflow](recipe-code-review.md) — deep dive on `/code-review` vs `@code-standards-reviewer`
- [Wrong Agent?](recipe-wrong-agent.md) — what happens when you pick the wrong agent
- [Test Creation](recipe-test-creation.md) — `/test-scaffold` vs `@test-specialist`
