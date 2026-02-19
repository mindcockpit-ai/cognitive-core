---
name: workspace-monitor
description: Proactive log and build monitoring. Scans application logs, test results, build output, and CI artifacts with smart filtering to detect issues before users report them. Language-aware via CC_LANGUAGE — adapts error patterns per stack.
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Grep, Glob
argument-hint: "--errors-only | --since=1h | --build | --tests | --runtime | --all"
---

# Workspace Monitor — Proactive Log and Build Intelligence

Scans application logs, test results, build output, and CI artifacts for the
current project. Uses smart filtering to detect errors, warnings, stack traces,
and anomalies. Language-aware — adapts scanning patterns based on `CC_LANGUAGE`
from `cognitive-core.conf`.

Operates in two modes:
- **Single-project** (default): Scans `CC_PROJECT_DIR` only
- **Workspace** (opt-in): If `CC_WORKSPACE_PROJECTS` is defined, scans multiple project directories

## Arguments

- `$ARGUMENTS` — options:
  - `--errors-only` — only show ERROR/FATAL level entries
  - `--since=1h|6h|24h|7d` — time window (default: `CC_MONITOR_SINCE` or `24h`)
  - `--build` — focus on build/compile output
  - `--tests` — focus on test results
  - `--runtime` — focus on application runtime logs
  - `--tail` — show last N lines of active logs
  - `--all` — scan all categories (default behavior)

## Configuration

From `cognitive-core.conf`:

| Variable | Default | Description |
|----------|---------|-------------|
| `CC_LANGUAGE` | — | Determines default error patterns and log conventions |
| `CC_MONITOR_LOG_DIRS` | `logs` | Log directories to scan (space-separated, relative to project root) |
| `CC_MONITOR_TEST_DIRS` | `test-results` | Test result directories (space-separated, relative) |
| `CC_MONITOR_BUILD_DIRS` | `target dist build` | Build artifact directories (space-separated, relative) |
| `CC_MONITOR_EXTRA_PATTERNS` | — | Additional error regex (pipe-separated, appended to language defaults) |
| `CC_MONITOR_SINCE` | `24h` | Default time window |
| `CC_MONITOR_REPORT_DIR` | `${CC_SESSION_DOCS_DIR}/monitor-reports` | Report output directory |
| `CC_MONITOR_MAX_LOG_SIZE` | `104857600` | Max log file size (bytes) before alerting (100MB) |
| `CC_WORKSPACE_PROJECTS` | — | Optional: additional project directories for multi-project scanning (absolute paths, space-separated) |

## Live Context (auto-injected)

### Active Log Files
!`for dir in ${CC_MONITOR_LOG_DIRS:-logs}; do [ -d "${dir}" ] && find "${dir}" -name "*.log" -mtime -1 2>/dev/null | head -5; done`

### Recent Test Results
!`for dir in ${CC_MONITOR_TEST_DIRS:-test-results}; do ls -lt "${dir}"/*.xml 2>/dev/null | head -3; ls -lt "${dir}"/*.tap 2>/dev/null | head -3; done`

### Log File Sizes
!`for dir in ${CC_MONITOR_LOG_DIRS:-logs}; do [ -d "${dir}" ] && ls -lh "${dir}"/*.log 2>/dev/null; done`

### Build Artifacts
!`for dir in ${CC_MONITOR_BUILD_DIRS:-target dist build}; do [ -d "${dir}" ] && echo "${dir}: exists ($(find "${dir}" -maxdepth 2 \( -name "*.jar" -o -name "*.war" -o -name "*.whl" -o -name "*.tar.gz" \) 2>/dev/null | wc -l | tr -d ' ') artifacts)"; done`

### cognitive-core Security Log
!`[ -f .claude/cognitive-core/security.log ] && tail -10 .claude/cognitive-core/security.log 2>/dev/null || echo "No security log"`

## Instructions

### Step 1: Load Configuration and Patterns

1. Source `cognitive-core.conf` for `CC_LANGUAGE`, `CC_MONITOR_*` variables
2. Load language-specific monitor patterns if available:
   - Check `language-packs/${CC_LANGUAGE}/monitor-patterns.conf` (in framework source)
   - Or read inline patterns from `references/error-patterns.md` (in this skill directory)
3. Merge `CC_MONITOR_EXTRA_PATTERNS` with language defaults (pipe-separated regex)

### Step 2: Determine Scope

- **Single-project** (default): Scan `CC_PROJECT_DIR` only
- **Workspace mode**: If `CC_WORKSPACE_PROJECTS` is defined, scan each listed directory
- Apply `$ARGUMENTS` to select categories: `--build`, `--tests`, `--runtime`, or `--all`

### Step 3: Discover Log Files

For each project directory in scope:
1. Search configured `CC_MONITOR_LOG_DIRS` for `*.log` files
2. Search for additional log locations: `**/logs/`, `**/*.log` (limit depth to 3)
3. Check logging configuration files based on `CC_LANGUAGE`:
   - Perl: `logger.conf`, `environments/*.yml` (Log4perl)
   - Java: `src/main/resources/logback*.xml`, `src/main/resources/log4j2.xml`
   - Python: `logging.conf`, `logging.yaml`, `pyproject.toml [tool.logging]`
   - Node: `winston.config.*`, `pino` config in `package.json`
