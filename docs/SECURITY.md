# Security Considerations

This document covers the security architecture of cognitive-core, including the multi-tool security guard, credential management, and production hardening recommendations.

## Security Guard Architecture

cognitive-core implements a defense-in-depth security model using Claude Code's PreToolUse and PostToolUse hook system. Every tool call is intercepted and validated before (or after) execution.

### Security Levels

Configure via `CC_SECURITY_LEVEL` in `cognitive-core.conf`:

| Level | Description |
|-------|-------------|
| `minimal` | 8 built-in destructive command patterns only |
| `standard` (default) | + exfiltration, encoded commands, pipe-to-shell, domain escalation |
| `strict` | + network destination allowlisting, unknown domains blocked |

### Hook Coverage

| Hook | Event | Tool | Purpose |
|------|-------|------|---------|
| `validate-bash.sh` | PreToolUse | Bash | Blocks destructive commands, exfiltration, pipe-to-shell |
| `validate-read.sh` | PreToolUse | Read | Prevents reading sensitive system files |
| `validate-fetch.sh` | PreToolUse | WebFetch, WebSearch | Audits URLs, domain filtering |
| `validate-write.sh` | PostToolUse | Write, Edit | Scans for hardcoded secrets |
| `setup-env.sh` | SessionStart | — | Verifies hook integrity at session start |
| `post-edit-lint.sh` | PostToolUse | Write, Edit | Auto-lints after edits |

### Graduated Response Model

Inspired by Metasploit's graduated response pattern:

1. **Allow** — safe operation, no output (silent pass)
2. **Ask** — suspicious but not clearly malicious, escalates to human (e.g., unknown domain in standard mode)
3. **Deny** — blocked with explanation in JSON response
4. **Log** — all security events written to `.claude/cognitive-core/security.log`

## Bash Validation Hook

The `validate-bash.sh` hook intercepts every bash command before execution (PreToolUse event) and blocks dangerous patterns.

### Built-In Blocked Patterns (Always Active)

| Pattern | Reason |
|---------|--------|
| `rm -rf /`, `rm -rf /etc`, etc. | Deletion of system-critical paths |
| `git push --force` to main/master | Destructive force push to protected branch |
| `git reset --hard` | May lose uncommitted work |
| `git clean -f` (without `-n`) | Removes untracked files without dry-run |
| `DROP TABLE`, `TRUNCATE TABLE` | Destructive database operations |
| `DELETE FROM` without `WHERE` | Unbounded data deletion |
| `rm .git` | Repository destruction |
| `chmod 777` | Insecure file permissions |

### Standard Level Patterns (Default)

| Category | Pattern | Risk |
|----------|---------|------|
| Exfiltration | `curl -d @file`, `cat \| curl`, `cat \| nc`, `env \|` | Data theft |
| Encoded bypass | `base64 -d \| sh`, `echo \| base64 -d`, `eval $(...)` | Obfuscated execution |
| Pipe-to-shell | `curl \| sh`, `wget \| bash`, `wget -O- \|` | Supply chain attack |

### Custom Blocked Patterns

Add project-specific patterns via `CC_BLOCKED_PATTERNS` in `cognitive-core.conf`:

```bash
CC_BLOCKED_PATTERNS="curl.*\|.*sh eval.*unsafe"
```

### How Blocking Works

