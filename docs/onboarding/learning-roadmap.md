# cognitive-core Learning Roadmap

A progressive guide from first install to framework contributor.

---

## 1. Quick Start (5-10 minutes)

### What is cognitive-core?

A portable framework that gives AI coding assistants (Claude Code, Aider, IntelliJ) production-grade safety hooks, structured agent teams, and composable skills. Install it into any project and get defense-in-depth security, multi-agent coordination, and quality enforcement from the first session.

### Install into a test project

```bash
# Clone the framework
git clone https://github.com/mindcockpit-ai/cognitive-core.git
cd cognitive-core

# Install into a throwaway project (interactive prompts with sane defaults)
./install.sh /tmp/test-project
```

The installer asks for project name, language, database, and which components to enable. Accept the defaults to get started fast.

### See it work

```bash
# Start a Claude Code session in the installed project
cd /tmp/test-project && claude
```

Three things happen automatically on session start:

1. **setup-env.sh** runs, verifies hook integrity, prints your branch status
2. **session-resume** skill loads prior context (if any)
3. Every Bash command you run is intercepted by **validate-bash.sh**

Try triggering a safety hook:

```
> Run: rm -rf /
```

The hook blocks it and returns a JSON deny response. That is cognitive-core working.

### Invoke a skill

Skills are invoked with slash commands inside a Claude Code session:

```
> /project-status
> /code-review
> /fitness
```

### Run the test suite

```bash
cd /path/to/cognitive-core
bash tests/run-all.sh
```

You should see all 20 suites pass with 800+ assertions. This confirms your local clone is healthy.

### Key files to bookmark

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Project rules — read this before any contribution |
| `cognitive-core.conf.example` | All configuration options with comments |
| `core/hooks/_lib.sh` | Shared library sourced by every hook |
| `install.sh` | Interactive installer (the main entry point) |
| `update.sh` | Checksum-based updater that preserves customizations |

---

## 2. Core Concepts

### Architecture layers

```
cognitive-core/
├── core/                    # Framework heart
│   ├── hooks/               # Safety hooks (PreToolUse / PostToolUse / SessionStart)
│   ├── agents/              # Agent definitions (.md with YAML frontmatter)
│   ├── skills/              # Skill definitions (SKILL.md + optional scripts/)
│   ├── utilities/           # Health check, cleanup, secrets management
│   └── templates/           # Rules templates, settings.json scaffold
├── adapters/                # Platform adapters (claude, aider, intellij, vscode)
├── language-packs/          # Per-language skills and rules (10 languages)
├── database-packs/          # Per-database skills and rules (3 databases)
├── cicd/                    # CI/CD pipeline templates and monitoring
├── tests/                   # 20 test suites, 800+ assertions
├── install.sh               # Bootstrapper
└── update.sh                # Safe updater
```

### The three pillars

| Pillar | What it does | Analogy |
|--------|-------------|---------|
| **Hooks** | Intercept every tool call. Block danger, scan for secrets, auto-lint. | Immune system |
| **Agents** | Specialized AI roles (coordinator, reviewer, tester, etc.) with least-privilege tool access. | Specialized organs |
| **Skills** | Composable task definitions invoked by slash commands. Config-driven, progressively disclosed. | Learned abilities |

### Configuration: one file rules them all

Everything is configured in `cognitive-core.conf` (shell syntax, sourced at runtime):

```bash
CC_PROJECT_NAME="my-project"
CC_LANGUAGE="python"              # perl|python|node|java|go|rust|csharp|react|angular|spring-boot
CC_DATABASE="postgresql"          # oracle|postgresql|mysql|sqlite|none
CC_SECURITY_LEVEL="standard"     # minimal|standard|strict
CC_AGENTS="coordinator reviewer architect tester researcher"
CC_SKILLS="session-resume code-review fitness pre-commit"
CC_HOOKS="setup-env validate-bash validate-read validate-write validate-fetch post-edit-lint compact-reminder"
```

Hooks load this file via `_cc_load_config` from `core/hooks/_lib.sh`.

### Install vs. update flow

