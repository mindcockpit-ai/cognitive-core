# Configuration Reference

All configuration lives in a single `cognitive-core.conf` file using shell syntax. Hooks source this file at runtime via `_cc_load_config`. The installer creates this file interactively if it does not exist.

## Config File Location

Resolution order (first match wins):

1. `$PROJECT_ROOT/cognitive-core.conf`
2. `$PROJECT_ROOT/.claude/cognitive-core.conf`
3. `$HOME/.cognitive-core/defaults.conf`

## Variable Reference

### Project Identity

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CC_PROJECT_NAME` | string | Directory basename | Project name used in metrics, manifests, and generated files |
| `CC_PROJECT_DESCRIPTION` | string | `"A software project"` | Brief project description |
| `CC_ORG` | string | Git user.name | Organization or owner name |

### Language & Stack

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CC_LANGUAGE` | enum | `"python"` | Primary language. Options: `perl`, `python`, `node`, `java`, `go`, `rust`, `csharp` |
| `CC_LINT_EXTENSIONS` | string | Varies by language | Space-separated file extensions to lint (include dots, e.g., `".py .pyi"`) |
| `CC_LINT_COMMAND` | string | Varies by language | Lint command template. `$1` is replaced with the file path |
| `CC_FORMAT_COMMAND` | string | `""` | Format check command template (optional). `$1` is replaced with the file path |
| `CC_TEST_COMMAND` | string | Varies by language | Test runner command (e.g., `"pytest"`, `"prove -l t/"`) |
| `CC_TEST_PATTERN` | string | Varies by language | Glob pattern for test files |

Language defaults set by `install.sh`:

| Language | Lint | Test | Extensions |
|----------|------|------|------------|
| perl | `perlcritic $1` | `prove -l t/` | `.pl .pm .t` |
| python | `ruff check $1` | `pytest` | `.py .pyi` |
| node | `eslint $1` | `npm test` | `.js .ts .tsx` |
| java | `checkstyle $1` | `mvn test` | `.java` |
| go | `golangci-lint run $1` | `go test ./...` | `.go` |
| rust | `cargo clippy -- -D warnings` | `cargo test` | `.rs` |
| csharp | `dotnet format --verify-no-changes` | `dotnet test` | `.cs` |

### Database

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CC_DATABASE` | enum | `"none"` | Database type. Options: `oracle`, `postgresql`, `mysql`, `sqlite`, `none` |

Database packs add additional variables when installed (e.g., `CC_DB_PORT`, `CC_DB_IN_CLAUSE_LIMIT`, `CC_DB_DATE_FORMAT`).

### Environment Setup

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CC_ENV_VARS` | multiline string | `""` | Newline-separated `KEY=VALUE` pairs set on session start. Use `${PROJECT_DIR}` for the project root path |

Example:
```bash
CC_ENV_VARS="
PYTHONPATH=${PROJECT_DIR}/src:${PYTHONPATH:-}
DATABASE_URL=sqlite:///dev.db
"
```

### Architecture

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CC_ARCHITECTURE` | enum | `"ddd"` | Architecture pattern. Options: `ddd`, `mvc`, `clean`, `hexagonal`, `layered`, `none` |
| `CC_SRC_ROOT` | string | `"src"` | Source code root directory (relative to project root) |
| `CC_TEST_ROOT` | string | `"tests"` | Test code root directory (relative to project root) |

### Agents

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CC_AGENTS` | string | `"coordinator reviewer architect tester researcher"` | Space-separated agent names to install. Options: `coordinator`, `reviewer`, `architect`, `tester`, `researcher`, `database`, `security`, `updater` |
| `CC_COORDINATOR_MODEL` | enum | `"opus"` | Model for the coordinator agent. Options: `opus`, `sonnet` |
| `CC_SPECIALIST_MODEL` | enum | `"sonnet"` | Model for specialist agents. Options: `opus`, `sonnet` |

### Skills

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CC_SKILLS` | string | `"session-resume code-review pre-commit fitness project-status"` | Space-separated skill names to install |

Available skills: `session-resume`, `session-sync`, `code-review`, `pre-commit`, `fitness`, `project-status`, `workflow-analysis`, `test-scaffold`, `tech-intel`, `security-baseline`, `secrets-setup`, `skill-sync`, `project-board`, `workspace-monitor`, `acceptance-verification`, `ctf-pentesting`

### Hooks

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CC_HOOKS` | string | `"setup-env compact-reminder validate-bash post-edit-lint"` | Space-separated hook names to enable |

