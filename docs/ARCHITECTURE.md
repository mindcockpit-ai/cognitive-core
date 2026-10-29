# Architecture Overview

cognitive-core is a portable framework that installs hooks, agents, skills, CI/CD pipelines, and monitoring into a project for AI coding assistants (Claude Code, Aider, IntelliJ, VS Code). This document describes the current architecture (v1.9.1) and the components planned next. For diagrams see [framework-overview.md](architecture/framework-overview.md).

## Status at a Glance

| Component | Count | Location |
|-----------|-------|----------|
| Hooks | 15 (+ 2 sourced helpers) | `core/hooks/` |
| Git hooks | 1 (`check-forbidden-chars.sh`) | `core/git-hooks/` |
| Agents | 10 | `core/agents/` |
| Core skills | 20 | `core/skills/` |
| Language packs | 11 | `language-packs/` |
| Database packs | 3 | `database-packs/` |
| Adapters | 4 (claude, aider, intellij, vscode) | `adapters/` |
| Test suites | 37 suites, 3000+ assertions | `tests/suites/` |

## High-Level Structure

```
cognitive-core (framework repo)          Target project (after install)
+-- core/                                .claude/  (Claude Code)
|   +-- hooks/       safety layer        |   +-- hooks/  agents/  skills/
|   +-- git-hooks/   pre-commit checks   |   +-- settings.json
|   +-- agents/      AI roles            |   +-- cognitive-core/version.json
|   +-- skills/      tasks + scripts     .cognitive-core/  (other adapters)
|   +-- utilities/   health, cleanup     CLAUDE.md / CONVENTIONS.md / ...
|   +-- templates/   settings, CLAUDE.md cognitive-core.conf
+-- adapters/        platform contract
+-- language-packs/  database-packs/
+-- cicd/            workflows, docker, k8s, monitoring
+-- plugin/          Claude Code plugin (secondary channel, build-plugin.sh)
+-- install.sh  update.sh
```

The framework source is cloned once. `install.sh` copies the selected components into the target project through the configured adapter, generates configuration, and writes a version manifest for safe updates.

## Config-Driven Design

All behavior flows from one file, `cognitive-core.conf`, in shell syntax and sourced at runtime by every hook. Resolution order:

1. `$PROJECT_ROOT/cognitive-core.conf`
2. `$PROJECT_ROOT/.claude/cognitive-core.conf`
3. `$HOME/.cognitive-core/defaults.conf` (user-level defaults)

Every `CC_*` variable controls what gets installed and how hooks behave. There is no secondary config format and no YAML/JSON parsing of configuration in the hook path. New variables must have defaults in code, because older conf files do not contain them.

## Execution Model: Who Decides, Who Executes

Most skill and agent behavior is interpreted by the LLM and therefore stochastic. Enforcement only exists where a script or the harness runs ([analysis](architecture/deterministic-vs-stochastic-analysis.md)). Every skill step is annotated with an ability type:

| Type | Flow | Enforcement |
|------|------|-------------|
| D | Script -> Output | Full (testable) |
| D/S | LLM input -> Script -> Output | Partial (mutation is deterministic) |
| S/D | Script data -> LLM -> Output | Partial (input is controlled) |
| S | LLM -> Output | None (variance acceptable) |
| H | Human decides | External |

Rule: anything that must hold (safety, state changes, gates) is moved into a D-type script or a hook. Skills orchestrate; scripts in `core/skills/<name>/scripts/` (or alongside `SKILL.md`) execute.

## Hook System

Hooks are bash scripts triggered at lifecycle events. They read JSON on stdin and answer with JSON on stdout; silent exit 0 means allow. Wiring comes from `core/templates/settings.json.tmpl`; only hooks listed in `CC_HOOKS` are installed.

| Event | Matcher | Hooks |
|-------|---------|-------|
| SessionStart | startup | `session-guard.sh`, `setup-env.sh`, `validate-git-remote-secret.sh` |
| SessionStart | compact | `compact-reminder.sh` |
| PreToolUse | Bash | `validate-bash.sh`, `validate-git-remote-secret.sh` |
| PreToolUse | Read | `validate-read.sh` |
| PreToolUse | WebFetch, WebSearch | `validate-fetch.sh` |
| PreToolUse | Write, Edit | `angular-version-guard.sh`, `spring-boot-version-guard.sh` |
| PostToolUse | Write, Edit | `post-edit-lint.sh`, `validate-write.sh` |
| PostToolUse | WebFetch | `post-fetch-cache.sh` |
| Stop | | `validate-reply-links.sh`, `notify-complete.sh`, `session-cleanup.sh` |
| SubagentStop, Notification | | `notify-complete.sh` |

