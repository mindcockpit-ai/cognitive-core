---
name: smoke-test
description: Happy path smoke testing — navigates all configured endpoints, checks HTTP status and server logs for errors, and optionally auto-creates GitHub issues for failures. Config-driven via CC_SMOKE_TEST_* variables.
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Grep, Glob
argument-hint: "run | report | fix"
featured: true
featured_description: Smoke test all endpoints and auto-create GitHub issues for failures.
---

# Smoke Test — Happy Path Endpoint Verification

Runs a project-specific smoke test script that checks every configured endpoint
for HTTP errors and scans server logs for runtime exceptions. Results can be
displayed as a report or used to auto-create GitHub bug issues on the project board.

## Arguments

- `$ARGUMENTS` — subcommand:
  - `run` (default) — Run tests AND auto-create GitHub issues for untracked failures
  - `report` — Run tests and display results only (no issue creation)
  - `fix` — Re-run tests and cross-reference against open smoke-test issues

## Configuration

From `cognitive-core.conf`:

| Variable | Default | Description |
|----------|---------|-------------|
| `CC_SMOKE_TEST_COMMAND` | — | Command that runs the test and outputs JSON (required) |
| `CC_SMOKE_TEST_URL` | — | Base URL of the running server (required) |
| `CC_SMOKE_TEST_LOG_PATTERN` | — | Log file path pattern (from language pack) |
| `CC_SMOKE_TEST_LABEL` | `smoke-test` | GitHub label for auto-created issues |
| `CC_ORG` | — | GitHub owner (for issue creation) |
| `CC_PROJECT_NAME` | — | GitHub repo name (for issue creation) |

## Standard JSON Schema

The smoke test command (`CC_SMOKE_TEST_COMMAND`) MUST output JSON in this format:

```json
{
  "timestamp": "ISO-8601",
  "server": "base URL",
  "environment": "env name",
  "summary": { "total": N, "passed": N, "failed": N },
  "results": [
    {
      "name": "human-readable page name",
      "url": "/relative/path",
      "status": "PASS|FAIL",
      "httpCode": 200,
      "errors": ["error line 1", "error line 2"]
    }
  ]
}
```

## Workflow

### Subcommand: `run` (default)

1. **Load config**: Read `CC_SMOKE_TEST_COMMAND` and `CC_SMOKE_TEST_URL` from `cognitive-core.conf`
2. **Preflight check**: Verify server is reachable:
   ```bash
   curl -s -o /dev/null -w "%{http_code}" "$CC_SMOKE_TEST_URL"
   ```
   If not reachable, print error and stop.
3. **Execute test**: Run the smoke test command:
   ```bash
   eval "$CC_SMOKE_TEST_COMMAND"
   ```
4. **Parse JSON**: Read the JSON output (standard schema above)
5. **Display results**: Print a formatted table:
   ```
   # Smoke Test Results — <timestamp>
   Server: <server> | Environment: <environment>

   | # | Page | URL | HTTP | Status | Errors |
   |---|------|-----|------|--------|--------|
   | 1 | Homepage | / | 200 | PASS | — |
   | 2 | EW Index | /admin/indexes/gui/ew | 200 | FAIL | ORA-00904 "ME"."YEAR" |
   ...

   Summary: X/Y passed, Z failed
   ```
6. **Check existing issues**: For each FAIL, search for an open issue:
   ```bash
   gh issue list --repo <CC_ORG>/<CC_PROJECT_NAME> --label "bug,<CC_SMOKE_TEST_LABEL>" --state open --search "<page name>"
   ```
7. **Create issues**: For each untracked failure, create a GitHub issue:
   - Title: `[smoke-test] <Page Name>: <short error summary>`
   - Labels: `bug`, `<CC_SMOKE_TEST_LABEL>`
   - Body: See issue template below
8. **Add to project board**: If a GitHub project exists, add the issue:
   ```bash
   gh project item-add <project-number> --owner <CC_ORG> --url <issue-url>
   ```
9. **Report**: Print count of created vs already-tracked issues

### Subcommand: `report`

Same as `run` steps 1-5 only. No issue creation or project board interaction.

### Subcommand: `fix`

1. List open smoke-test issues:
   ```bash
   gh issue list --repo <CC_ORG>/<CC_PROJECT_NAME> --label "bug,<CC_SMOKE_TEST_LABEL>" --state open
   ```
2. Re-run the smoke test (steps 2-5 from `run`)
3. Cross-reference: identify which open issues are now PASS (resolved) vs still FAIL
4. Display a resolution table:
   ```
   | Issue | Page | Previous | Current | Action |
   |-------|------|----------|---------|--------|
   | #42 | EW Index | FAIL | PASS | Can close |
   | #43 | MPMF Viewer | FAIL | FAIL | Still broken |
   | — | New Page | — | FAIL | New failure |
   ```
5. Offer to close resolved issues and create issues for new failures

## Issue Title Convention

```
[smoke-test] <Page Name>: <short error>
```

Examples:
- `[smoke-test] EW Index: ORA-00904 "ME"."YEAR"`
- `[smoke-test] MPMF Viewer: Malformed UTF-8 character`
- `[smoke-test] Change Module: HTTP 500`

## Issue Body Template

```markdown
## Smoke Test Failure: <Page Name>

**URL**: `<url>`
**HTTP Status**: <code>
**Detected**: <date>
**Environment**: <env>

### Error Log
\`\`\`
<error lines from test output>
\`\`\`

### Suggested Investigation
- Check file:line references in the error
- Verify database schema matches ORM definitions
- Re-run: `<CC_SMOKE_TEST_COMMAND>`

---
*Auto-generated by `/smoke-test run`. Label: `<CC_SMOKE_TEST_LABEL>`*
```

## Error Handling

- If `CC_SMOKE_TEST_COMMAND` is not set: print "No smoke test configured. Set CC_SMOKE_TEST_COMMAND in cognitive-core.conf" and stop
- If server is not reachable: print "Server not reachable at <URL>. Start the server first." and stop
- If JSON output is invalid: print "Smoke test command did not produce valid JSON" and show raw output
- If `gh` CLI is not available: skip issue creation, print warning