| Step | `install.sh` | `update.sh` |
|------|-------------|-------------|
| 1 | Interactive prompts for project config | Reads existing `version.json` |
| 2 | Copies hooks, agents, skills to `.claude/` | Computes SHA256 checksums of installed files |
| 3 | Generates `cognitive-core.conf`, `settings.json`, `CLAUDE.md` | Updates unmodified files, preserves your customizations |
| 4 | Writes `version.json` manifest with checksums | Writes updated `version.json` |

Key invariant: **update never overwrites files you have customized**. It warns you to review them manually.

### The parsimony principle

Every design decision must justify its complexity. Essential complexity (inherent to the problem) is respected. Accidental complexity (artifacts of the solution) is eliminated. Exception: security uses defense-in-depth by design — parsimony applies within each security layer, never across them.

---

## 3. Skills Deep-Dive

### Location

```
core/skills/
├── code-review/
│   ├── SKILL.md              # Skill definition (required)
│   └── references/           # Supporting docs (optional)
├── smoke-test/
│   ├── SKILL.md
│   └── scripts/              # D-type deterministic scripts
│       ├── preflight.sh
│       ├── execute-test.sh
│       ├── check-issues.sh
│       └── create-issue.sh
└── ...
```

Path: `core/skills/<skill-name>/SKILL.md`

### YAML frontmatter (required)

Every `SKILL.md` starts with YAML frontmatter. Test suite `02-skill-frontmatter.sh` validates this across all skills.

```yaml
---
name: smoke-test
description: Happy path smoke testing with Playwright.
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Grep, Glob
argument-hint: "run | report | fix"
featured: true
featured_description: Smoke test all endpoints and auto-create GitHub issues.
supported-languages: [node, react, angular]
---
```

| Field | Required | Purpose |
|-------|----------|---------|
| `name` | yes | Unique identifier, matches directory name |
| `description` | yes | One-line purpose |
| `user-invocable` | yes | Can the user invoke this with a slash command? |
| `allowed-tools` | yes | Least-privilege tool list for this skill |
| `disable-model-invocation` | no | If `true`, only the user (not the LLM) can invoke it |
| `argument-hint` | no | Shows usage hint in help output |
| `featured` | no | Surfaces on the website and in health dashboard |
| `supported-languages` | no | Language pack filter |

### Ability registry (advanced skills)

Complex skills decompose their workflow into typed abilities:

| Type | Code | Meaning | Example |
|------|------|---------|---------|
| Deterministic | **D** | A script that runs without LLM involvement | `preflight.sh` — checks if server is reachable |
| Synthetic (LLM) | **S** | Pure LLM generation | Formatting a markdown table from data |
| Deterministic/Synthetic | **D/S** | LLM provides input, script executes | LLM composes issue title, `create-issue.sh` creates it |
| Synthetic/Deterministic | **S/D** | Script provides data, LLM interprets | Script lists open issues, LLM cross-references results |
| Human | **H** | Requires human decision | User decides which resolved issues to close |

See `core/skills/smoke-test/SKILL.md` for a complete ability registry example.

### Skill body structure

After the frontmatter, the SKILL.md body contains:

1. **Arguments** — what `$ARGUMENTS` subcommands are supported
2. **Configuration** — which `CC_*` variables drive behavior
3. **Workflow** — step-by-step instructions per subcommand
4. **Error handling** — what to do when things go wrong

The body is natural language instructions that Claude reads and follows. It is not executed code — it is a prompt that tells the agent how to orchestrate the skill's workflow.

---

## 4. Hooks Deep-Dive

### The JSON protocol

All hooks communicate via JSON on stdin/stdout. The protocol is defined in `core/hooks/_lib.sh`.

**Input** (stdin from Claude Code):
```json
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "rm -rf /"
  }
}
```

