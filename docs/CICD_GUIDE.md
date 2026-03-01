# CI/CD Pipeline Guide

The cognitive-core CI/CD pipeline implements a 5-gate progressive quality model using GitHub Actions. Each gate has configurable fitness thresholds that increase strictness as code moves toward production.

## Pipeline Overview

```
Commit --> Gate 1: Lint --> Gate 2: Commit --> Gate 3: Test --> Gate 4: Merge --> Gate 5: Deploy
              60%              80%               85%              90%              95%
```

| Gate | Purpose | Default Threshold | Trigger |
|------|---------|-------------------|---------|
| 1. Lint | Syntax checks on changed files | 60% | Every push |
| 2. Commit | Secrets scan, Semgrep, commit message validation | 80% | After lint passes |
| 3. Test | Run test suite, compute fitness score | 85% | After commit validation |
| 4. Merge | Aggregate quality report for PR approval | 90% | Pull requests only |
| 5. Deploy | Container build and push | 95% | Push to main/master only |

## Prerequisites

- GitHub repository with Actions enabled
- For self-hosted runners: a Linux VPS with Docker installed
- For monitoring: Docker Compose on the runner or a separate host

## Installation

Set `CC_ENABLE_CICD="true"` in `cognitive-core.conf` before running `install.sh`, or answer "true" when prompted during interactive setup.

```bash
./install.sh /path/to/your-project
```

This installs:

```
your-project/
+-- .github/workflows/
|   +-- evolutionary-cicd.yml    # Main 5-gate pipeline
+-- cicd/
|   +-- docker/
|   |   +-- docker-compose.runner.yml       # Self-hosted runner containers
|   |   +-- docker-compose.monitoring.yml   # Monitoring stack
|   +-- scripts/
|   |   +-- setup-runner.sh      # Runner provisioning script
|   |   +-- fitness-check.sh     # Pluggable quality scoring
|   |   +-- push-metrics.sh      # Push metrics to Prometheus
|   +-- monitoring/              # Prometheus, Grafana, Alertmanager configs
|   +-- k8s/                     # Kubernetes manifests (optional)
```

## GitHub Actions Configuration

### Repository Variables

The pipeline reads configuration from GitHub repository variables (Settings > Secrets and variables > Actions > Variables):

| Variable | Default | Description |
|----------|---------|-------------|
| `RUNNER_LABEL` | `ubuntu-latest` | Runner label (set to your self-hosted label for self-hosted runners) |
| `GATE_TEST_MIN_PASS_RATE` | `95` | Minimum test pass rate percentage |
| `GATE_MERGE_FITNESS_THRESHOLD` | `70` | Minimum fitness score for merge gate |
| `GATE_DEPLOY_FITNESS_THRESHOLD` | `80` | Minimum fitness score for deploy gate |
| `PROJECT_NAME` | `app` | Project name for metrics and container tags |
| `CONTAINER_REGISTRY` | `ghcr.io` | Container registry for deploy gate |
| `SEMGREP_RULES` | `p/default` | Semgrep rulesets for security scanning |

### Repository Secrets

For the deploy gate (container push):

- `GITHUB_TOKEN` is provided automatically by GitHub Actions

For self-hosted runners:

- Runner tokens are configured during `setup-runner.sh` execution (not stored as secrets)

## Fitness Check System

The `fitness-check.sh` script computes a weighted quality score (0-100) based on pluggable checks.

### Core Checks (Language-Agnostic)

| Check | Weight | What It Measures |
|-------|--------|------------------|
| Git cleanliness | 5 | Uncommitted files (5 points deducted per dirty file) |
| Documentation | 5 | Presence of README, docs/, CHANGELOG |
| CI/CD configuration | 10 | Workflow files exist |
| No hardcoded secrets | 15 | Scans config files for credential patterns |
| Dependency manifest | 5 | package.json, requirements.txt, cpanfile, etc. |
| Test suite | 15 | Test directory exists and contains test files |
| .gitignore quality | 5 | Covers standard exclusions |

### Language Pack Checks

The remaining weight (40 points) is allocated to language-specific fitness checks loaded from `language-packs/<lang>/scripts/fitness-check.sh`. Pack scripts output a score and description:

```
85 All lint checks passed with severity 4
```

### Usage

