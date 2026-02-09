# CI/CD Pattern

Continuous Integration and Continuous Deployment architecture for reliable software delivery.

## Problem

- Manual deployments are error-prone
- Integration issues discovered late
- Long feedback loops
- Inconsistent environments
- Difficulty tracking what's deployed

## Solution: CI/CD Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CI/CD Pipeline                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐        │
│  │ Commit │───►│ Build  │───►│  Test  │───►│ Stage  │───►│ Deploy │        │
│  │        │    │        │    │        │    │        │    │        │        │
│  └────────┘    └────────┘    └────────┘    └────────┘    └────────┘        │
│      │             │             │             │             │              │
│      ▼             ▼             ▼             ▼             ▼              │
│  ┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐        │
│  │ Lint   │    │Compile │    │  Unit  │    │ E2E    │    │ Prod   │        │
│  │ Check  │    │ Deps   │    │  Int.  │    │ Perf   │    │ Canary │        │
│  │ Format │    │ Scan   │    │ Sec.   │    │ Smoke  │    │ Blue/  │        │
│  └────────┘    └────────┘    └────────┘    └────────┘    │ Green  │        │
│                                                          └────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Abstract Interface

```yaml
# Abstract pipeline definition
pipeline:
  name: string
  trigger:
    branches: [string]
    paths: [string]

  stages:
    - name: string
      jobs:
        - name: string
          runs_on: string
          steps:
            - name: string
              command: string
          artifacts:
            - path: string
              retention: duration
          cache:
            - key: string
              paths: [string]
```

## Pipeline Stages

### 1. Commit Stage

Fast feedback on code quality.

```yaml
# Abstract commit stage
commit:
  timeout: 10m
  steps:
    - lint: Check code style and formatting
    - security_scan: Static security analysis
    - unit_test: Fast unit tests
    - build: Compile/bundle application
```

### 2. Test Stage

Comprehensive testing.

```yaml
# Abstract test stage
test:
  timeout: 30m
  parallel: true
  steps:
    - integration_test: Database, API tests
    - contract_test: API contract validation
    - security_test: DAST, dependency scan
    - coverage: Code coverage report
```

### 3. Deploy Stage

Progressive deployment.

```yaml
# Abstract deploy stage
deploy:
  environments:
    - name: staging
      auto_deploy: true
      tests:
        - smoke_test
        - e2e_test

    - name: production
      manual_approval: true
      strategy: canary
      rollback: automatic
```

## Deployment Strategies

### 1. Blue-Green Deployment

```
        Load Balancer
              │
    ┌─────────┴─────────┐
    ▼                   ▼
┌───────┐           ┌───────┐
│ Blue  │           │ Green │
│ (v1)  │           │ (v2)  │
│ LIVE  │           │ IDLE  │
└───────┘           └───────┘
```

Switch traffic instantly, easy rollback.

### 2. Canary Deployment

```
           Load Balancer
                 │
    ┌────────────┼────────────┐
    │            │            │
    ▼            ▼            ▼
┌───────┐   ┌───────┐   ┌───────┐
│ v1    │   │ v1    │   │ v2    │
│ (90%) │   │       │   │ (10%) │
└───────┘   └───────┘   └───────┘
```

Gradual rollout, real-world validation.

### 3. Rolling Deployment

```
┌───────┐   ┌───────┐   ┌───────┐
│ v2    │   │ v1→v2 │   │ v1    │
│ done  │   │ doing │   │ next  │
└───────┘   └───────┘   └───────┘
```

Sequential instance updates.

## Trade-offs

| Aspect | Benefit | Cost |
|--------|---------|------|
| Fast feedback | Early bug detection | Infrastructure cost |
| Automation | Consistency | Initial setup effort |
| Parallel jobs | Speed | Resource usage |
| Manual gates | Safety | Slower deployment |

## Implementation Examples

| Platform | Best For | Guide |
|----------|----------|-------|
| **GitHub Actions** | GitHub-hosted projects | [github-actions/](./implementations/github-actions/) |
| **GitLab CI** | GitLab ecosystem | [gitlab-ci/](./implementations/gitlab-ci/) |
| **Jenkins** | Enterprise, on-prem | [jenkins/](./implementations/jenkins/) |
| **Azure DevOps** | Microsoft ecosystem | [azure-devops/](./implementations/azure-devops/) |

## Platform-Specific Examples

### GitHub Actions

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install ruff
      - run: ruff check src/

  test:
    needs: lint
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: test
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
      - run: pip install -e .[test]
      - run: pytest --cov=src --cov-report=xml

  deploy-staging:
    needs: test
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4
      - run: ./deploy.sh staging

  deploy-production:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - run: ./deploy.sh production
```

### GitLab CI

```yaml
stages:
  - lint
  - test
  - build
  - deploy

variables:
  PYTHON_VERSION: "3.12"

lint:
  stage: lint
  image: python:${PYTHON_VERSION}
  script:
    - pip install ruff
    - ruff check src/
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH

test:
  stage: test
  image: python:${PYTHON_VERSION}
  services:
    - postgres:16
  variables:
    POSTGRES_PASSWORD: test
  script:
    - pip install -e .[test]
    - pytest --cov=src --cov-report=xml
  coverage: '/TOTAL.*\s+(\d+%)$/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml

deploy_staging:
  stage: deploy
  environment:
    name: staging
  script:
    - ./deploy.sh staging
  rules:
    - if: $CI_COMMIT_BRANCH == "develop"

deploy_production:
  stage: deploy
  environment:
    name: production
  script:
    - ./deploy.sh production
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
```

### Jenkins (Declarative)

```groovy
pipeline {
    agent any

    environment {
        PYTHON_VERSION = '3.12'
    }

    stages {
        stage('Lint') {
            steps {
                sh 'pip install ruff'
                sh 'ruff check src/'
            }
        }

        stage('Test') {
            steps {
                sh 'pip install -e .[test]'
                sh 'pytest --cov=src --cov-report=xml'
            }
            post {
                always {
                    publishCoverage adapters: [coberturaAdapter('coverage.xml')]
                }
            }
        }

        stage('Deploy Staging') {
            when {
                branch 'develop'
            }
            steps {
                sh './deploy.sh staging'
            }
        }

        stage('Deploy Production') {
            when {
                branch 'main'
            }
            input {
                message "Deploy to production?"
            }
            steps {
                sh './deploy.sh production'
            }
        }
    }

    post {
        failure {
            slackSend channel: '#deployments', message: "Build failed: ${env.JOB_NAME}"
        }
    }
}
```

## Quality Gates

```yaml
quality_gates:
  - name: code_coverage
    threshold: 70%
    fail_on: below

  - name: security_vulnerabilities
    threshold: 0
    severity: [critical, high]
    fail_on: any

  - name: code_smells
    threshold: 10
    fail_on: above

  - name: test_pass_rate
    threshold: 100%
    fail_on: below
```

## Fitness Criteria

| Criteria | Threshold | Description |
|----------|-----------|-------------|
| `pipeline_duration` | <15min | Commit to deploy time |
| `test_coverage` | 70% | Minimum coverage |
| `zero_vulnerabilities` | 100% | No critical/high vulns |
| `deployment_frequency` | Daily | Deploy capability |
| `rollback_time` | <5min | Recovery speed |
| `build_success_rate` | 95% | Pipeline reliability |

## See Also

- [Testing](../testing/) - Test strategy
- [Security](../security/) - Security in pipelines
- [Messaging](../messaging/) - Event-driven deployments