Security levels (`CC_SECURITY_LEVEL`: minimal, standard, strict) set how hard the guards act. Responses are graduated: allow, ask, deny. Security guards deny; deprecations ask.

### Shared Library (`_lib.sh`)

Every hook sources `_lib.sh` first. It provides config loading (`_cc_load_config`), JSON helpers (`_cc_json_get`, `_cc_json_pretool_deny`, `_cc_json_session_context`, `_cc_json_posttool_context`), a session cache (`_cc_session_cache_add`), the `_cc_rg` ripgrep wrapper with grep fallback, and project directory resolution. It works with or without `jq` and when sourced into zsh. `_session-hygiene.sh` is the second sourced helper (orphan process detection).

### Bash Validation (Safety Guard)

`validate-bash.sh` blocks dangerous commands before they run: destructive `rm` on system paths, force pushes to protected branches, `git reset --hard`, `git clean -f`, unbounded SQL deletes, `chmod 777`, state-changing `gh`/Jira calls without approval (shared-state gate), and custom `CC_BLOCKED_PATTERNS`.

### Git Hooks

`core/git-hooks/check-forbidden-chars.sh` runs at pre-commit and rejects AI-tell characters in tracked files, with path-prefix excludes.

## Agent Hub-and-Spoke Model

```
                    +---------------------+
                    | project-coordinator |
                    |     (Hub / Opus)    |
                    +----------+----------+
                               |
  +--------+--------+--------+-+------+--------+--------+--------+
  |        |        |        |        |        |        |        |
solution code-std  test   research database security angular  spring-boot
architect reviewer spec.  analyst  spec.    analyst  spec.    spec.
```

The coordinator receives requests and delegates; the code-standards-reviewer is the quality gate after implementation. Agents run least-privilege (a `tools:` allowlist or `disallowedTools` in frontmatter).

| Agent | Model | Responsibility |
|-------|-------|----------------|
| project-coordinator | opus | Orchestration, delegation |
| solution-architect | opus | Architecture, business workflows, ADR feasibility review |
| code-standards-reviewer | sonnet | Code review, standards compliance |
| test-specialist | sonnet | Tests, coverage, QA |
| research-analyst | opus | External research with the Source Authority Model (T1-T5) |
| database-specialist | opus | Query optimization, schema design |
| security-analyst | opus | Offensive security, vulnerability analysis |
| angular-specialist | sonnet | Angular migration and patterns |
| spring-boot-specialist | sonnet | Spring Boot migration and patterns |
| skill-updater | sonnet | Framework synchronization |

Which agents are installed is controlled by `CC_AGENTS`.

### Source Authority Model

Research agents classify every source into tiers T1 (official) to T5 (unverified, discarded by default). Decisions require T1 or T2 backing; the higher tier wins on conflict. See [source-authority-model.md](research/source-authority-model.md). This is the framework's input-side grounding for external facts.

## Skills

Skills are installed to `.claude/skills/<name>/SKILL.md` (other adapters: `.cognitive-core/skills/`). They require YAML frontmatter (`name`, `description`, `allowed-tools`), validated by suite 02. Note that `allowed-tools` is documentation, not enforcement; enforcement lives in hooks.

| Invocation | Behavior | Examples |
|------------|----------|----------|
| Model-invocable | Claude may load the skill when relevant | session-resume, code-review, project-board, acceptance-verification |
| Manual only | `disable-model-invocation: true`; invoked via `/skill-name` | pre-commit, fitness, project-status, smoke-test, workflow-analysis |
| Background knowledge | `user-invocable: false` | security-baseline |

Progressive disclosure: concise `SKILL.md` (under 500 lines), detail in `references/`, deterministic work in scripts.

### Notable Skill Subsystems

| Skill | Subsystem |
|-------|-----------|
| project-board | Provider layer (GitHub Projects, Jira, YouTrack) via `_provider-lib.sh`; approval gate; `pr/pr-guard.sh` PR lifecycle rules; `validate-prompt.sh` prompt linter (stochastic vulnerability check + path grounding) |
| smoke-test | Reference implementation of ability-type decomposition (`scripts/`) |
| fitness | Weighted quality score used by the CI gates |

### Python Helpers

Python is used in adapters (3.10+) and in skill helpers (stdlib only, must run on macOS system Python 3.9). Helpers run with `python3 -I` so modules in the project checkout are never imported.

## Adapters

Adapters implement the contract in `adapters/adapter-interface.yaml`: five functions (`_adapter_install_hook`, `_adapter_install_agent`, `_adapter_install_skill`, `_adapter_generate_settings`, `_adapter_generate_project_readme`), checked by `_adapter_validate`. Shared defaults live in `_adapter-lib.sh` and `adapters/_shared/` (Python utilities, safety rules, MCP server).