```bash
# Full report with color-coded output
bash cicd/scripts/fitness-check.sh

# Score number only (used in CI pipeline)
bash cicd/scripts/fitness-check.sh --score-only

# Verbose output showing each check
bash cicd/scripts/fitness-check.sh --verbose

# Check against a specific gate threshold
bash cicd/scripts/fitness-check.sh --gate merge
bash cicd/scripts/fitness-check.sh --gate deploy
```

### Customizing Thresholds

Gate thresholds are configured in three places (in order of precedence):

1. GitHub repository variables (`GATE_MERGE_FITNESS_THRESHOLD`, etc.)
2. Environment variables (`GATE_MERGE_THRESHOLD`, `GATE_DEPLOY_THRESHOLD`)
3. `cognitive-core.conf` (`CC_FITNESS_MERGE`, `CC_FITNESS_DEPLOY`, etc.)

## Self-Hosted Runner Setup

For teams that need more control or want to avoid GitHub-hosted runner costs:

```bash
# Generate a runner token at:
# https://github.com/YOUR-ORG/YOUR-REPO/settings/actions/runners/new

# Install a single runner
bash cicd/scripts/setup-runner.sh \
  --org your-org \
  --repo your-repo \
  --token AXXXXXXXXXXXXXXX

# Install as a systemd service (auto-start on boot)
bash cicd/scripts/setup-runner.sh \
  --org your-org \
  --repo your-repo \
  --token AXXXXXXXXXXXXXXX \
  --service

# Install a second node
bash cicd/scripts/setup-runner.sh \
  --org your-org \
  --repo your-repo \
  --token AXXXXXXXXXXXXXXX \
  --node-id 2 \
  --service
```

### Docker-Based Runners

Alternatively, use `docker-compose.runner.yml` for containerized runners:

```bash
cp cicd/monitoring/.env.template cicd/monitoring/.env
# Edit .env with your GITHUB_ORG, GITHUB_REPO, RUNNER_TOKEN, DOCKER_GID

cd cicd/docker
docker compose -f docker-compose.runner.yml up -d
```

## Pipeline Workflow Details

### Gate 1: Lint

- Detects changed files using `git diff` (only lints what changed)
- Runs syntax checks for Perl, Python, and Shell files
- Supports `force_full_lint` workflow dispatch input to lint all files
- Uses `continue-on-error` so syntax issues produce warnings, not failures

### Gate 2: Commit Validation

- Scans changed files for potential secrets (passwords, API keys, tokens)
- Runs Semgrep security scan with configurable rulesets
- Validates commit messages against conventional commit format on PRs

### Gate 3: Test

- Auto-detects the test framework (Perl/prove, Python/pytest, Node/jest/mocha, Go)
- Runs tests once (single-pass, no redundant re-runs)
- Produces JUnit XML for GitHub Actions test reporting
- Runs `fitness-check.sh` and records the score

### Gate 4: Merge Readiness

- Runs only on pull requests
- Aggregates test pass rate and fitness score
- Prints a merge readiness report
- Blocks merge if thresholds are not met

### Gate 5: Deploy

- Runs only on pushes to main/master
- Checks fitness score against deploy threshold
- Builds and pushes a Docker container to the configured registry
- Pushes deployment metrics to Pushgateway

### Pipeline Summary

A final summary job always runs and writes a GitHub Actions step summary with gate results, test pass rate, and fitness score.

## Pushing Metrics

The `push-metrics.sh` script sends CI/CD metrics to Prometheus Pushgateway:

```bash
# Push fitness score
bash cicd/scripts/push-metrics.sh push_fitness --project myapp --score 85

# Record job timing
bash cicd/scripts/push-metrics.sh push_job_start --project myapp --job lint
bash cicd/scripts/push-metrics.sh push_job_end --project myapp --job lint --status success

# Push test results
bash cicd/scripts/push-metrics.sh push_test_results --project myapp --total 150 --passed 145 --failed 5
```

All metrics use gauge semantics (absolute values, not counters) and are pushed via HTTP PUT to replace the previous value for each grouping key.

## Automated PR Reviews

For projects using branch protection with required reviews, a GitHub App can be configured to let the `code-standards-reviewer` agent post reviews as a separate identity. This enables automated approvals that satisfy branch protection requirements.

See [GitHub App Reviewer Guide](GITHUB_APP_REVIEWER.md) for setup instructions.
