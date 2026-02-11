# Horizontal Scaling Guide

This guide covers scaling CI/CD runners across multiple VPS nodes for teams that need parallel pipeline execution, faster feedback loops, or workload isolation.

## Architecture

```
                    +-------------------+
                    |  GitHub Actions   |
                    |  (Workflow Jobs)  |
                    +--------+----------+
                             |
              +--------------+--------------+
              |              |              |
       +------+------+ +----+-------+ +----+-------+
       |  VPS Node 1 | | VPS Node 2 | | VPS Node 3 |
       |  $5-10/mo   | |  $5-10/mo  | |  $5-10/mo  |
       +------+------+ +----+-------+ +----+-------+
       | runner-1    | | runner-2   | | runner-3   |
       | Docker      | | Docker     | | Docker     |
       | node-export | | node-export| | node-export|
       +------+------+ +----+-------+ +----+-------+
              |              |              |
              +--------------+--------------+
                             |
                    +--------+----------+
                    |  Monitoring Host  |
                    |  Prometheus       |
                    |  Grafana          |
                    |  Alertmanager     |
                    +-------------------+
```

Each node runs a GitHub Actions self-hosted runner. A separate monitoring host (or one of the runner nodes) aggregates metrics from all nodes.

## Configuration

Set the scaling parameters in `cognitive-core.conf`:

```bash
CC_RUNNER_NODES="3"
CC_RUNNER_LABELS="self-hosted,linux,docker"
```

The workflow file (`evolutionary-cicd.yml`) uses runner labels to target self-hosted runners:

```yaml
runs-on: ${{ vars.RUNNER_LABEL || 'ubuntu-latest' }}
```

Set `RUNNER_LABEL` in your GitHub repository variables to match your runner labels (e.g., `self-hosted`).

## Node Setup

### Option A: Direct Installation (setup-runner.sh)

Run `setup-runner.sh` on each VPS node, incrementing `--node-id`:

```bash
# Node 1
ssh node1 'bash -s' < cicd/scripts/setup-runner.sh \
  --org your-org \
  --repo your-repo \
  --token AXXXXXXXX \
  --node-id 1 \
  --labels "self-hosted,linux,docker" \
  --service

# Node 2
ssh node2 'bash -s' < cicd/scripts/setup-runner.sh \
  --org your-org \
  --repo your-repo \
  --token AXXXXXXXX \
  --node-id 2 \
  --labels "self-hosted,linux,docker" \
  --service

# Node 3
ssh node3 'bash -s' < cicd/scripts/setup-runner.sh \
  --org your-org \
  --repo your-repo \
  --token AXXXXXXXX \
  --node-id 3 \
  --labels "self-hosted,linux,docker" \
  --service
```

Each node gets its own runner directory (`/opt/actions-runner-1`, `/opt/actions-runner-2`, etc.) and systemd service.

#### Prerequisites per Node

- Linux (Ubuntu 22.04+ recommended)
- Docker installed and running
- `curl` and `tar` available
- At least 2 GB disk space
- Runner user in the `docker` group

### Option B: Docker-Based Runners

Use `docker-compose.runner.yml` for containerized runners. Copy `.env.template` to each node, set `GITHUB_ORG`, `GITHUB_REPO`, `RUNNER_TOKEN`, and `DOCKER_GID`, then start:

```bash
docker compose -f docker-compose.runner.yml up -d                    # Single runner
docker compose -f docker-compose.runner.yml --profile multi-node up -d  # All 3 runners
```

## Shared Labels and Workload Isolation

All runners share labels (e.g., `self-hosted,linux,docker`). GitHub distributes jobs across matching runners. For isolation, assign distinct labels per node:

```bash
--labels "self-hosted,linux,docker,testing"   # Node 2: test workloads
--labels "self-hosted,linux,docker,deploy"    # Node 3: deploy only
```

Target specific nodes in the workflow with `runs-on: [self-hosted, testing]`.

## Monitoring Aggregation

### Single Monitoring Host

Run the monitoring stack on one node (or a dedicated monitoring host):

```bash
cd cicd/docker
docker compose -f docker-compose.monitoring.yml --env-file ../monitoring/.env up -d
```

### Scraping Multiple Nodes

Edit `cicd/monitoring/prometheus.yml` to scrape node exporters from all runner nodes:

```yaml
scrape_configs:
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node1:9100']
        labels:
          node: '1'
      - targets: ['node2:9100']
        labels:
          node: '2'
      - targets: ['node3:9100']
        labels:
          node: '3'
```

Ensure port 9100 is accessible between nodes (use VPN or firewall rules).

### Pushgateway Aggregation

All runner nodes push metrics to the same Pushgateway instance. Configure the Pushgateway URL on each node:

```bash
export PUSHGATEWAY_URL=http://monitoring-host:9091
```

For remote access, either:
- Set up a VPN between nodes (recommended)
- Open port 9091 with IP allowlisting (less secure)

By default, Pushgateway binds to `127.0.0.1` only. For multi-node setups, change the binding in `docker-compose.monitoring.yml`:

```yaml
pushgateway:
  ports:
    - "0.0.0.0:9091:9091"  # Open to network (secure with VPN/firewall)
```

## Cost Optimization

| Workload | Recommended Spec | Estimated Cost |
|----------|-----------------|----------------|
| Light (lint + small tests) | 1 vCPU, 1 GB RAM | $5/month |
| Medium (full test suite) | 2 vCPU, 2 GB RAM | $10/month |
| Heavy (Docker builds) | 2 vCPU, 4 GB RAM | $20/month |

Start with 1 node. Add a second when queue times exceed 5 minutes. Add a third for deploy isolation. Use `RUNNER_EPHEMERAL=true` in `.env` for burst capacity (runners pick up one job and terminate).

## VPN for Secure Communication

For multi-node setups, a VPN ensures secure communication between runner nodes and the monitoring host without exposing ports to the public internet.

### WireGuard Setup (Recommended)

1. Install WireGuard on all nodes
2. Configure a mesh or hub-spoke topology
3. Use WireGuard IP addresses in Prometheus scrape targets and Pushgateway URL
4. Bind monitoring services to the WireGuard interface

## Runner Management

```bash
# Check runner status (systemd)
sudo systemctl status actions.runner.ORG-REPO.runner-1

# View runner logs
sudo journalctl -u actions.runner.ORG-REPO.runner-1 -f

# Stop a runner
sudo systemctl stop actions.runner.ORG-REPO.runner-1

# Remove a runner (requires new token)
cd /opt/actions-runner-1
./config.sh remove --token AXXXXXXXX
```

## Generating Runner Tokens

Runner registration tokens are short-lived (1 hour). Generate them at:

```
https://github.com/YOUR-ORG/YOUR-REPO/settings/actions/runners/new
```

Or via the GitHub API:

```bash
curl -X POST \
  -H "Authorization: token YOUR_PAT" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/YOUR-ORG/YOUR-REPO/actions/runners/registration-token
```