| Adapter | Platform | Install dir | Project file |
|---------|----------|-------------|--------------|
| claude | Claude Code | `.claude/` | `CLAUDE.md` |
| aider | Aider (+ Ollama local models) | `.cognitive-core/` | `CONVENTIONS.md` |
| intellij | IntelliJ + DevoxxGenie (MCP server) | `.cognitive-core/` | `DEVOXXGENIE.md` |
| vscode | VS Code (Copilot, Continue.dev, Cline) | `.cognitive-core/` (MCP config in `.vscode/mcp.json`) | `.github/copilot-instructions.md` |

Platforms without native hooks get the safety rules as conventions text; enforcement is weaker there by design.

## Install / Update Lifecycle

### install.sh

1. Validates the target is a git repository and anchors `CC_FRAMEWORK_ROOT`
2. Runs interactive setup if no `cognitive-core.conf` exists
3. Copies `_lib.sh`, the hooks in `CC_HOOKS`, agents, the skills in `CC_SKILLS`, and the language and database pack
4. Generates settings (hook wiring from the template), `CLAUDE.md` scaffold, `AGENTS_README.md`, `.gitattributes`, `.gitignore` fragments
5. Optionally installs CI/CD workflows, Docker, monitoring, and K8s manifests
6. Writes `version.json` with SHA-256 checksums of all installed files

### update.sh

1. Reads `version.json` and compares installed, original, and latest checksums
2. Unmodified files are updated; user-modified files are preserved with a warning; files marked as local overrides are skipped
3. New files inside installed skills are added; `--prune` removes files the framework dropped
4. Switches to `CC_SYNC_BRANCH` (default `chore/cognitive-core-sync`) when `CC_SYNC_ENFORCE` is on, the project has an `origin` remote, and it is not already on main, master, develop, or the sync branch; writes a new manifest

Only paths under `core/hooks`, `core/agents`, and `core/skills` are mapped back to the framework. New shared components must live there, or install and update will not deliver them.

### Plugin Channel

