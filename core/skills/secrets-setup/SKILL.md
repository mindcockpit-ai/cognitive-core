---
name: secrets-setup
description: Platform-independent secrets management using 1Password CLI. Scans for plaintext secrets, generates .env.tpl templates with op:// references, patches GitHub Actions workflows, and verifies security hooks are active.
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
argument-hint: "scan | init | patch-ci | verify | status"
featured: true
featured_description: 1Password-based secrets management — zero plaintext secrets across all machines and CI/CD.
---

# Secrets Setup — 1Password-Powered Secrets Management

Industry-standard secrets management for cognitive-core projects. Uses 1Password CLI (`op`)
for platform-independent, encrypted secret injection with full audit trails.

**Blue team approved:** encrypted at rest, injected at runtime, never in plaintext.

## Arguments

- `$ARGUMENTS` — subcommand: `scan`, `init`, `patch-ci`, `verify`, `status`

## Live Context

### 1Password CLI Status
!`command -v op &>/dev/null && echo "op CLI: $(op --version 2>/dev/null || echo 'installed')" || echo "op CLI: NOT INSTALLED"`

### Current .env Files
!`echo "=== .env files ==="; find . -maxdepth 3 -name ".env*" -not -path "./.git/*" -not -path "*/node_modules/*" 2>/dev/null | head -20 || echo "None found"`

### Gitignore Coverage
!`grep -n "\.env" .gitignore 2>/dev/null || echo "No .env rules in .gitignore"`

### Security Hooks
!`ls .claude/hooks/validate-write.sh 2>/dev/null && echo "validate-write: active" || echo "validate-write: NOT INSTALLED"`

### GitHub Actions Workflows
!`find .github/workflows -name "*.yml" -type f 2>/dev/null | head -10 || echo "No workflows found"`

### Project Language
!`CC_LANG=$(grep "^CC_LANGUAGE=" .claude/cognitive-core.conf 2>/dev/null | cut -d= -f2 | tr -d '"'); echo "Language: ${CC_LANG:-not set}"`

### Language-Specific Patterns
When `CC_LANGUAGE` is set, load additional scan patterns from `references/language-patterns.md`
for the active language. This enables detection of framework-specific secret leaks
(e.g., Django `SECRET_KEY`, Spring `datasource.password`, Dancer2 session secrets).

## Commands

### `scan` — Detect Plaintext Secrets

Scan the project for potential secret exposure:

1. **Search for `.env` files** that contain actual values (not `op://` references):
   ```bash
   find . -name ".env" -o -name ".env.local" -o -name ".env.production" | \
     grep -v node_modules | grep -v .git
   ```

2. **Search for hardcoded secrets** using universal patterns (always active):
   - AWS access keys: `AKIA[0-9A-Z]{16}`
   - Private keys: `-----BEGIN.*PRIVATE.*KEY-----`
   - API key assignments: `(api[_-]?key|api[_-]?secret|access[_-]?token)\s*[:=]`
   - Hardcoded passwords: `(password|secret|token)\s*[:=]\s*["'][^"']{16,}`
   - 1Password service account tokens: `ops_`
   - GitHub PATs: `ghp_[a-zA-Z0-9]{36}`
   - Cloudflare tokens: `[a-zA-Z0-9]{40}` near `cloudflare` context

   **Plus language-specific patterns** from `references/language-patterns.md` when `CC_LANGUAGE` is set.
   For example, with `CC_LANGUAGE=perl`: scan for `$ENV{}` with hardcoded fallbacks,
   Dancer2 session secrets in `config.yml`, DBI connection strings with embedded passwords.

3. **Check `.gitignore`** for proper `.env` exclusion rules

4. **Report findings** with severity and remediation:
   ```
   SECRETS SCAN
   ============

   CRITICAL
   --------
   [!] .env contains 3 plaintext values (not op:// references)
   [!] src/config.ts:42 — hardcoded API key pattern detected

   WARNING
   -------
   [~] .gitignore missing .env.local exclusion
   [~] validate-write.sh hook not installed

   OK
   --
   [✓] No AWS keys found
   [✓] No PEM files in tracked files
   [✓] .env.tpl uses op:// references
   ```

### `init` — Generate .env.tpl Template

Create a `.env.tpl` file with 1Password references:

1. **If `.env.template` or `.env.example` exists**, read it and convert each `KEY=value` to `KEY=op://Vault/Item/field`:
   - Prompt for the 1Password vault name (default: "Development")
   - Prompt for item names (suggest grouping by service: Cloudflare, GitHub, Database, etc.)
   - Generate `op://` references for each key

2. **If no template exists**, scan the project for environment variable usage:
   - Search for `process.env.`, `$ENV{}`, `os.environ`, `env::var` patterns
   - Search GitHub Actions workflows for `secrets.*` references
   - Build a suggested `.env.tpl` from discovered variables