**Output** (stdout — deny):
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Blocked: deletion of system-critical path"
  }
}
```

**Output** (allow): silent `exit 0` — no stdout.

### Hook events

| Event | When | Can block? | Example hooks |
|-------|------|-----------|---------------|
| `SessionStart` | Session begins | No (injects context) | `setup-env.sh` |
| `PreToolUse` | Before tool executes | Yes (deny) | `validate-bash.sh`, `validate-read.sh`, `validate-fetch.sh` |
| `PostToolUse` | After tool executes | No (warn only) | `validate-write.sh`, `post-edit-lint.sh` |
| `Notification` | On context compaction | No (re-injects rules) | `compact-reminder.sh` |

### Writing a hook: the template

```bash
#!/bin/bash
set -euo pipefail

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${HOOKS_DIR}/_lib.sh"
_cc_load_config

# Read JSON from stdin
INPUT=$(cat)
TOOL_NAME=$(_cc_json_get "$INPUT" "tool_name")

# Your validation logic
if [[ "$TOOL_NAME" == "Bash" ]]; then
    COMMAND=$(_cc_json_get "$INPUT" "tool_input.command")
    if [[ "$COMMAND" =~ dangerous_pattern ]]; then
        _cc_json_pretool_deny "Blocked: reason"
        exit 0
    fi
fi

# Silent exit 0 = allow
exit 0
```

### Key `_lib.sh` helpers

| Function | Purpose |
|----------|---------|
| `_cc_load_config` | Source `cognitive-core.conf` (project root > `.claude/` > user defaults) |
| `_cc_json_get "$json" "field.subfield"` | Extract a value from JSON (uses jq if available, fallback to sed) |
| `_cc_json_pretool_deny "reason"` | Output a deny JSON response |
| `_cc_json_pretool_deny_structured "reason" "category" "retryable" ["suggestion"]` | Deny with error classification |
| `_cc_json_session_context "text"` | Inject additional context at session start |
| `_cc_rg [flags] "pattern" [path]` | Portable grep (ripgrep with grep fallback) |
| `_cc_compute_sha256 "file"` | Cross-platform SHA256 (shasum or sha256sum) |

### Security levels

Set `CC_SECURITY_LEVEL` in `cognitive-core.conf`:

| Level | Scope |
|-------|-------|
| `minimal` | 8 built-in destructive patterns only (`rm -rf /`, `git push --force main`, etc.) |
| `standard` (default) | + exfiltration (`curl -d @file`), encoded bypass (`base64 -d \| sh`), pipe-to-shell (`curl \| sh`) |
| `strict` | + domain allowlisting — only `CC_ALLOWED_DOMAINS` permitted for web access |

### Graduated response model

Inspired by Metasploit:

1. **Allow** — safe, silent pass
2. **Ask** — suspicious, escalate to human
3. **Deny** — blocked with JSON explanation
4. **Log** — all security events to `.claude/cognitive-core/security.log`

Full security documentation: `docs/SECURITY.md`

---

## 5. Agents Deep-Dive

### Hub-and-spoke model

The **project-coordinator** (Opus) is the hub. It analyzes requests, routes to specialists, and synthesizes results.

```
                    USER
                      |
              project-coordinator (Hub, Opus)
             /     |      |      \       \
   solution-  code-    test-  research- database-
   architect  reviewer spec   analyst   specialist
   (Opus)     (Sonnet) (Son.) (Opus)   (Opus)