Available hooks: `setup-env`, `compact-reminder`, `validate-bash`, `validate-read`, `validate-write`, `validate-fetch`, `post-edit-lint`

### Compact Rules

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CC_COMPACT_RULES` | multiline string | Generic rules | Critical rules re-injected after context compaction. These are your project's "golden rules" that must survive compaction |

Example:
```bash
CC_COMPACT_RULES="
1. Always use type hints in function signatures
2. Use parameterized queries for all database operations
3. Follow the architecture pattern defined in CLAUDE.md
4. Git commits: type(scope): subject format, no AI references
5. Run lint before every commit
"
```

### Safety Rules

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CC_BLOCKED_PATTERNS` | string | `""` | Space-separated regex patterns for additional bash commands to block (beyond built-in safety rules) |

### Git

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CC_MAIN_BRANCH` | string | `"main"` | Main branch name (used by safety guard to block force pushes) |
| `CC_COMMIT_FORMAT` | enum | `"conventional"` | Commit message format. Options: `conventional`, `freeform` |
| `CC_COMMIT_SCOPES` | string | `"api ui db auth core"` | Space-separated valid commit scopes (for documentation) |

### CI/CD

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CC_ENABLE_CICD` | bool | `"true"` | Install CI/CD pipeline files |
| `CC_RUNNER_TYPE` | enum | `"self-hosted"` | Runner type. Options: `self-hosted`, `github-hosted` |
| `CC_MONITORING` | bool | `"true"` | Install the monitoring stack (Prometheus, Grafana, Alertmanager) |
| `CC_FITNESS_LINT` | int | `60` | Minimum fitness score for the lint gate (percentage) |
| `CC_FITNESS_COMMIT` | int | `80` | Minimum fitness score for the commit gate |
| `CC_FITNESS_TEST` | int | `85` | Minimum fitness score for the test gate |
| `CC_FITNESS_MERGE` | int | `90` | Minimum fitness score for the merge gate |
| `CC_FITNESS_DEPLOY` | int | `95` | Minimum fitness score for the deploy gate |

### Horizontal Scaling

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CC_RUNNER_NODES` | int | `1` | Number of runner VPS nodes |
| `CC_RUNNER_LABELS` | string | `"self-hosted,linux,docker"` | Comma-separated runner labels for GitHub Actions |

### Experimental

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CC_AGENT_TEAMS` | bool | `"false"` | Enable agent team coordination features |
| `CC_MCP_SERVERS` | string | `"context7"` | Space-separated MCP servers to configure |

### Framework Synchronization

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CC_UPDATE_AUTO_CHECK` | bool | `"true"` | Enable automatic update checking at session start |
| `CC_UPDATE_CHECK_INTERVAL` | int | `7` | Days between automatic update checks |
| `CC_SKILL_AUTO_UPDATE` | bool | `"false"` | Auto-apply safe updates without prompting (only unmodified files) |
| `CC_SKILL_UPDATE_SOURCES` | string | `"core"` | Sources to check: `core`, `language-packs`, `database-packs` |

### Context Management

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CC_ENABLE_CLEANUP_CRON` | bool | `"true"` | Enable weekly context cleanup cron job |
| `CC_SESSION_DOCS_DIR` | string | `"docs"` | Directory for session documentation (relative to project root) |
| `CC_SESSION_MAX_AGE_DAYS` | int | `30` | Maximum age in days before session docs are auto-archived |

## Usage in Hooks

All hooks source the config via the shared library:

```bash
source "${SCRIPT_DIR}/_lib.sh"
_cc_load_config

# Now all CC_* variables are available
echo "$CC_PROJECT_NAME"
echo "$CC_LANGUAGE"
```

## Overriding at Runtime

Since the config uses shell syntax, environment variables take precedence when exported before a session:

```bash
CC_MAIN_BRANCH=develop claude
```

However, because `_cc_load_config` sources the file (which uses assignment, not `export`), the file values will overwrite environment variables. To override reliably, set the variable after sourcing, or modify the config file.
