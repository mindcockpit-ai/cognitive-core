# Recipe: Getting Started with Python / FastAPI

> **Time**: ~5 min | **Level**: Beginner | **Language**: Python / FastAPI

## Goal

Install cognitive-core on your Python project and run your first code review, tests, and security scan in under 5 minutes.

## Prerequisites

- A Python project with git initialized (FastAPI, Django, Flask, or plain Python)
- Claude Code CLI installed
- cognitive-core cloned: `git clone https://github.com/mindcockpit-ai/cognitive-core.git`

## Steps

### Step 1: Install

```bash
./cognitive-core/install.sh /path/to/your-python-project
```

When prompted:
- **Language**: `python`
- **Database**: your DB (or `none`)
- **Architecture**: `ddd` (or your pattern)
- Accept defaults for agents, skills, hooks

### Step 2: Start a Claude Code session

```bash
cd /path/to/your-python-project
claude
```

**First session output:**
```
FIRST SESSION: Welcome to cognitive-core!
Agents (6): coordinator reviewer architect tester researcher skill-updater
Skills (11): session-resume skill-sync code-review pre-commit fitness ...
Quick start: '@code-standards-reviewer review my code', '/code-review'
```

### Step 3: Run your first code review

```
/code-review src/services/user_service.py
```

**Expected output:**
```
CODE REVIEW — src/services/user_service.py
Standards:    3 PASS, 1 WARNING
Architecture: 2 PASS
Anti-patterns: 1 PASS
VERDICT: APPROVED with warnings
```

### Step 4: Create tests for a module

```
@test-specialist create unit tests for UserService
```

The agent generates pytest tests with:
- `@pytest.fixture` for setup/teardown
- `unittest.mock.patch` for dependency injection
- Async test support with `pytest-asyncio` (for FastAPI)
- Edge cases and error paths

### Step 5: Check for security issues

```
@security-analyst scan the authentication module for vulnerabilities
```

The agent checks for:
- Hardcoded secrets or tokens
- `shell=True` in subprocess calls
- Unsafe XML parsing (XXE)
- Weak hashing (MD5/SHA1 for passwords)
- SQL injection in raw queries

### Step 6: Check quality gates

```
/fitness
```

**Expected output:**
```
QUALITY FITNESS
Lint:     82% (target: 60%) PASS
Tests:    91% (target: 85%) PASS
VERDICT: PASS
```

## What Got Installed

| Component | Count | Examples |
|-----------|-------|---------|
| **Hooks** | 7 | validate-bash, validate-write, validate-read |
| **Agents** | 6 | @code-standards-reviewer, @test-specialist, @security-analyst |
| **Core Skills** | 8 | /code-review, /pre-commit, /fitness, /test-scaffold |
| **Python Skills** | 3 | python-patterns, python-ddd, python-messaging |
| **Rules** | 1 | testing.md (test files only) |

## Python Language Pack

The `python` language pack adds three domain skills:

| Skill | Purpose |
|-------|---------|
| `python-patterns` | Pythonic idioms, type hints, dataclasses, async patterns |
| `python-ddd` | Domain-Driven Design conventions for Python (entities, repositories, services) |
| `python-messaging` | Event-driven patterns with Python (Celery, RabbitMQ, Kafka consumers) |

These load automatically when the language is set to `python` in `cognitive-core.conf`.

## Expected Output

After completing all steps, you should have:
- cognitive-core installed with 7 hooks, 6 agents, and 11+ skills
- A code review report for at least one file
- Generated pytest test files for a module
- A security scan with findings (or clean bill of health)
- A passing fitness check

## Next Steps

- [Code Review Workflow](recipe-code-review.md) -- deep dive on `/code-review` vs `@code-standards-reviewer`
- [Test Creation](recipe-test-creation.md) -- `/test-scaffold` vs `@test-specialist`
- [Security Scan](recipe-security-scan.md) -- full security analysis workflow
- [Wrong Agent?](recipe-wrong-agent.md) -- what happens when you pick the wrong agent