```

### Agent frontmatter

Path: `core/agents/<agent-name>.md`

```yaml
---
name: project-coordinator
description: Hub orchestrator that delegates to specialist agents.
tools: Task, Bash, Glob, Grep, LS, Read, Edit, Write, WebFetch, TodoWrite, WebSearch
model: opus
featured: true
featured_description: Hub orchestrator that delegates to specialist agents.
---
```

| Field | Required | Purpose |
|-------|----------|---------|
| `name` | yes | Agent identifier |
| `description` | yes | When to use this agent (Claude reads this for routing) |
| `tools` | yes | Allowed tools — enforces least-privilege |
| `model` | yes | `opus` for deep analysis, `sonnet` for fast execution |
| `featured` | no | Shown on website health dashboard |

### Least-privilege tool restrictions

| Agent | Restricted from | Rationale |
|-------|----------------|-----------|
| code-standards-reviewer | WebFetch, WebSearch | Code review needs no external access |
| research-analyst | Write, Edit | Research should not modify project files |
| skill-updater | WebFetch, WebSearch | Framework sync is local only |

### Routing keywords

| Keywords in request | Routes to |
|--------------------|-----------|
| "design", "architecture", "workflow" | solution-architect |
| "review code", "check standards", "refactor" | code-standards-reviewer |
| "write tests", "coverage", "QA" | test-specialist |
| "research", "evaluate library", "best practice" | research-analyst |
| "slow query", "database", "index", "bulk import" | database-specialist |
| "pentest", "CTF", "vulnerability" | security-analyst |

### Mandatory quality gate

Every code change must pass through the code-standards-reviewer before completion. This is enforced by the project-coordinator's delegation protocol.

### Agent health monitoring

Background agents are monitored for stuck behavior. Configuration in `cognitive-core.conf`:

```bash
CC_AGENT_TIMEOUT_EXPLORE=5      # minutes
CC_AGENT_TIMEOUT_RESEARCH=15
CC_AGENT_TIMEOUT_PLAN=10
CC_AGENT_TIMEOUT_IMPLEMENT=30
CC_AGENT_AUTO_KILL=false         # set true to auto-terminate stuck agents
```

Full agent documentation: `.claude/AGENTS_README.md`

---

## 6. Testing

### Test framework

Path: `tests/lib/test-helpers.sh`

The framework provides:

| Function | Purpose |
|----------|---------|
| `suite_start "NN -- Name"` | Begin a named test suite |
| `suite_end` | Print results, exit 1 if any failures |
| `assert_eq "label" "expected" "actual"` | Exact string match |
| `assert_contains "label" "haystack" "needle"` | Substring match |
| `assert_file_exists "label" "path"` | File existence check |
| `assert_hook_denies "label" "$hook" "$json"` | Hook outputs deny JSON |
| `assert_hook_allows "label" "$hook" "$json"` | Hook exits silently |
| `mock_bash_json "command"` | Create mock PreToolUse stdin JSON |
| `_skip "label"` | Mark a test as skipped |

### Test suite anatomy

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "03 — Hook Protocol (JSON I/O)"

# --- Your assertions ---
assert_hook_denies \
    "validate-bash: rm -rf / -> deny" \
    "${ROOT_DIR}/core/hooks/validate-bash.sh" \
    "$(mock_bash_json "rm -rf /")"

assert_hook_allows \
    "validate-bash: ls -la -> allow" \
    "${ROOT_DIR}/core/hooks/validate-bash.sh" \
    "$(mock_bash_json "ls -la")"

suite_end
```

### Running tests

```bash
# Run all suites (ANSI output)
bash tests/run-all.sh

# Run all suites (structured JSON output — used by CI and the website health dashboard)
bash tests/run-all.sh --json

# Run a single suite
bash tests/suites/03-hook-protocol.sh

# Generate JUnit XML reports
JUNIT_REPORT_DIR=/tmp/junit bash tests/run-all.sh
```

### Current test suites

| Suite | File | What it validates |
|-------|------|-------------------|
| 01 | `01-shellcheck.sh` | All `.sh` files pass ShellCheck |
| 02 | `02-skill-frontmatter.sh` | Every SKILL.md has valid YAML frontmatter |
| 03 | `03-hook-protocol.sh` | Hooks produce valid JSON deny/allow responses |
| 04 | `04-install-dryrun.sh` | `install.sh` dry-run produces expected output |
| 05 | `05-update-flow.sh` | `update.sh` checksum logic works correctly |
| 06 | `06-security-hooks.sh` | Security patterns are blocked at all levels |
| 07 | `07-agent-permissions.sh` | Agent tool restrictions are correctly declared |
| 08 | `08-workspace-monitor.sh` | Workspace monitoring skill validation |
| 09 | `09-adapter-interface.sh` | All adapters implement the required contract |
| 10 | `10-aider-adapter.sh` | Aider-specific adapter behavior |
| 11 | `11-intellij-adapter.sh` | IntelliJ adapter behavior |
| 12 | `12-mcp-server.sh` | MCP server structure validation |
| 13 | `13-plugin-structure.sh` | Plugin structure validation |
| 14 | `14-project-board-providers.sh` | Project board multi-provider support |
| 15 | `15-gitignore-policy.sh` | Gitignore template merging |
| 16 | `16-recursive-epic-structure.sh` | Recursive epic verification logic |
| 17 | `17-agent-health.sh` | Agent timeout and health monitoring |
| 18 | `18-vscode-adapter.sh` | VS Code adapter behavior |
| 19 | `19-validate-prompt.sh` | Prompt validation hook |
| 20 | `20-smoke-test-abilities.sh` | Smoke test deterministic abilities |

