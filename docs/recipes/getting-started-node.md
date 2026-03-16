# Recipe: Getting Started with Node.js / React

> **Time**: ~5 min | **Level**: Beginner | **Language**: Node.js / React

## Goal

Install cognitive-core on your Node.js or React project and run your first code review, tests, and security scan in under 5 minutes.

## Prerequisites

- A Node.js project with git initialized (Express, Next.js, React, or plain Node)
- Claude Code CLI installed
- cognitive-core cloned: `git clone https://github.com/mindcockpit-ai/cognitive-core.git`

## Steps

### Step 1: Install

```bash
./cognitive-core/install.sh /path/to/your-node-project
```

When prompted:
- **Language**: `node` (or `react` for React-specific rules)
- **Database**: your DB (or `none`)
- **Architecture**: `layered` (or your pattern)
- Accept defaults for agents, skills, hooks

### Step 2: Start a Claude Code session

```bash
cd /path/to/your-node-project
claude
```

**First session output:**
```
FIRST SESSION: Welcome to cognitive-core!
Agents (6): coordinator reviewer architect tester researcher skill-updater
Skills (9): session-resume skill-sync code-review pre-commit fitness ...
Quick start: '@code-standards-reviewer review my code', '/code-review'
```

### Step 3: Run your first code review

```
/code-review src/routes/auth.js
```

**Expected output:**
```
CODE REVIEW — src/routes/auth.js
Standards:    4 PASS, 1 WARNING
Architecture: 2 PASS
Anti-patterns: 1 PASS
VERDICT: APPROVED with warnings
```

### Step 4: Create tests for a module

```
@test-specialist create unit tests for the auth middleware
```

The agent generates Jest/Vitest tests with:
- `describe`/`it` blocks per exported function
- `jest.mock()` for dependency isolation
- Supertest for HTTP endpoint tests (Express)
- Both happy-path and error-path cases

### Step 5: Check for security issues

```
@security-analyst scan this Express app for security vulnerabilities
```

The agent checks for:
- Missing `helmet` middleware for HTTP headers
- SQL injection in raw queries (Knex, Sequelize)
- `eval()` or `Function()` with user input
- Missing CSRF protection
- Insecure `Math.random()` for tokens (should use `crypto.randomUUID()`)

### Step 6: Check quality gates

```
/fitness
```

**Expected output:**
```
QUALITY FITNESS
Lint:     85% (target: 60%) PASS
Tests:    79% (target: 85%) WARN
VERDICT: WARN — test coverage below target
```

## What Got Installed

| Component | Count | Examples |
|-----------|-------|---------|
| **Hooks** | 7 | validate-bash, validate-write, validate-read |
| **Agents** | 6 | @code-standards-reviewer, @test-specialist, @security-analyst |
| **Core Skills** | 8 | /code-review, /pre-commit, /fitness, /test-scaffold |
| **Node Skills** | 1 | node-messaging |
| **Rules** | 1 | testing.md (test files only) |

## A Note on Language Packs

The Node.js language pack currently includes one domain skill (`node-messaging` for event-driven patterns). The framework's core agents and skills work fully without a language pack -- `/code-review`, `@test-specialist`, `@security-analyst`, and all other core features adapt to JavaScript/TypeScript automatically based on your project's files and `cognitive-core.conf`.

If you use React, install with `react` as the language to get React-specific rules and patterns.

## Expected Output

After completing all steps, you should have:
- cognitive-core installed with 7 hooks, 6 agents, and 9+ skills
- A code review report for at least one file
- Generated Jest/Vitest test files for a module
- A security scan with findings and recommendations
- A fitness check showing quality gate status

## Next Steps

- [Code Review Workflow](recipe-code-review.md) -- deep dive on `/code-review` vs `@code-standards-reviewer`
- [Test Creation](recipe-test-creation.md) -- `/test-scaffold` vs `@test-specialist`
- [Security Scan](recipe-security-scan.md) -- full security analysis workflow
- [Wrong Agent?](recipe-wrong-agent.md) -- what happens when you pick the wrong agent
