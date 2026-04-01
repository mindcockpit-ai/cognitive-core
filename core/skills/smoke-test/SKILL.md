---
name: smoke-test
description: Happy path smoke testing — navigates all configured endpoints, checks HTTP status and server logs for errors, and optionally auto-creates GitHub issues for failures. Config-driven via CC_SMOKE_TEST_* variables.
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Grep, Glob
argument-hint: "run | report | fix"
featured: true
featured_description: Smoke test all endpoints and auto-create GitHub issues for failures.
supported-languages: [node, react, angular]
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

## Ability Registry

Each workflow step is classified by ability type. D-type abilities are deterministic
scripts that execute without LLM involvement. See #195 for the full type system.

| Ability | Type | Script | Description |
|---------|:---:|--------|-------------|
| preflight | **D** | `scripts/preflight.sh` | Verify server reachable, validate config |
| execute-test | **D** | `scripts/execute-test.sh` | Run CC_SMOKE_TEST_COMMAND, validate JSON |
| check-issues | **D** | `scripts/check-issues.sh` | Search GitHub for existing tracking issues |
| create-issue | **D/S** | `scripts/create-issue.sh` | LLM provides title+body → script creates issue with dedup |
| list-open-issues | **D** | `scripts/list-open-issues.sh` | List open smoke-test issues as JSON |
| cross-reference | **S/D** | *(orchestration)* | Scripts provide data → LLM interprets resolution |
| format-table | **S** | *(orchestration)* | LLM renders results as markdown table |
| offer-closures | **H** | *(orchestration)* | Human decides which resolved issues to close |

**Type key**: **D** = deterministic script, **D/S** = LLM provides input → script executes,
**S/D** = script provides input → LLM generates output, **S** = pure LLM, **H** = human decision.

## Workflow

### Subcommand: `run` (default)

1. **Preflight** [D]: Run `scripts/preflight.sh` — exits if server unreachable or config missing
2. **Execute** [D]: Run `scripts/execute-test.sh` — captures validated JSON results
3. **Display** [S]: Render results as a formatted markdown table:
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
4. **Check existing** [D]: Pipe results through `scripts/check-issues.sh` — outputs tracked/untracked JSON
5. **Compose issue content** [S]: For each untracked failure, compose:
   - Title: `[smoke-test] <Page Name>: <short error summary>`
   - Body: Use issue template (see Issue Body Template below)
6. **Create issues** [D/S]: For each untracked failure, run:
   ```bash
   scripts/create-issue.sh --title "<composed title>" --body "<composed body>" [--add-to-project <number>]
   ```
7. **Report** [D]: Print count of created vs already-tracked issues

### Subcommand: `report`

Steps 1-3 from `run` only. No issue creation or project board interaction.

### Subcommand: `fix`

1. **List issues** [D]: Run `scripts/list-open-issues.sh` — outputs JSON of open smoke-test issues
2. **Re-test** [D]: Run steps 1-2 from `run` (preflight + execute)
3. **Cross-reference** [S/D]: Compare open issues against fresh results. Identify:
   - Resolved: open issue, page now PASS
   - Still failing: open issue, page still FAIL
   - New failures: no issue, page FAIL
4. **Display resolution table** [S]: Render comparison:
   ```
   | Issue | Page | Previous | Current | Action |
   |-------|------|----------|---------|--------|
   | #42 | EW Index | FAIL | PASS | Can close |
   | #43 | MPMF Viewer | FAIL | FAIL | Still broken |
   | — | New Page | — | FAIL | New failure |
   ```
5. **Offer closures** [H]: Present resolved issues, human decides which to close

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
