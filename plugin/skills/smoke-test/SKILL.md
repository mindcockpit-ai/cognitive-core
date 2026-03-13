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

## Implementation Guide: Headless Browser vs HTTP-only

### Why a headless browser is required

A naive HTTP GET test will return **HTTP 200 for every page** in most web apps because
the server renders the HTML template successfully. The real errors only surface when
the browser executes JavaScript — AJAX calls, DataTable data loading, dynamic
rendering. These errors manifest as:

- **JavaScript `alert()` dialogs** — e.g., DataTables warning alerts showing ORA errors
- **Browser console errors** — AJAX failures, uncaught exceptions, missing resources
- **Server log entries** — triggered by the AJAX API calls, not the initial page load

An HTTP-only test **will miss all of these**. You must use a headless browser
(Playwright, Puppeteer, or Selenium) to execute JavaScript and wait for async
operations to complete.

### Recommended: Playwright (Node.js)

```bash
# One-time setup
npm install --save-dev playwright
npx playwright install chromium
```

### Test script requirements

The smoke test script (`CC_SMOKE_TEST_COMMAND`) should:

1. **Launch headless browser** and create an authenticated session (login)
2. **Navigate to each endpoint** and wait for `networkidle` (all AJAX calls complete)
3. **Add settle time** (1-2 seconds) after networkidle for JS rendering and alert dialogs
4. **Capture three error sources per page**:

| Source | How to capture | Example |
|--------|---------------|---------|
| **JS Alert dialogs** | Playwright `page.on('dialog')` | `ORA-00904: "ME"."YEAR"` shown via DataTables `alert()` |
| **Console errors** | Playwright `page.on('console')` filtered to `type === 'error'` | AJAX error objects, uncaught exceptions |
| **Server log** | Read log file from byte-offset before → after each navigation | ORA errors, DBIx exceptions, Perl `die`, encoding errors |

5. **Prefix errors by source** for clear triage:
   - `[JS Alert] DataTables warning: table id=...`
   - `[Console] AJAX Error: {userMessage: ...}`
   - `[Server Log] 2026/02/23 18:31:11 ORA-00904: ...`

6. **Output JSON** in the standard schema above

### Error pattern reference

Define both **critical** patterns (fail the test) and **ignore** patterns (known
noise like connectivity timeouts):

```
Critical:  ORA-\d{5}, DBIx::Class.*Exception, Error processed:,
           died at, FATAL, Malformed UTF-8, Can't find source for
Ignore:    ORA-12541 (no listener), ORA-12170 (timeout),
           ORA-03114/03113 (disconnected)
```

### Real-world results (IPMS reference)

A Playwright-based test on a 45-page Perl/Dancer2/Oracle app found **10 failures**
across 3 root causes — all invisible to HTTP-only testing:

| Pages affected | Root cause | Detection source |
|---------------|------------|-----------------|
| EW Index, Task Planning, 9999/XXXX containers | `ORA-00904: "ME"."YEAR"` — missing column | JS Alert + Server Log |
| MOD Register, MSF Register, Change, Shipping | `ORA-00904: "UPDATED_BY"` — missing column | JS Alert + Console + Server Log |
| MPMF Viewer | `Malformed UTF-8` — encoding issue | JS Alert + Server Log |

Every one of these returned **HTTP 200** — the page template rendered fine, but the
DataTables AJAX calls triggered server errors that appeared as JavaScript alert dialogs.

### Common pitfalls

| Pitfall | Consequence | Solution |
|---------|------------|---------|
| Using `curl` or `LWP::UserAgent` only | All pages appear to pass (HTTP 200) | Use Playwright/Puppeteer headless browser |
| Not waiting for `networkidle` | AJAX calls haven't fired yet when you check | `page.waitForLoadState('networkidle')` |
| Not adding settle time after networkidle | Alert dialogs appear slightly after network settles | Add 1-2 second `waitForTimeout` after networkidle |
| Not capturing `dialog` events | `alert()` errors are dismissed without being recorded | Register `page.on('dialog')` handler before navigation |
| Only checking HTTP status code | 500 errors are rare; most errors happen in AJAX responses | Check all three sources: alerts, console, server log |
| ESM module conflicts | `require('playwright')` fails in ESM projects | Use `.cjs` extension or `import` syntax |

## Error Handling

- If `CC_SMOKE_TEST_COMMAND` is not set: print "No smoke test configured. Set CC_SMOKE_TEST_COMMAND in cognitive-core.conf" and stop
- If server is not reachable: print "Server not reachable at <URL>. Start the server first." and stop
- If JSON output is invalid: print "Smoke test command did not produce valid JSON" and show raw output
- If `gh` CLI is not available: skip issue creation, print warning
- If Playwright/browser is not installed: print setup instructions and stop
