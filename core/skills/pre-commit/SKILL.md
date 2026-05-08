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

## Forbidden-Character Enforcement (optional, via `core/git-hooks/check-forbidden-chars.sh`)

Cognitive-core ships a standalone pre-commit script that blocks AI-tell characters in staged files. It is **not auto-installed** by `update.sh`; projects opt in by referencing the script from their git pre-commit hook (or husky pre-commit).

### Two enforcement modes (extension-driven)

| Mode | Default extensions | Behavior |
|---|---|---|
| **ASCII-ONLY** | `pm pl t sh bash js ts tsx jsx css scss less html tx yml yaml json toml ini conf sql py rb go java c h cpp hpp psgi pod` | Rejects any byte > 0x7F. No exceptions. |
| **BLOCKLIST** | `md markdown txt rst adoc` | Rejects only the configured AI-tell chars (defaults below). |

### Default blocklist (doc files)

| Code-point | Name | Replacement |
|---|---|---|
| U+2014 | EM DASH | `-` |
| U+2013 | EN DASH | `-` |
| U+2026 | HORIZONTAL ELLIPSIS | `...` |
| U+2018 / U+2019 | TYPOGRAPHIC SINGLE QUOTES | `'` |
| U+201C / U+201D | TYPOGRAPHIC DOUBLE QUOTES | `"` |
| U+2192 | RIGHTWARDS ARROW | `->` |
| U+00A0 | NO-BREAK SPACE | regular space |
| U+200B | ZERO-WIDTH SPACE | (removed) |
| U+200C | ZERO-WIDTH NON-JOINER | (removed) |

### Per-project configuration

Project-local override file at `.husky/forbidden-chars.conf` or `bin/hooks/forbidden-chars.conf`:

```
CODE_EXT = pm pl t sh js ...        # override code extensions
DOC_EXT  = md txt rst ...           # override doc extensions
ALLOW_DEFAULT = 0                   # blocklist: start from empty
2248 ALMOST EQUAL TO -> ~=          # add a custom rule
!2018                               # remove a default rule
```

### Installation in a project

```bash
# 1. Reference the cognitive-core hook from your pre-commit
ln -s "$CC_FRAMEWORK_ROOT/core/git-hooks/check-forbidden-chars.sh" \
      "$REPO_ROOT/bin/hooks/checkForbiddenChars.sh"

# 2. Add a step to .husky/pre-commit (or .git/hooks/pre-commit)
echo 'bash bin/hooks/checkForbiddenChars.sh || exit 1' >> .husky/pre-commit

# 3. Optional per-project tuning
cp /dev/null .husky/forbidden-chars.conf
edit .husky/forbidden-chars.conf
```

### Rationale

- ASCII-only for code is **stricter** than tracking individual AI tells but **future-proof** against new ones (e.g., a new Unicode emoji that AI tools start emitting).
- Blocklist for docs preserves legitimate non-ASCII (German content, math notation, customer-source data, accented names).
- Both modes operate on staged files only and skip binary files.
- The hook script and config file are exempt from their own rules (they document the codepoints by necessity).

### Security model

The per-repo config file (`.husky/forbidden-chars.conf` or `bin/hooks/forbidden-chars.conf`) is parsed line-by-line, and the resulting `<codepoint>|<name>` pairs are interpolated **verbatim** into an inline Perl `BEGIN { our %FN = (...) }` block. A hostile config can therefore inject arbitrary Perl code that runs with the user's commit privileges:

```
# Malicious .husky/forbidden-chars.conf entry (illustrative)
2014" => "x"; system("..."); my $f = "
```

This is **acceptable** under the same trust assumption as `.gitignore`, `.editorconfig`, `.gitattributes`, and other per-repo config files: a compromised repo's local config is out of scope for this hook. Mitigation:

- Configs are typically committed to the repo and reviewed alongside other code changes (PR review catches malicious edits).
- Pre-commit hooks only run on machines where the user has already cloned and trusted the repo.
- Adopters who need stronger isolation should run hooks inside a sandboxed environment (e.g., container, VM) or use a pre-commit framework with its own sandboxing.

The script header (`core/git-hooks/check-forbidden-chars.sh`) carries the same note for reviewers reading the code.

## See Also

- `/code-review` -- Full code review (more thorough)
- `/fitness` -- Quality fitness scoring
- `CLAUDE.md` -- Project standards reference
- `core/git-hooks/check-forbidden-chars.sh` -- AI-tell character pre-commit hook
