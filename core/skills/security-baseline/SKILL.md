---
name: security-baseline
description: OWASP-aware secure coding awareness. Provides security rules, common vulnerability patterns, and safe coding practices adapted to the project's language and framework.
user-invocable: false
allowed-tools: Read, Grep, Glob
---

# Security Baseline — Secure Coding Awareness

Auto-loaded skill providing security context for every coding session. All code
generated or reviewed should follow these security principles.

## Core Security Rules

1. **Never hardcode credentials** — use environment variables or a secrets manager
2. **Validate all external input** — user input, API responses, file contents
3. **Use parameterized queries** — never concatenate user input into SQL/commands
4. **Escape output** — HTML-encode for web, shell-escape for commands
5. **Principle of least privilege** — request minimum permissions needed
6. **Fail securely** — error messages should not leak internal details
7. **Keep dependencies updated** — known CVEs in dependencies are low-hanging fruit

## Language-Specific Rules

### Python
- Use `subprocess.run()` with `shell=False` and list args (never `shell=True` with user input)
- Use `secrets.token_urlsafe()` for tokens, not `random`
- Use `defusedxml` for XML parsing (prevents XXE)
- Use `bcrypt` or `argon2` for password hashing, never MD5/SHA1

### JavaScript/TypeScript
- Use `parameterized queries` or ORM methods, never string concatenation for DB
- Use `helmet` middleware for Express HTTP headers
- Use `DOMPurify` or similar for HTML sanitization
- Use `crypto.randomUUID()` for identifiers, not `Math.random()`

### Go
- Use `html/template` (auto-escapes) over `text/template`
- Use `crypto/rand` not `math/rand` for security-sensitive values
- Use `prepared statements` for database queries
- Check `err` returns — silent error drops cause security bypasses

### Perl
- Use `DBI` placeholders (`?`) for all database queries
- Use `Taint mode` (`-T`) for CGI/web scripts
- Use `quotemeta()` or `\Q...\E` when interpolating into regex
- Use `IPC::Run` over backticks for external commands

### Rust
- Use `sqlx::query!` macro for compile-time query validation
- Use `ring` or `rustcrypto` crates for cryptography
- Use `secrecy::Secret<T>` wrapper to prevent accidental logging of secrets
- Avoid `unsafe` blocks unless absolutely necessary and well-documented

### Java
- Use `PreparedStatement` for all JDBC queries
- Use `OWASP Java Encoder` for output encoding
- Use `java.security.SecureRandom` for tokens
- Avoid `Runtime.exec()` with user input; use `ProcessBuilder` with explicit args

### C#
- Use `SqlParameter` for all ADO.NET queries or EF Core parameterized queries
- Use `HtmlEncoder.Default.Encode()` for HTML output
- Use `System.Security.Cryptography.RandomNumberGenerator` for tokens
- Enable `nullable reference types` to prevent null-related vulnerabilities

## OWASP LLM Top 10 2025 Coverage

See `references/owasp-quick-ref.md` for detailed coverage assessment.

| Risk | Status | Notes |
|------|--------|-------|
| LLM01 Prompt Injection | Partial | validate-read + validate-fetch reduce attack surface |
| LLM02 Sensitive Info Disclosure | Addressed | validate-write secret scanning + validate-read |
| LLM03 Supply Chain | Partial | install.sh integrity + pipe-to-shell blocking |
| LLM06 Excessive Agency | Addressed | Per-agent tool restrictions, graduated response |

## Security Hooks Active

This project is protected by these cognitive-core security hooks:
- `validate-bash.sh` — blocks destructive commands, exfiltration, pipe-to-shell
- `validate-read.sh` — prevents reading sensitive system files
- `validate-fetch.sh` — audits external URL access, domain filtering
- `validate-write.sh` — scans written files for hardcoded secrets
- `setup-env.sh` — verifies hook integrity at session start