`build-plugin.sh` packages hooks, agents, and skills as a Claude Code plugin in `plugin/`. It is a secondary channel; `install.sh` remains primary ([#331](https://github.com/mindcockpit-ai/cognitive-core/issues/331)).

## Language and Database Packs

Packs are drop-in extensions: `pack.conf` (defaults), `skills/`, path-scoped `rules/`, `compact-rules.md`, and for languages `gitignore` and `gitattributes-lang` fragments plus optional `fitness-checks.sh` and `lint-config.sh` (shared helpers in `language-packs/_common.sh`). When `CC_LANGUAGE` or `CC_DATABASE` is set, install copies the pack's skills and rules.

## CI/CD Pipeline

A 5-gate progressive quality model (see [CICD_GUIDE.md](CICD_GUIDE.md)):

```
Commit --> Gate 1: Lint --> Gate 2: Commit --> Gate 3: Test --> Gate 4: Merge --> Gate 5: Deploy
              60%             80%                85%             90%              95%
```

Each gate runs the fitness check. Project-board automation (closure guard, approval gate, daily reconciliation) runs as GitHub workflows with a GitHub App token. Self-hosted runners are selected by trust level.

## Design Principles

1. **Parsimony** -- the simplest solution that meets requirements; every component justifies its complexity. Security is the exception: defense-in-depth across layers ([paper](research/parsimony-principle.md))
2. **Deterministic over stochastic** -- what must hold is enforced by hooks and scripts, not by instructions
3. **Single config** -- one `cognitive-core.conf` drives everything
4. **No runtime dependencies** -- bash alone works; jq, ripgrep, python3 are optional or stdlib-only
5. **Safe updates** -- the checksum-based updater never destroys user work
6. **Backwards compatible** -- existing installations keep working after every update
7. **Language and platform agnostic** -- packs add language specifics, adapters add platform specifics
8. **Security by default** -- dangerous commands blocked, credentials externalized, graduated responses

## Future Components

### Strategic Focus: Deterministic Assurance

The next releases concentrate on one goal: what the assistant reads, references, and does is verified by deterministic checks instead of trusted instructions. Three streams serve it:

| Stream | Goal | Components |
|--------|------|------------|
| **Grounding** | Every reference (path, symbol, agent, table, source) resolves to something real | L0 source authority (exists), L2 code grounding engine, reply grounding hook, evidence citations in acceptance verification |
| **Ontology** | Domain terms are defined once and used canonically | JSON ontology file per project (stdlib parser), SKOS export, alias/deprecated/anchor drift checks |
| **Deterministic assurance** | Rules that must hold are enforced by scripts, hooks, and CI, not by prose | Stochastic vulnerability check (L1) for prompts, issues, skills, and agents; PR lifecycle guard; approval gate; S-to-D migration of skill steps |

Status: **In progress** (epic open, work started), **Proposed** (ADR under review), **Planned** (issue accepted), **Deprioritized** (kept in backlog, not scheduled), **Research** (not committed).

### Proposed

| Component | Stream | Tracking |
|-----------|--------|----------|
| Grounding and ontology framework: shared engine as a non-invocable skill, four layers (L0 source authority, L1 stochastic vulnerability, L2 code grounding, L3 ontology), JSON ontology with SKOS export, versioned machine output, optional SARIF | Grounding, Ontology | [ADR-001](architecture/decisions/ADR-001-grounding-ontology-framework.md) |
| Self-check suite: L1 over the framework's own skills and agents | Deterministic assurance | ADR-001 |

### In Progress

| Component | Stream | Tracking |
|-----------|--------|----------|
| PR lifecycle guard (`pr-guard.sh`, `gh pr` guards in validate-bash, CI enforcement) | Deterministic assurance | [#391](https://github.com/mindcockpit-ai/cognitive-core/issues/391) |
| Approval gate end to end, non-PR work reaches To Be Tested | Deterministic assurance | [#367](https://github.com/mindcockpit-ai/cognitive-core/issues/367) |
| Drift-free installs across adapters, plugin as secondary channel | Platform | [#331](https://github.com/mindcockpit-ai/cognitive-core/issues/331) |
| Settings follow `CC_HOOKS`, merge on re-install, MCP opt-in | Platform | [#345](https://github.com/mindcockpit-ai/cognitive-core/issues/345) |
| Test suite hardening (assertion quality, env isolation) | Deterministic assurance | [#275](https://github.com/mindcockpit-ai/cognitive-core/issues/275) |

### Planned

| Component | Stream | Tracking |
|-----------|--------|----------|
| End-to-end integration tests of installed projects | Deterministic assurance | [#93](https://github.com/mindcockpit-ai/cognitive-core/issues/93) |
| Instruction-file consistency check (CLAUDE.md, rules, skills) | Grounding | [#229](https://github.com/mindcockpit-ai/cognitive-core/issues/229) |
| Worktree guard and `/worktree` skill for parallel sessions | Platform | [#266](https://github.com/mindcockpit-ai/cognitive-core/issues/266) |
| Toxic flow analysis (cross-call data exfiltration) | Security | [#209](https://github.com/mindcockpit-ai/cognitive-core/issues/209) |
| MCP server configuration scan | Security | [#210](https://github.com/mindcockpit-ai/cognitive-core/issues/210) |
| Enterprise pack manifest (bundled custom components) | Platform | [#110](https://github.com/mindcockpit-ai/cognitive-core/issues/110) |
| Further adapters: Eclipse, Cursor, Windsurf, Neovim | Platform | [#82](https://github.com/mindcockpit-ai/cognitive-core/issues/82), [#83](https://github.com/mindcockpit-ai/cognitive-core/issues/83), [#84](https://github.com/mindcockpit-ai/cognitive-core/issues/84), [#85](https://github.com/mindcockpit-ai/cognitive-core/issues/85) |

### Deprioritized

| Component | Tracking |
|-----------|----------|
| EU AI Act compliance (disclosure, provenance trailers, JSON Lines audit log, emergency stop, minimum security level, code of conduct) | [#120](https://github.com/mindcockpit-ai/cognitive-core/issues/120) |
| GDPR-oriented features (PII detection, SIEM export) | [#120](https://github.com/mindcockpit-ai/cognitive-core/issues/120), [#132](https://github.com/mindcockpit-ai/cognitive-core/issues/132) |

Items from these epics that also serve deterministic assurance (for example the emergency stop or a structured audit log of hook decisions) can be pulled forward individually.

### Research

| Topic | Note |
|-------|------|
| Deterministic workflow engine | [#200](https://github.com/mindcockpit-ai/cognitive-core/issues/200); evaluate against the S-to-D script approach first |
| Sampling-based stochastic checks (semantic entropy, self-consistency) | Deferred in ADR-001 until deterministic layers show measurable gaps |
| Agent Teams (parallel teammates, team-guard watchdog, `TeammateIdle`/`TaskCompleted` hooks) | Researched, not implemented; earlier versions of this document described it as existing. Only the `CC_AGENT_TEAMS` setting exists (install.sh, settings template) |
| cognitive-core assistant (authority-weighted RAG) | [#141](https://github.com/mindcockpit-ai/cognitive-core/issues/141), separate product |
