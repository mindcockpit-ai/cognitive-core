# Recipe: Test Creation Workflow

> **Time**: ~3 min read | **Level**: Beginner | **Language**: All

## Goal

Create tests for your project using cognitive-core's two testing tools -- the `/test-scaffold` skill for generating test file structures and `@test-specialist` for complete, runnable tests with edge cases.

## Prerequisites

- cognitive-core installed (`./install.sh /path/to/project`)
- `CC_TEST_COMMAND` set in `cognitive-core.conf` (e.g., `pytest`, `jest`, `mvn test`)
- At least one source module to test

## Steps

### Step 1: Generate a test scaffold

Use `/test-scaffold` to create a correctly structured test file for any source module:

```
/test-scaffold src/utils/parser.js
```

**Expected output:**
```
TEST SCAFFOLD GENERATED
=======================
Source:  src/utils/parser.js
Test:    __tests__/utils/parser.test.js
Type:    Utility
Methods: 4 public methods scaffolded
Run:     npm test __tests__/utils/parser.test.js
```

The scaffold includes imports, test groups for each public function, and `// FILL:` markers where you need to add assertions.

### Step 2: Fill in the scaffold with @test-specialist

Hand the scaffold to `@test-specialist` to generate complete test logic:

```
@test-specialist complete the test scaffold at __tests__/utils/parser.test.js with edge cases
```

The agent reads the source module and the scaffold, then fills in:
- Assertions for return values and side effects
- Edge cases (null input, empty string, boundary values)
- Error path tests (invalid input, thrown exceptions)
- Setup/teardown for stateful tests

### Step 3: Run the tests

```
npm test __tests__/utils/parser.test.js
```

Or let the agent run them:

```
@test-specialist run the tests and fix any failures
```

### Step 4: Check coverage with /fitness

```
/fitness --gate=test
```

**Expected output:**
```
QUALITY FITNESS (test gate)
Tests:    92% (target: 85%) PASS
VERDICT: PASS
```

## When to Use Which Tool

| Situation | Tool | Why |
|-----------|------|-----|
| Need a test file with correct structure | `/test-scaffold` | Fast, creates conventions-compliant file |
| Need complete tests with real assertions | `@test-specialist` | Reads source code, generates meaningful tests |
| Need both structure and content | `/test-scaffold` then `@test-specialist` | Scaffold first, fill second |
| Need tests for a whole module (5+ files) | `@test-specialist create tests for the auth module` | Handles multi-file analysis |

## Language-Specific Examples

### Python (pytest)

```
/test-scaffold src/services/user_service.py
@test-specialist complete the tests with fixtures and mocks
```

Generates `tests/services/test_user_service.py` with `@pytest.fixture`, `unittest.mock.patch`, and async support.

### Java (JUnit 5)

```
/test-scaffold src/main/java/com/example/UserService.java
@test-specialist complete with Spring Boot test annotations
```

Generates `src/test/java/com/example/UserServiceTest.java` with `@ExtendWith(MockitoExtension.class)` and `@Mock` annotations.

### Node.js (Jest)

```
/test-scaffold src/middleware/auth.js
@test-specialist complete with supertest for HTTP tests
```

Generates `__tests__/middleware/auth.test.js` with `jest.mock()` and Supertest for endpoint testing.

## Expected Output

After completing the workflow, you should have:
- A test file in the correct location following project conventions
- Complete test cases covering happy paths, edge cases, and error paths
- Passing tests when run with your project's test command
- A fitness check confirming test coverage meets the target

## Next Steps

- [Code Review Workflow](recipe-code-review.md) -- review the generated tests
- [Security Scan](recipe-security-scan.md) -- check that test fixtures don't contain hardcoded secrets
- [Getting Started with Java](getting-started-java.md) -- full walkthrough for Java projects
- [Getting Started with Python](getting-started-python.md) -- full walkthrough for Python projects
