# Recipe: Security Scan Workflow

> **Time**: ~3 min read | **Level**: Intermediate | **Language**: All

## Goal

Scan your project for security vulnerabilities using `@security-analyst` and understand the OWASP-aware findings it produces.

## Prerequisites

- cognitive-core installed (`./install.sh /path/to/project`)
- `@security-analyst` agent available (installed by default)
- `/security-baseline` skill loaded (auto-loaded, not user-invocable)

## Steps

### Step 1: Run a targeted security scan

Point `@security-analyst` at a specific module or feature area:

```
@security-analyst scan the authentication module for security vulnerabilities
```

### Step 2: Review the findings

**Expected output:**
```
SECURITY ANALYSIS — src/auth/
==============================

CRITICAL
--------
[SEC-01] Hardcoded JWT secret in src/auth/config.js:12
  Risk:  Secret leaks if code is pushed to public repo
  Fix:   Move to environment variable: process.env.JWT_SECRET

[SEC-02] SQL injection in src/auth/login.js:34
  Risk:  Attacker can bypass authentication
  Code:  `SELECT * FROM users WHERE email = '${email}'`
  Fix:   Use parameterized query: `db.query('SELECT * FROM users WHERE email = $1', [email])`

HIGH
----
[SEC-03] Missing rate limiting on POST /api/auth/login
  Risk:  Brute-force password attacks
  Fix:   Add rate limiter middleware (express-rate-limit or similar)

WARNING
-------
[SEC-04] Using Math.random() for session token in src/auth/session.js:8
  Risk:  Predictable tokens, session hijacking
  Fix:   Use crypto.randomUUID() or crypto.randomBytes(32)

SUMMARY
=======
Critical: 2  |  High: 1  |  Warning: 1
```

### Step 3: Fix the critical findings first

Address findings by severity. For the hardcoded secret:

```
Move the JWT secret from src/auth/config.js to an environment variable
```

### Step 4: Re-scan to verify fixes

```
@security-analyst re-scan src/auth/ — verify the previous findings are resolved
```

### Step 5: Run a project-wide scan

Once the critical module is clean, scan the whole project:

```
@security-analyst scan the entire project for OWASP Top 10 vulnerabilities
```

## What @security-analyst Checks

The agent uses the `/security-baseline` skill internally, which provides OWASP-aware rules adapted to your project's language:

| Category | Examples |
|----------|---------|
| **Secrets** | Hardcoded passwords, API keys, JWT secrets, connection strings |
| **Injection** | SQL injection, command injection, XSS, XXE |
| **Authentication** | Weak hashing, missing rate limiting, insecure session management |
| **Authorization** | Missing access checks, privilege escalation paths |
| **Cryptography** | Weak algorithms (MD5, SHA1), predictable randomness |
| **Dependencies** | Known CVEs in package.json/requirements.txt/pom.xml |

## Language-Specific Scan Examples

### Python / FastAPI

```
@security-analyst scan this FastAPI app — check for injection, auth, and dependency issues
```

Checks for `shell=True`, unsafe `pickle.loads()`, missing `defusedxml`, weak password hashing.

### Java / Spring Boot

```
@security-analyst review the Spring Security configuration and all REST endpoints
```

Checks for missing CSRF protection, `@PreAuthorize` gaps, `Runtime.exec()` usage, SQL injection in JPQL.

### Node.js / Express

```
@security-analyst scan this Express app for OWASP Top 10 vulnerabilities
```

Checks for missing `helmet`, `eval()` usage, prototype pollution, unvalidated redirects.

## Expected Output

After completing the workflow, you should have:
- A severity-ranked list of security findings with file:line references
- Concrete fix recommendations for each finding
- Verification that critical findings are resolved after fixes
- A clean or reduced-severity project-wide scan

## Next Steps

- [Code Review Workflow](recipe-code-review.md) -- code review catches some security issues too
- [Test Creation](recipe-test-creation.md) -- write tests that verify security fixes
- [Troubleshooting](recipe-no-output.md) -- if the scan produces no output
- `@security-analyst` agent: `core/agents/security-analyst.md`
- `/security-baseline` skill: `core/skills/security-baseline/SKILL.md`
