# Architecture Overview

cognitive-core is a portable framework that installs production-grade hooks, agents, skills, CI/CD pipelines, and monitoring into any Claude Code project. This document describes the system architecture and how the components interact.

## High-Level Structure

```
cognitive-core (framework repo)          Target project (after install)
+-- core/                                .claude/
|   +-- hooks/                             +-- hooks/
|   +-- agents/                            +-- agents/
|   +-- skills/                            +-- skills/
|   +-- templates/                         +-- settings.json
+-- language-packs/                        +-- cognitive-core/version.json
+-- database-packs/                      CLAUDE.md
+-- cicd/                                cognitive-core.conf
+-- install.sh
+-- update.sh
```

The framework source is cloned once. Running `install.sh` copies selected components into the target project's `.claude/` directory, generates configuration files, and writes a version manifest for safe future updates.

## Config-Driven Design

All behavior flows from a single configuration file, `cognitive-core.conf`, which uses shell syntax and is sourced at runtime by every hook. The resolution order is:

1. `$PROJECT_ROOT/cognitive-core.conf`
2. `$PROJECT_ROOT/.claude/cognitive-core.conf`
3. `$HOME/.cognitive-core/defaults.conf` (user-level defaults)

Every `CC_*` variable controls what gets installed and how hooks behave. There is no secondary config format and no YAML/JSON parsing at runtime. This keeps the hook execution path fast and dependency-free.

## Hook System

Hooks are bash scripts triggered by Claude Code at specific lifecycle events. They communicate with Claude through a JSON protocol on stdout.

### Hook Events

| Event | Hook File | Trigger |
|-------|-----------|---------|
| SessionStart (startup/resume) | `setup-env.sh` | New or resumed session |
| PreToolUse (Bash) | `validate-bash.sh` | Before any bash command runs |
| PostToolUse (Edit/Write) | `post-edit-lint.sh` | After any file is edited |
| Notification (compact) | `compact-reminder.sh` | After context compaction |

### JSON Protocol

Each hook receives context on stdin as JSON and outputs a JSON response on stdout. The shared library `_lib.sh` provides helper functions:

- `_cc_json_session_context "$text"` -- Injects context into the session (SessionStart)
- `_cc_json_pretool_deny "$reason"` -- Blocks a command with a reason (PreToolUse)
- `_cc_json_posttool_context "$text"` -- Adds feedback after a tool runs (PostToolUse)
- `_cc_json_get ".path.to.field"` -- Extracts fields from stdin JSON (uses jq if available, falls back to grep)

### Shared Library (_lib.sh)

Every hook sources `_lib.sh` as its first action. The library provides:

- **Config loading** via `_cc_load_config` -- sources `cognitive-core.conf` following the resolution order above
- **JSON output helpers** -- produce valid JSON with or without jq installed
- **Project directory resolution** -- determines `CC_PROJECT_DIR` from environment or filesystem

This shared library eliminates code duplication and ensures consistent behavior across all hooks.

### Bash Validation (Safety Guard)

The `validate-bash.sh` hook blocks dangerous commands before they execute:

- `rm` targeting system-critical paths (`/`, `/etc`, `/usr`, etc.)
- `git push --force` to main/master
- `git reset --hard`, `git clean -f`
- `DROP TABLE`, `TRUNCATE TABLE`, `DELETE FROM` without WHERE
- `chmod 777`
- Custom patterns defined in `CC_BLOCKED_PATTERNS`

Blocked commands produce a `deny` JSON response. Safe commands exit silently (exit 0, no output).

## Agent Hub-and-Spoke Model

Agents are markdown definition files that configure Claude Code's multi-agent system.

```
                +---------------------+
                | project-coordinator |
                |     (Hub / Opus)    |
                +----------+----------+
                           |
     +----------+----------+----------+----------+
     |          |          |          |          |
 solution   code-std    test      research  database
 architect  reviewer  specialist  analyst  specialist
```

