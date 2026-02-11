# Monitoring Guide

The cognitive-core monitoring stack provides observability for CI/CD pipelines, host infrastructure, and application containers using Prometheus, Grafana, and Alertmanager.

## Stack Components

| Component | Version | Port | Purpose |
|-----------|---------|------|---------|
| Prometheus | 2.51.0 | 9090 | Metrics collection and storage |
| Grafana | 10.4.0 | 3000 | Dashboards and visualization |
| Alertmanager | 0.27.0 | 9093 | Alert routing and notifications |
| Node Exporter | 1.7.0 | 9100 | Host-level metrics (CPU, memory, disk) |
| cAdvisor | 0.49.1 | 8080 | Container-level metrics |
| Pushgateway | 1.7.0 | 9091 | Batch/CI job metrics ingestion |
| Nginx | 1.25 | 8888 | Reverse proxy for external access |

## Prerequisites

- Docker and Docker Compose installed
- Ports 3000, 9090, 9091, 9093 available (or configure alternatives)
- The CI/CD pipeline installed (`CC_MONITORING="true"` during setup)

## Quick Start

```bash
# 1. Copy the environment template
cp cicd/monitoring/.env.template cicd/monitoring/.env

# 2. Edit .env with real credentials (see Environment Variables below)
# At minimum, set GRAFANA_ADMIN_PASSWORD

# 3. Start the stack
cd cicd/docker
docker compose -f docker-compose.monitoring.yml --env-file ../monitoring/.env up -d

# 4. Access Grafana
open http://localhost:3000
# Login: admin / <your GRAFANA_ADMIN_PASSWORD>
```

## Environment Variables (.env)

Copy `.env.template` to `.env` and configure these values. Never commit `.env` to version control.

### Grafana

| Variable | Default | Description |
|----------|---------|-------------|
| `GRAFANA_ADMIN_USER` | `admin` | Grafana admin username |
| `GRAFANA_ADMIN_PASSWORD` | (required) | Grafana admin password. Must be set -- compose will fail without it |
| `GRAFANA_ROOT_URL` | `http://localhost:3000` | Public URL for Grafana (used in alert links) |

### Slack

| Variable | Default | Description |
|----------|---------|-------------|
| `SLACK_WEBHOOK_URL` | (placeholder) | Incoming webhook URL for Slack notifications |
| `SLACK_CHANNEL_CRITICAL` | `#alerts-critical` | Channel for critical alerts |
| `SLACK_CHANNEL_WARNINGS` | `#alerts-warnings` | Channel for warning alerts |
| `SLACK_CHANNEL_CICD` | `#cicd-alerts` | Channel for CI/CD pipeline alerts |

### Email / SMTP

| Variable | Default | Description |
|----------|---------|-------------|
| `SMTP_HOST` | `smtp.gmail.com` | SMTP server hostname |
| `SMTP_PORT` | `587` | SMTP port (587 for TLS) |
| `SMTP_FROM` | `alerts@example.com` | Sender address |
| `SMTP_USERNAME` | `alerts@example.com` | SMTP authentication username |
| `SMTP_PASSWORD` | (placeholder) | SMTP authentication password |
| `ALERT_EMAIL_TO` | `team@example.com` | Recipient for alert digest emails |

### PagerDuty

| Variable | Default | Description |
|----------|---------|-------------|
| `PAGERDUTY_SERVICE_KEY` | (placeholder) | PagerDuty Events API v2 integration key |

### Infrastructure

| Variable | Default | Description |
|----------|---------|-------------|
| `DOCKER_GID` | `999` | Host Docker group ID (find with `getent group docker \| cut -d: -f3`) |
| `NGINX_PORT` | `8888` | External port for the Nginx reverse proxy |
| `PUSHGATEWAY_URL` | `http://127.0.0.1:9091` | Pushgateway URL for CI scripts |

## Prometheus Configuration

The Prometheus config (`cicd/monitoring/prometheus.yml`) defines scrape targets:

| Job | Target | Metrics |
|-----|--------|---------|
| `prometheus` | `localhost:9090` | Prometheus self-monitoring |
| `node-exporter` | `node-exporter:9100` | Host CPU, memory, disk, network |
| `cadvisor` | `cadvisor:8080` | Container CPU, memory, network |
| `pushgateway` | `pushgateway:9091` | CI/CD job metrics from pipelines |
| `alertmanager` | `alertmanager:9093` | Alertmanager health |

### Adding Application Metrics

Uncomment and configure the application target in `prometheus.yml`:

```yaml
- job_name: 'application'
  metrics_path: '/metrics'
  static_configs:
    - targets: ['app:8080']
      labels:
        component: 'application'
```

### Retention

Prometheus retains 30 days of metrics by default. Adjust in `docker-compose.monitoring.yml`:

```yaml
command:
  - '--storage.tsdb.retention.time=30d'
```

## Grafana Dashboards

Two dashboards are auto-provisioned on startup:

### CI/CD Overview Dashboard

Visualizes pipeline metrics pushed by `push-metrics.sh`:

- Fitness score trends over time
- Job duration and status (success/failure)
- Test pass rate history
- Active/recent pipeline runs

### App Metrics Dashboard

Visualizes application-level metrics (requires your app to expose a `/metrics` endpoint):

- Request rates and latencies
- Error rates
- Custom business metrics

### Dashboard Provisioning

Dashboards are loaded from `cicd/monitoring/grafana/dashboards/` and auto-refresh every 30 seconds. To add a custom dashboard:

1. Create or export a dashboard JSON file
2. Place it in `cicd/monitoring/grafana/dashboards/`
3. Restart Grafana or wait for the 30-second auto-refresh

The Prometheus datasource is auto-provisioned via `cicd/monitoring/grafana/provisioning/datasources.yml`.

## Alertmanager Configuration

Alerts are routed by severity to appropriate channels:

| Severity | Receiver | Channel |
|----------|----------|---------|
| Critical | PagerDuty + Slack | `#alerts-critical` |
| Warning | Slack | `#alerts-warnings` |
| Info | Email digest | Configured `ALERT_EMAIL_TO` |
| CI/CD | Slack | `#cicd-alerts` |

### Routing Rules

- Critical alerts trigger both PagerDuty and Slack simultaneously
- If a critical alert fires, matching warning alerts are suppressed (inhibition)
- If the `HostDown` alert fires, all other alerts for that host are suppressed
- Alerts are grouped by `alertname`, `severity`, and `job`
- Group wait: 30 seconds (10 seconds for critical)
- Repeat interval: 4 hours (1 hour for critical)

### Adding Alert Rules

Add Prometheus alerting rules to `cicd/monitoring/alert-rules.yml`:

```yaml
groups:
  - name: custom
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
        for: 5m
        labels:
          severity: warning
          category: application
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }} errors/sec"
```

### Testing Alerts

```bash
# Send a test alert to Alertmanager
curl -X POST http://localhost:9093/api/v2/alerts \
  -H "Content-Type: application/json" \
  -d '[{
    "labels": {"alertname": "TestAlert", "severity": "warning"},
    "annotations": {"summary": "Test alert from manual trigger"}
  }]'
```

## Accessing Dashboards

| Service | URL | Auth |
|---------|-----|------|
| Grafana | `http://localhost:3000` | `admin` / (your password) |
| Prometheus | `http://localhost:9090` | None (internal only) |
| Alertmanager | `http://localhost:9093` | None (internal only) |

For production, place Nginx or a similar reverse proxy in front with TLS and authentication. The included Nginx service (`port 8888`) can be extended with TLS termination.

## Stopping the Stack

```bash
cd cicd/docker
docker compose -f docker-compose.monitoring.yml --env-file ../monitoring/.env down

# To also remove stored data volumes:
docker compose -f docker-compose.monitoring.yml --env-file ../monitoring/.env down -v
```
