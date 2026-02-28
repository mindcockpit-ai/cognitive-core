---
name: pre-commit
description: Run configured lint and syntax checks on staged or specified files before committing.
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Grep, Glob
catalog_description: Lint and syntax checks on staged files before committing.
---

# Pre-Commit — Lint and Syntax Checks

Runs the project's configured lint command on staged files or files passed as
arguments. Uses `CC_LINT_COMMAND` and `CC_LINT_EXTENSIONS` from
`cognitive-core.conf`.

## Arguments

- `$ARGUMENTS` -- specific files to check (optional; defaults to staged files)

## Configuration Reference

From `cognitive-core.conf`:
- `CC_LINT_COMMAND` -- lint command to run (`$1` = file path)
- `CC_FORMAT_COMMAND` -- optional format check (`$1` = file path)
- `CC_LINT_EXTENSIONS` -- file extensions to check (e.g., `.py .js`)

## Instructions

### Step 1: Determine Files to Check

If `$ARGUMENTS` provided, use those files. Otherwise, detect staged files:

```bash
git diff --cached --name-only --diff-filter=ACM
```

Filter to files matching `CC_LINT_EXTENSIONS`.

### Step 2: Run Lint

For each file, execute the configured lint command:

```bash
# Lint check
eval "$CC_LINT_COMMAND $file"

# Format check (if CC_FORMAT_COMMAND is set)
eval "$CC_FORMAT_COMMAND $file"
```

### Step 3: Report Results

```
PRE-COMMIT CHECK
=================

STAGED FILES (N):
  [file1]
  [file2]

CHECKING: [file]
  Lint:   [PASS/FAIL] [detail if failed]
  Format: [PASS/FAIL] [detail if failed]

SUMMARY
=======
Files checked: N
Passed: N
Failed: N

[PASS] PRE-COMMIT PASSED
  or
[FAIL] PRE-COMMIT FAILED — Fix violations before committing.
```

## Environment Variables

| Variable | Effect |
|----------|--------|
| `LINT_VERBOSE=1` | Show detailed check output |
| `LINT_WARN=1` | Warn only, do not block |
| `SKIP_LINT=1` | Skip all lint checks |

## See Also

- `/code-review` -- Full code review (more thorough)
- `/fitness` -- Quality fitness scoring
- `CLAUDE.md` -- Project standards reference