When a command matches a blocked pattern, the hook outputs a JSON deny response:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Blocked: potential data exfiltration (cat | curl)"
  }
}
```

## Read Guard

The `validate-read.sh` hook prevents reading sensitive files:

- `/etc/shadow`, `/etc/master.passwd` — system password hashes
- `~/.ssh/id_rsa`, `~/.ssh/id_ed25519` — SSH private keys
- `~/.aws/credentials` — AWS credentials
- `~/.gnupg/` — GnuPG private keys
- `.env` files outside the project directory

**CTF Exception:** If `CC_SKILLS` contains `ctf-pentesting`, read guard checks are skipped (CTF work legitimately needs to read sensitive files on target systems).

## Fetch Guard

The `validate-fetch.sh` hook audits all external URL access:

- **All modes**: Every WebFetch/WebSearch is logged to security.log
- **Standard mode**: Unknown domains trigger human escalation ("ask" decision)
- **Strict mode**: Only `CC_ALLOWED_DOMAINS` are permitted

Built-in known-safe domains include: github.com, stackoverflow.com, docs.python.org, developer.mozilla.org, and other major documentation sites.

## Secret Scanner

The `validate-write.sh` hook (PostToolUse) scans file writes for:

- AWS access keys (`AKIA...`)
- PEM private keys (`-----BEGIN PRIVATE KEY-----`)
- API key/secret/token assignments
- Hardcoded passwords (long string values)

Test files and documentation are excluded to reduce false positives. Warnings are non-blocking (PostToolUse cannot prevent the write) but are logged and reported to the user.

## Integrity Verification

At session start, `setup-env.sh` verifies hook files haven't been tampered with:

1. Reads the `source` field from `version.json` to locate the framework source directory
2. Computes SHA256 of each installed hook file
3. Compares against the corresponding file in the framework source
4. Reports mismatches in the session context and security.log

This comparison is against the **framework source directory** (not version.json checksums), which fixes the TOCTOU vulnerability where an attacker could modify both the hook and its recorded checksum.

## Per-Agent Tool Restrictions

Agents use `disallowedTools` in their frontmatter for least-privilege:

| Agent | Restricted Tools | Rationale |
|-------|-----------------|-----------|
| code-standards-reviewer | WebFetch, WebSearch | Code review doesn't need external access |
| research-analyst | Write, Edit | Research shouldn't modify project files |

## Secrets Management

cognitive-core provides a layered secrets management system with three components: a setup skill for detection and configuration, a storage CLI for persisting secrets, and a runtime injector that resolves secrets at execution time.

### Architecture

```
secrets-setup (skill)     Scans code, generates .env.tpl, patches CI
        |
secrets-store (CLI)       Persists secrets in macOS Keychain (or 1Password)
        |
secrets-run (wrapper)     Resolves op:// references at runtime, injects into env
        |
    application           Reads secrets from environment variables
```

### Backend Detection

The tools auto-detect the available backend in priority order:

1. **1Password** (`op` CLI) -- enterprise-grade, cross-platform, team sharing
2. **macOS Keychain** (`security` CLI) -- free, zero-config, single-machine

Both backends use the same `op://Vault/Item/field` reference format in `.env.tpl` files.

### secrets-setup Skill

The `secrets-setup` skill provides guided secrets management setup:

| Command | Purpose |
|---------|---------|
| `scan` | Detect plaintext secrets in codebase using universal + language-specific patterns |
| `init` | Generate `.env.tpl` with `op://` references from detected secrets |
| `patch-ci` | Patch GitHub Actions workflows to inject secrets at build time |
| `verify` | Validate all referenced secrets exist in the backend |
| `status` | Show backend, stored secrets count, and health |

### secrets-store CLI

Persists secrets in macOS Keychain:

```bash
# Store a secret
core/utilities/secrets-store Development/MyApp database-url
# (prompts for value, input not echoed)

# List stored secrets
core/utilities/secrets-store --list

# Delete a secret
core/utilities/secrets-store --delete Development/MyApp database-url
```

### secrets-run Wrapper

Resolves `op://` references and injects them as environment variables:

```bash
# Run a command with secrets injected
core/utilities/secrets-run -- uvicorn app:main

# Use a custom template
core/utilities/secrets-run --env-file=.env.tpl -- python manage.py migrate
```

### .env.tpl Format

Template files use `op://Vault/Item/field` references (compatible with both 1Password and Keychain backends):

```bash
APP_DATABASE_URL=op://Development/MyApp/database-url
APP_SECRET_KEY=op://Development/MyApp/secret-key
GITHUB_CLIENT_SECRET=op://Development/GitHub/client-secret
```

### Feeding Secrets to GitHub Actions

Use piped Keychain-to-GitHub feeding for zero console exposure:

