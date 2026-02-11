# Security Considerations

This document covers the security architecture of cognitive-core, including the built-in safety mechanisms, credential management, and production hardening recommendations.

## Bash Validation Hook

The `validate-bash.sh` hook intercepts every bash command before execution (PreToolUse event) and blocks dangerous patterns.

### Built-In Blocked Patterns

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

### Custom Blocked Patterns

Add project-specific patterns via `CC_BLOCKED_PATTERNS` in `cognitive-core.conf`:

```bash
CC_BLOCKED_PATTERNS="curl.*\|.*sh eval.*unsafe"
```

Patterns are space-separated extended regex. Each is tested against the lowercased command.

### Database Pack Patterns

Database packs append their own safety patterns. For example, the Oracle pack adds `drop\s+table` and `truncate\s+table` to the blocked list.

### How Blocking Works

When a command matches a blocked pattern, the hook outputs a JSON deny response:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Blocked: force push to main"
  }
}
```

Claude Code reads this response and refuses to execute the command. Non-blocked commands produce no output (silent pass).

## Credential Management

### The .env Pattern

All credentials are externalized to `.env` files that are never committed to version control.

```
cicd/monitoring/.env.template    <-- Committed (placeholder values)
cicd/monitoring/.env             <-- NOT committed (real credentials)
```

The `.env.template` file documents every required variable with placeholder values. The `.env` file contains real credentials and must be in `.gitignore`.

### Credentials in .env

| Credential | Variable | Where Used |
|------------|----------|------------|
| Grafana admin password | `GRAFANA_ADMIN_PASSWORD` | docker-compose.monitoring.yml |
| Slack webhook URL | `SLACK_WEBHOOK_URL` | alertmanager.yml |
| SMTP password | `SMTP_PASSWORD` | alertmanager.yml |
| PagerDuty service key | `PAGERDUTY_SERVICE_KEY` | alertmanager.yml |
| Runner registration token | `RUNNER_TOKEN` | docker-compose.runner.yml |
| Docker group ID | `DOCKER_GID` | docker-compose.runner.yml |

### Required Credential Pattern

The `GRAFANA_ADMIN_PASSWORD` variable uses Docker Compose's `${VAR:?error}` syntax, which causes the compose command to fail with an error if the variable is not set:

```yaml
- GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:?Set GRAFANA_ADMIN_PASSWORD in .env}
```

This prevents accidental deployment with missing credentials.

### Secret Scanning in CI

Gate 2 of the pipeline scans changed files for potential secrets using pattern matching:

```bash
grep -nEi '(password|secret|api_key|token|private_key)\s*[:=]\s*["\x27][^"\x27]{8,}' "$file"
```

Additionally, Semgrep runs security-focused rulesets (`p/security-audit`, `p/secrets`) as part of Gate 2.

### Fitness Check: No Hardcoded Secrets

The fitness check system includes a "No hardcoded secrets" check (weight: 15) that scans configuration files for credential patterns. Each detected occurrence reduces the fitness score by 20 points.

## Pushgateway Security

Pushgateway accepts arbitrary metrics via HTTP POST/PUT. By default, it is bound to localhost only:

```yaml
pushgateway:
  ports:
    - "127.0.0.1:9091:9091"  # Localhost only
```

This means only processes on the same host can push metrics. For multi-node setups where remote runners need to push metrics, see the options below.

### Multi-Node Pushgateway Access

For multi-node setups: use a VPN (recommended), SSH tunnel, or open with strict firewall rules (bind to `0.0.0.0:9091` with IP allowlisting). See `docs/HORIZONTAL_SCALING.md` for details.

## Docker Socket Security

Runner containers mount the host Docker socket for Docker-in-Docker capability:

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

This grants the runner container full control over the host Docker daemon. Mitigations:

1. **DOCKER_GID binding**: The `group_add` directive uses `${DOCKER_GID}` to match the host Docker group, avoiding running the container as root.

2. **Security label disable**: `security_opt: label:disable` is required for Docker socket access on SELinux systems.

3. **Dedicated runner user**: Run the runner process as a non-root user that is a member of the Docker group.

4. **Ephemeral runners**: Use `RUNNER_EPHEMERAL=true` so each runner picks up one job and terminates, reducing the window of exposure.

### Docker Group ID

Find the Docker group ID on your host:

```bash
getent group docker | cut -d: -f3
```

Set this in `.env`:

```bash
DOCKER_GID=999
```

## Grafana Authentication

Default configuration:

```yaml
- GF_SECURITY_ADMIN_USER=${GRAFANA_ADMIN_USER:-admin}
- GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:?...}
- GF_USERS_ALLOW_SIGN_UP=false
```

Sign-up is disabled by default. For production:

1. Change the admin password from the default
2. Configure LDAP or OAuth authentication via Grafana environment variables
3. Place Grafana behind a reverse proxy with TLS

## HTTPS / TLS

The monitoring stack does not include TLS by default. For production deployments:

### Reverse Proxy with TLS

The included Nginx container can be extended with TLS. Mount certificates into the container and update `nginx-monitoring.conf` to redirect HTTP to HTTPS with `ssl_certificate` and `ssl_certificate_key` directives. Internal communication between Prometheus, Grafana, and Alertmanager uses the Docker bridge network and does not need TLS.

## Secrets in CI/CD

### GitHub Actions Secrets

The pipeline uses `secrets.GITHUB_TOKEN` (auto-provided) for container registry authentication. Store additional secrets in GitHub repository settings:

- **Settings > Secrets and variables > Actions > Secrets**
- Never echo secrets in workflow logs
- Use `${{ secrets.NAME }}` syntax

### Environment Variable Exposure

The pipeline reads several values from `vars.*` (repository variables), not `secrets.*`. Variables are visible in logs. Only store non-sensitive configuration in variables:

| Safe for vars | Use secrets instead |
|---------------|-------------------|
| `RUNNER_LABEL` | `RUNNER_TOKEN` |
| `PROJECT_NAME` | `SLACK_WEBHOOK_URL` |
| `GATE_TEST_MIN_PASS_RATE` | `PAGERDUTY_SERVICE_KEY` |
| `CONTAINER_REGISTRY` | Any API key or password |

## Security Checklist

Before deploying to production:

- [ ] `GRAFANA_ADMIN_PASSWORD` is set to a strong, unique value
- [ ] `.env` file is in `.gitignore` and not committed
- [ ] Pushgateway is not exposed on public network
- [ ] Docker socket access is limited to the Docker group
- [ ] TLS is enabled for any externally accessible service
- [ ] Slack webhook URLs, SMTP passwords, and PagerDuty keys are rotated periodically
- [ ] Runner tokens are generated fresh for each node setup
- [ ] Semgrep security scan is enabled in Gate 2
- [ ] `CC_BLOCKED_PATTERNS` includes any project-specific dangerous operations
- [ ] Firewall rules restrict access between nodes to required ports only
