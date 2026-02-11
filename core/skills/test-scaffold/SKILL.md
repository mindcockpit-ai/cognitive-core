---
name: test-scaffold
description: Generate test file scaffolds for project modules. Language-agnostic; reads CC_TEST_COMMAND and CC_TEST_PATTERN from config.
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Grep, Glob, Write
---

# Test Scaffold — Test File Generator

Generates correctly structured test files based on the project's language,
architecture, and testing conventions. Reads configuration from
`cognitive-core.conf` and conventions from CLAUDE.md.

## Arguments

- `$ARGUMENTS` -- source module path to generate tests for
- `--type=<type>` -- override auto-detected test type

## Configuration Reference

From `cognitive-core.conf`:
- `CC_LANGUAGE` -- determines test file format and runner
- `CC_TEST_COMMAND` -- test runner command (e.g., `pytest`, `jest`, `prove -l`)
- `CC_TEST_PATTERN` -- test file glob (e.g., `tests/**/*.py`, `t/**/*.t`)
- `CC_TEST_ROOT` -- test directory (e.g., `tests`, `t`, `__tests__`)
- `CC_ARCHITECTURE` -- determines layer detection and mock strategy
- `CC_SRC_ROOT` -- source root for path mapping

## Instructions

### Step 1: Analyze the Source Module

Read the module at the given path. Extract:
- Module/class/function name
- Public interface (methods, functions, exports)
- Dependencies (imports, injections)
- Whether it uses database or external services

### Step 2: Determine Test Location

Map source path to test path using `CC_SRC_ROOT` and `CC_TEST_ROOT`:

```
{CC_SRC_ROOT}/[path]/Module  ->  {CC_TEST_ROOT}/[path]/test_module
```

Respect language conventions for test file naming:
- Python: `test_module.py`
- JavaScript: `module.test.js` or `module.spec.js`
- Perl: `module.t`
- Go: `module_test.go`
- Java: `ModuleTest.java`
- Rust: inline `#[cfg(test)]` or `tests/module.rs`

### Step 3: Detect Architectural Layer

Based on `CC_ARCHITECTURE` and file path, determine the layer:
- **Domain/Model** -- pure unit tests, no mocks needed
- **Repository/Data** -- mock database, verify queries
- **Service/Use-case** -- mock dependencies, test orchestration
- **Controller/Handler** -- integration or HTTP tests
- **Mapper/DTO** -- transformation tests with edge cases

### Step 4: Generate Test File

Include in every generated test:
1. Language-appropriate test framework imports
2. Source module import
3. Setup and teardown if needed
4. One test group per public method/function
5. Both positive and negative test cases
6. Comments marked `# FILL:` where manual input is needed

### Step 5: Report

```
TEST SCAFFOLD GENERATED
=======================
Source:  [source path]
Test:    [generated test path]
Type:    [detected layer]
Methods: [N] public methods scaffolded
Run:     [CC_TEST_COMMAND] [test path]
```

## See Also

- `/code-review` -- Review generated test code
- `/pre-commit` -- Lint check before committing tests
- `/fitness --gate=test` -- Verify test fitness