```bash
security find-generic-password -s "Development/MyApp" -a "database-url" -w \
  | gh secret set APP_DATABASE_URL --repo owner/repo
```

### CI/CD Credentials

| Credential | Variable | Where Used |
|------------|----------|------------|
| Grafana admin password | `GRAFANA_ADMIN_PASSWORD` | docker-compose.monitoring.yml |
| Slack webhook URL | `SLACK_WEBHOOK_URL` | alertmanager.yml |
| SMTP password | `SMTP_PASSWORD` | alertmanager.yml |
| PagerDuty service key | `PAGERDUTY_SERVICE_KEY` | alertmanager.yml |
| Runner registration token | `RUNNER_TOKEN` | docker-compose.runner.yml |
| Docker group ID | `DOCKER_GID` | docker-compose.runner.yml |

### Secret Scanning in CI

Gate 2 of the pipeline scans changed files for potential secrets. Additionally, `validate-write.sh` provides real-time secret scanning during development.

## OWASP LLM Top 10 2025 Coverage

See `core/skills/security-baseline/references/owasp-quick-ref.md` for the full assessment.

| # | Risk | Status | Notes |
|---|------|--------|-------|
| LLM01 | Prompt Injection | **Partial** | Reduced surface, architecturally unsolved |
| LLM02 | Sensitive Info Disclosure | **Addressed** | Secret scanning + read guard |
| LLM03 | Supply Chain | **Partial** | Integrity check + pipe-to-shell blocking |
| LLM04 | Data/Model Poisoning | Out of scope | Claude's model, not ours |
| LLM05 | Improper Output Handling | **Partial** | post-edit-lint |
| LLM06 | Excessive Agency | **Addressed** | Per-agent restrictions, graduated response |
| LLM07 | System Prompt Leakage | Not addressed | Architecture limitation |
| LLM08 | Vector/Embedding Issues | Out of scope | No RAG system |
| LLM09 | Misinformation | Not addressed | Model behavior |
| LLM10 | Unbounded Consumption | **Partial** | Context management tools |

### Honest Limitations

- **Prompt injection is not solved.** Defense-in-depth reduces the attack surface but single-LLM systems cannot fully prevent indirect prompt injection.
- **settings.json `deny` rules are bugged** (GitHub issues #6699, #6631, #8961). All enforcement uses PreToolUse hooks instead.
- **PostToolUse hooks cannot block** — `validate-write.sh` warns but cannot prevent a secret from being written. The write has already occurred.
- **No CaMeL pattern** — Dual-LLM verification is not achievable within Claude Code's hook architecture.

## Pushgateway Security

Pushgateway is bound to localhost only by default. For multi-node setups, use VPN, SSH tunnel, or strict firewall rules.

## Docker Socket Security

Mitigations: DOCKER_GID binding, security_opt, dedicated runner user, ephemeral runners.

## HTTPS / TLS

No TLS by default. Use a reverse proxy with TLS for production deployments.

## Security Checklist

Before deploying to production:

- [ ] `CC_SECURITY_LEVEL` set appropriately for your threat model
- [ ] `GRAFANA_ADMIN_PASSWORD` is set to a strong, unique value
- [ ] `.env` and `.env.tpl` files are in `.gitignore` and not committed
- [ ] Secrets stored via `secrets-store` or 1Password (not in plaintext files)
- [ ] `secrets-setup scan` reports zero plaintext secrets
- [ ] Pushgateway is not exposed on public network
- [ ] Docker socket access is limited to the Docker group
- [ ] TLS is enabled for any externally accessible service
- [ ] Credentials are rotated periodically
- [ ] Runner tokens are generated fresh for each node setup
- [ ] Semgrep security scan is enabled in Gate 2
- [ ] `CC_BLOCKED_PATTERNS` includes any project-specific dangerous operations
- [ ] Firewall rules restrict access between nodes to required ports only
- [ ] `CC_ALLOWED_DOMAINS` configured if using strict mode
- [ ] Per-agent tool restrictions reviewed for your team's workflow