### Writing a new test suite

1. Create `tests/suites/NN-my-feature.sh` (next available number)
2. Source `test-helpers.sh`
3. Use `suite_start` / assertions / `suite_end`
4. Run `bash tests/run-all.sh` to verify it integrates cleanly

Rule: **all 20 suites must pass before every commit** (see `CLAUDE.md` rule 6).

---

## 7. Contributing

### Branch conventions

```bash
git checkout -b feat/my-feature     # new feature
git checkout -b fix/broken-hook     # bug fix
git checkout -b docs/skill-guide    # documentation
```

### Commit format

```
type(scope): subject

# Types: feat, fix, docs, style, refactor, test, chore
# Scopes: hooks, agents, skills, adapters, install, cicd, packs, docs, security
```

Examples:

```
feat(skills): add terraform-patterns cellular skill
fix(hooks): handle edge case in validate-bash POSIX regex
docs(onboarding): add learning roadmap
test(adapters): add VS Code adapter validation suite
chore(install): bump version to 1.1.0
```

**No AI/Claude references in commits.** This is a professional codebase.

### PR workflow

1. Fork the repository
2. Create a feature branch
3. Implement changes following the standards in `CLAUDE.md`
4. Run `bash tests/run-all.sh` — all suites must pass
5. Test the install flow: `./install.sh /tmp/test-project --force`
6. Test the update flow: `./update.sh /tmp/test-project`
7. Submit PR with a clear description

### Shell scripting standards

- `set -euo pipefail` at the top of every script
- POSIX ERE for regex (no `\s`, `\b`, `\w` — these break on macOS)
- ShellCheck clean (suite 01 validates when shellcheck is installed)
- Source `_lib.sh` for JSON helpers — do not hand-roll JSON output
- Cross-platform: must work on both macOS and Linux

### Priority contribution areas

1. **Adapters** — new platform adapters (Gemini, Mistral, Cursor, VS Code)
2. **Skills** — domain-specific skills
3. **Language packs** — add language-specific skills and rules
4. **Testing** — increase coverage, add edge cases

Full guidelines: `CONTRIBUTING.md`

---

## 8. Advanced Topics

### Ability-type decomposition (D/S/H)

Skills that orchestrate multi-step workflows classify each step by how much LLM involvement it requires. This is the **ability registry** pattern introduced in issue #195.

| Type | Symbol | LLM involved? | Testable in CI? | Example |
|------|--------|---------------|-----------------|---------|
| Deterministic | **D** | No | Yes (bash tests) | `preflight.sh` — check if server is reachable |
| Synthetic | **S** | Yes (generation) | No (non-deterministic) | Format test results as markdown |
| D/S hybrid | **D/S** | LLM provides input | Partially (script is testable) | LLM composes issue body, script creates it |
| S/D hybrid | **S/D** | LLM interprets output | Partially (script is testable) | Script fetches data, LLM analyzes it |
| Human | **H** | No (user decides) | No | User approves which issues to close |

The key benefit: **D-type abilities can be extracted into standalone scripts** and validated in test suites. Suite `20-smoke-test-abilities.sh` tests the D-type abilities of the smoke-test skill.

### Language packs

Path: `language-packs/<language>/`

Each language pack provides:

```
language-packs/python/
├── skills/
│   ├── python-patterns/SKILL.md       # Language-specific coding patterns
│   ├── python-ddd/SKILL.md            # DDD patterns for Python
│   └── python-messaging/SKILL.md      # Messaging patterns
├── rules/
│   └── python-conventions.md           # Path-scoped rules (activate on *.py edits)
├── gitignore.fragment                  # Merged into project .gitignore on install
└── pack.conf                           # Language defaults (linter, formatter, etc.)
```