The **project-coordinator** is the hub. It receives requests, analyzes them, and delegates to the appropriate specialist. After specialists complete their work, the **code-standards-reviewer** performs a mandatory quality gate.

| Agent | Model | Responsibility |
|-------|-------|----------------|
| project-coordinator | opus | Orchestration, delegation |
| solution-architect | opus | Architecture, business workflows |
| code-standards-reviewer | sonnet | Code review, standards compliance |
| test-specialist | sonnet | Tests, coverage, QA |
| research-analyst | opus | External research, library evaluation |
| database-specialist | opus | Query optimization, schema design |

Which agents to install is controlled by `CC_AGENTS` in configuration.

## Skill Hierarchy

Skills are reusable knowledge modules installed to `.claude/skills/<name>/SKILL.md`.

### Auto-Load vs. Manual

| Type | Behavior | Examples |
|------|----------|---------|
| Auto-load | Claude reads at session start | session-resume, code-review, tech-intel |
| Manual | Invoked explicitly via `/skill-name` | pre-commit, fitness, project-status, session-sync, workflow-analysis, test-scaffold |

Manual skills use `disable-model-invocation: true` to avoid consuming context budget at startup.

### Progressive Disclosure

Skills follow a two-tier pattern:
- `SKILL.md` -- Concise instructions (under 500 lines)
- `references/` -- Detailed reference material loaded on demand

This keeps the auto-load context budget under 100KB total.

## Install / Update Lifecycle

### install.sh

1. Validates the target is a git repository
2. Checks for an existing installation via `version.json`
3. Runs interactive setup if no `cognitive-core.conf` exists (prompts for language, database, architecture, agents, skills, hooks, CI/CD)
4. Creates `.claude/` directory structure
5. Copies selected hooks, agents, and skills from the framework
6. Installs language pack and database pack if configured
7. Generates `settings.json` (hook wiring), `CLAUDE.md` (scaffold), `AGENTS_README.md`
8. Optionally installs CI/CD workflows, Docker configs, monitoring stack, and K8s manifests
9. Writes `version.json` with SHA-256 checksums of all installed files

### update.sh

1. Reads the existing `version.json` manifest
2. For each tracked file, computes SHA-256 of the installed copy
3. Compares against the original checksum (from install time) and the latest framework file
4. **Unmodified files** -- updated silently
5. **User-modified files** -- preserved with a warning to review manually
6. **New framework files** -- installed automatically
7. Writes an updated `version.json` with new checksums

This checksum-based approach means `update.sh` never overwrites your customizations.

## Language and Database Packs

Packs are drop-in extensions that add language-specific or database-specific configuration and skills.

```
language-packs/python/
+-- pack.conf              # CC_* defaults for Python projects
+-- skills/
    +-- python-patterns/
        +-- SKILL.md       # Python-specific patterns and rules
```

When `CC_LANGUAGE` is set, `install.sh` copies the pack's skills into `.claude/skills/` and its `pack.conf` values serve as defaults during interactive setup.

## CI/CD Pipeline

The pipeline uses a 5-gate progressive quality model. See `docs/CICD_GUIDE.md` for the full setup guide.

```
Commit --> Gate 1: Lint --> Gate 2: Commit --> Gate 3: Test --> Gate 4: Merge --> Gate 5: Deploy
              60%             80%                85%             90%              95%
```

Each gate runs `fitness-check.sh` to produce a weighted quality score. Metrics are pushed to Prometheus via `push-metrics.sh` and visualized in Grafana dashboards.

## Design Principles

1. **Single config** -- One `cognitive-core.conf` drives everything
2. **No runtime dependencies** -- Hooks work with bash alone (jq is optional)
3. **Safe updates** -- Checksum-based updater never destroys user work
4. **Progressive disclosure** -- Concise SKILL.md files, detail in references/
5. **Language agnostic** -- Core framework has no language assumptions; packs add specifics
6. **Security by default** -- Dangerous commands blocked, credentials externalized, Pushgateway localhost-only