3. **Update `.gitignore`**:
   - Ensure `.env` and `.env.*` are ignored
   - Add `!.env.tpl` exception so the template is tracked

4. **Write the `.env.tpl` file** with header documentation:
   ```bash
   # Project — 1Password secret references
   # Usage: op run --env-file=.env.tpl -- <command>
   #
   # Vault: Development
   # Items: Cloudflare, GitHub-PAT, Database
   #
   # Setup:
   #   1. brew install 1password-cli (or apt/winget)
   #   2. op signin
   #   3. Create items in vault matching references below
   #   4. op run --env-file=.env.tpl -- your-command

   CLOUDFLARE_API_TOKEN=op://Development/Cloudflare/api-token
   DATABASE_URL=op://Development/Database/connection-string
   ```

### `patch-ci` — Add 1Password to GitHub Actions

Patch existing GitHub Actions workflows to support 1Password secrets:

1. **Scan `.github/workflows/*.yml`** for `${{ secrets.* }}` usage
2. **For each workflow**, add a `Load secrets from 1Password` step:
   ```yaml
   - name: Load secrets from 1Password
     if: ${{ env.OP_SERVICE_ACCOUNT_TOKEN != '' }}
     uses: 1password/load-secrets-action@v2
     with:
       export-env: true
     env:
       OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
       SECRET_NAME: op://Vault/Item/field
   ```
3. **Update secret references** to use fallback pattern:
   ```yaml
   # Before:
   token: ${{ secrets.MY_TOKEN }}
   # After:
   token: ${{ env.MY_TOKEN || secrets.MY_TOKEN }}
   ```
4. This ensures **backwards compatibility** — workflows work with either 1Password or direct GitHub secrets.

### `verify` — Validate Security Posture

Run a comprehensive check:

1. **op CLI installed and authenticated?**
   ```bash
   op --version
   op vault list --format=json 2>/dev/null | head -1
   ```

2. **.env.tpl exists and uses op:// references?**
   ```bash
   grep -c "op://" .env.tpl 2>/dev/null
   ```

3. **No plaintext .env files tracked by git?**
   ```bash
   git ls-files | grep -E "^\.env$|^\.env\." | grep -v ".tpl$\|.template$\|.example$"
   ```

4. **Security hooks active?**
   - `validate-write.sh` scanning for secrets
   - `.gitignore` blocking `.env` files

5. **GitHub Actions using 1Password or fallback?**
   - Check for `1password/load-secrets-action` in workflows

6. **Output a scorecard:**
   ```
   SECRETS VERIFICATION
   ====================

   [✓] op CLI v2.30.0 installed
   [✓] .env.tpl has 3 op:// references
   [✓] No plaintext .env files tracked
   [✓] validate-write.sh hook active
   [✓] .gitignore blocks .env files
   [✓] 2/2 workflows have 1Password fallback

   Score: 6/6 — All clear
   ```

### `status` — Quick Overview

Show current secrets management state:

```
SECRETS STATUS
==============
Platform:    macOS (darwin)
op CLI:      v2.30.0 (authenticated)
Vault:       Development (3 items)
Template:    .env.tpl (3 references)
Gitignore:   .env blocked, .env.tpl allowed
Hooks:       validate-write active
CI/CD:       2 workflows with 1Password support
Last scan:   2026-02-19 (0 issues)
```

## 1Password Setup Guide

### New Machine Setup
```bash
# 1. Install op CLI
brew install 1password-cli          # macOS
# OR: sudo apt install 1password-cli   # Debian/Ubuntu
# OR: winget install 1Password.CLI      # Windows

# 2. Sign in
op signin

# 3. Verify
op vault list
```

### CI/CD Setup (one-time, per GitHub org)
1. Create a 1Password **Service Account** at https://my.1password.com
2. Grant read access to the "Development" vault
3. Add `OP_SERVICE_ACCOUNT_TOKEN` as a GitHub **organization-level** secret
4. All repos with `load-secrets-action` automatically resolve secrets

### Adding a New Secret
1. Add the secret to 1Password (vault → item → field)
2. Add the `op://` reference to `.env.tpl`
3. If used in CI/CD, add the reference to the workflow's `Load secrets` step
4. Run `/secrets-setup verify` to confirm

## Error Handling

| Error | Recovery |
|-------|----------|
| `op` not installed | `brew install 1password-cli` (or platform equivalent) |
| Not signed in | `op signin` — uses biometric if available |
| Vault not found | Create vault or update references in `.env.tpl` |
| Item not found | Create item in 1Password matching the `op://` reference |
| CI/CD token expired | Rotate the Service Account token, update GitHub secret |
| Plaintext secret found | Move to 1Password, replace with `op://` reference, rotate the exposed secret |

## See Also

- `validate-write.sh` — PostToolUse hook that scans for plaintext secrets
- `security-baseline` skill — OWASP-aware coding rules including secret handling
- `/skill-sync install secrets-setup` — Install this skill in a project