To add a new language pack:

1. Create `language-packs/<language>/skills/<skill-name>/SKILL.md`
2. Add language defaults to the `install.sh` case statement
3. Test: `./install.sh /tmp/test --force` with `CC_LANGUAGE=<language>`

### Adapter interface

Path: `adapters/adapter-interface.yaml`

Every adapter must implement 5 functions and set 2 variables:

| Required function | Purpose |
|-------------------|---------|
| `_adapter_install_hook` | Copy a hook file into the project |
| `_adapter_install_agent` | Copy an agent definition into the project |
| `_adapter_install_skill` | Copy a skill directory into the project |
| `_adapter_generate_settings` | Generate platform-specific settings file |
| `_adapter_generate_project_readme` | Generate the project instruction file (CLAUDE.md, CONVENTIONS.md, etc.) |

| Required variable | Purpose |
|-------------------|---------|
| `_ADAPTER_NAME` | Human-readable name (e.g., `claude-code`, `aider`) |
| `_ADAPTER_INSTALL_DIR` | Where components go (e.g., `.claude`, `.cognitive-core`) |

The `_adapter-lib.sh` validates contract compliance at install time. Suite `09-adapter-interface.sh` tests all adapters.

### Platform capability matrix

Not all platforms support all features:

| Capability | Claude Code | Aider | IntelliJ | VS Code |
|-----------|-------------|-------|----------|---------|
| PreToolUse hooks | Native | Convention-based | Convention + MCP | Convention + MCP |
| PostToolUse hooks | Native | Auto-lint config | MCP tool | MCP tool |
| Agent delegation | Native | Read-only context | Read-only + MCP | Read-only + MCP |
| Skill invocation | Native (slash commands) | Not supported | Not supported | Not supported |
| Settings file | `.claude/settings.json` | `.aider.conf.yml` | `.devoxxgenie.yaml` | `.vscode/mcp.json` |
| Project readme | `CLAUDE.md` | `CONVENTIONS.md` | `DEVOXXGENIE.md` | `.github/copilot-instructions.md` |

### CI/CD evolutionary pipeline

```
Commit --> Lint Gate (60%) --> Test Gate (85%) --> Merge Gate (90%) --> Deploy Gate (95%)
               |                    |                   |                    |
          fitness-check.sh    fitness-check.sh    fitness-check.sh    fitness-check.sh
               |                    |                   |                    |
          push-metrics.sh -------> Prometheus -------> Grafana Dashboards
```

Fitness gates are configurable per project. Thresholds increase as code moves toward production — natural selection applied to software delivery.

### Secrets management

Three-layer architecture:

```
secrets-setup (skill)     # Scans code, generates .env.tpl, patches CI
        |
secrets-store (CLI)       # Persists secrets in macOS Keychain or 1Password
        |
secrets-run (wrapper)     # Resolves op:// references at runtime
        |
    application           # Reads secrets from environment variables
```

Both backends use the same `op://Vault/Item/field` reference format. See `docs/SECURITY.md` for the full secrets management guide.

---

## Appendix: File Reference

| What you want to understand | Read this file |
|-----------------------------|---------------|
| Project rules and architecture | `CLAUDE.md` |
| Security model and hook coverage | `docs/SECURITY.md` |
| Agent team and routing | `.claude/AGENTS_README.md` |
| Hook JSON protocol and helpers | `core/hooks/_lib.sh` |
| Skill frontmatter spec | Any `core/skills/*/SKILL.md` (e.g., `smoke-test`) |
| Adapter contract | `adapters/adapter-interface.yaml` |
| Test framework | `tests/lib/test-helpers.sh` |
| Test runner | `tests/run-all.sh` |
| Configuration options | `cognitive-core.conf.example` |
| Contribution guidelines | `CONTRIBUTING.md` |
| Parsimony principle | `README.md` (Philosophy section) |