4. Note file sizes and last modification times

### Step 4: Smart Scan — Runtime Logs

If `--runtime` or `--all`:

For each discovered log file:
1. **Recency check**: Skip files not modified within the `--since` window
2. **Error extraction**: Apply language-aware error patterns (see references/error-patterns.md)
3. **Context capture**: For each match, capture 3 lines before and 3 after
4. **Deduplication**: Group identical error messages, count occurrences
5. **Severity classification**:
   - **CRITICAL**: Unhandled exceptions, OOM, security events, data corruption indicators
   - **ERROR**: Application errors, failed operations, connection issues
   - **WARNING**: Deprecations, slow queries, resource pressure, high retry counts
   - **INFO**: Notable events that aren't errors but may indicate trends

### Step 5: Parse Test Results

If `--tests` or `--all`:

1. Find test result files in `CC_MONITOR_TEST_DIRS`:
   - **JUnit XML**: `**/TEST-*.xml`, `**/junit.xml`, `**/surefire-reports/*.xml`
   - **TAP**: `*.tap`, `*.t` output
   - **pytest**: `**/pytest-report.xml`
   - **Jest**: `**/jest-results.json`
2. Detect format based on `CC_LANGUAGE` and file extension
3. Parse test counts: total, passed, failed, skipped, errors
4. Calculate pass rate per test suite
5. If `CC_TEST_COMMAND` is set, offer to re-run for live results

### Step 6: Check Build Health

If `--build` or `--all`:

1. Check `CC_MONITOR_BUILD_DIRS` for build artifacts
2. Detect build system from `CC_LANGUAGE`:
   - Java: `target/` (Maven), `build/` (Gradle) — look for `BUILD SUCCESS`/`BUILD FAILURE`
   - Python: `dist/` (setuptools/poetry), `build/` (flit)
   - Node: `dist/`, `build/`, `.next/` — look for bundle errors
   - Perl: `blib/` (ExtUtils), `local/` (Carton)
3. Check for stale builds (artifacts older than source files)
4. Verify artifact integrity (exists and non-zero size)
5. Look for build failure indicators in build logs

### Step 7: Log Growth Analysis

For all discovered log files:
1. Check current size against `CC_MONITOR_MAX_LOG_SIZE`
2. If a log exceeds the threshold, flag as alert
3. Check for log rotation configuration (presence of archived logs)
4. Flag missing rotation for large log files

### Step 8: Generate Monitoring Report

Save to `${CC_MONITOR_REPORT_DIR:-docs/monitor-reports}/YYYY-MM-DD-monitor.md`:

```markdown
# Monitoring Report

> Generated: YYYY-MM-DD HH:MM
> Project: [CC_PROJECT_NAME] ([CC_LANGUAGE])
> Window: last [since]
> Mode: [single-project | workspace (N projects)]

## Alerts

| Severity | Source | Message | Count | Last Seen |
|----------|--------|---------|-------|-----------|
| CRITICAL | [log file] | [error msg] | [N] | [timestamp] |
| ERROR | [log file] | [error msg] | [N] | [timestamp] |
| WARNING | [log file] | [warning msg] | [N] | [timestamp] |

## Test Results

| Suite | Tests | Passed | Failed | Errors | Skipped | Pass Rate |
|-------|-------|--------|--------|--------|---------|-----------|
| [name] | [N] | [N] | [N] | [N] | [N] | [%] |

## Build Health

| Directory | Last Build | Status | Artifacts | Stale? |
|-----------|-----------|--------|-----------|--------|
| [dir] | [time ago] | [status] | [count] | [yes/no] |

## Log Growth

| File | Size | Threshold | Rotation | Alert |
|------|------|-----------|----------|-------|
| [path] | [size] | [max] | [yes/no] | [OK/WARN] |

## Error Details

### [Source File]
```
[timestamp] [level] [context]
  error message with stack trace
  ... (N occurrences in window)
```

## Recommended Actions
1. [Priority action based on findings]
```

### Step 9: Workspace Mode — Aggregate Dashboard

When `CC_WORKSPACE_PROJECTS` is defined and scanning multiple projects:
- Prefix all table rows with the project name
- Add a "Summary by Project" section at the top
- Aggregate alert counts across projects

## Examples

```
/workspace-monitor                                   # Default: full scan, last 24h
/workspace-monitor --errors-only --since=1h          # Errors only, last hour
/workspace-monitor --tests                           # Test results only
/workspace-monitor --build                           # Build health only
/workspace-monitor --runtime --since=7d              # Runtime logs, last week
```

## See Also

- `/project-status` — Development progress report (git history based)
- `/fitness` — Codebase fitness scoring (code quality)
- `/session-resume` — Session context recovery
- `references/error-patterns.md` — Default error patterns by language
- `cognitive-core.conf` — All configuration reference
