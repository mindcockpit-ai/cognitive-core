# cognitive-core FAQ

Answers to common questions from developers who just installed the framework.

---

<details>
<summary><strong>Getting Started</strong></summary>

### What is cognitive-core?

A portable framework that gives AI coding assistants (Claude Code, Aider, IntelliJ) safety hooks, structured agent teams, and composable skills. Install it into any project — hooks activate on the first session.

### What are the minimum requirements?

- Bash 4+ (macOS ships Bash 3 — use `brew install bash`)
- Git repository (the installer checks for this)
- One supported AI platform: Claude Code, Aider + Ollama, or IntelliJ + DevoxxGenie
- Python 3.10+ (optional, improves JSON parsing in install/update scripts)

### Where do I start after installing?

Open a Claude Code session in your project. Three things happen automatically:
1. `setup-env.sh` verifies hook integrity and prints branch status
2. `session-resume` loads prior context
3. `validate-bash.sh` intercepts every Bash command

Try `/project-status` or `/code-review` to invoke a skill. See `docs/onboarding/learning-roadmap.md` for the full progression.

### How do I verify my installation is working?

Run `rm -rf /` in your Claude session. The hook blocks it with a JSON deny response. If it does not block, your hooks are not loaded — check that `.claude/settings.json` references the hooks correctly.

</details>

<details>
<summary><strong>Installation</strong></summary>

### Install fails with "Not a git repository"

The target directory must be an initialized git repo. Fix: `git init /path/to/your-project` then re-run `install.sh`.

### Install fails with "already installed"

cognitive-core detects an existing `version.json`. Use `--force` to overwrite, or use `update.sh` for safe updates that preserve your customizations.

```bash
./install.sh /path/to/project --force    # full overwrite
./update.sh /path/to/project             # safe incremental update
```

### CRLF line endings break the installer on Windows

Fixed in [#58](https://github.com/mindcockpit-ai/cognitive-core/issues/58). If you cloned on Windows, ensure `git config core.autocrlf false` or re-clone. The installer normalizes backslash paths but cannot fix CRLF in shell scripts.

### Plugin vs. full install — what is the difference?

| Method | What you get |
|--------|-------------|
| `claude --plugin-dir` | Hooks, agents, skills (auto-loaded, no file copy) |
| `./install.sh` | Same + CI/CD pipelines, language packs, `CLAUDE.md`, `cognitive-core.conf` |

Both coexist. If the plugin is detected, `install.sh` skips hook/agent/skill copy to avoid double-firing.

### How do I install for Aider or IntelliJ?

```bash
./install.sh /path/to/project --platform aider
./install.sh /path/to/project --platform intellij
```

Files go into `.cognitive-core/` instead of `.claude/`. The adapter generates platform-specific config (`CONVENTIONS.md` for Aider, `DEVOXXGENIE.md` for IntelliJ).

</details>

<details>
<summary><strong>Configuration</strong></summary>

### Where is the configuration file?

`cognitive-core.conf` in your project root. It is shell syntax, sourced by every hook at runtime. See `cognitive-core.conf.example` in the framework repo for all options.

### How do I change the security level?

Edit `cognitive-core.conf`:

```bash
CC_SECURITY_LEVEL="strict"   # minimal | standard (default) | strict
```

- `minimal` — 8 built-in destructive patterns only
- `standard` — + exfiltration, encoded bypass, pipe-to-shell
- `strict` — + domain allowlisting (only `CC_ALLOWED_DOMAINS` permitted)

### How do I add custom blocked commands?

Add patterns to `CC_BLOCKED_PATTERNS` in `cognitive-core.conf`:

```bash
CC_BLOCKED_PATTERNS="curl.*\|.*sh eval.*unsafe my_dangerous_command"
```

### How do I enable/disable specific hooks, agents, or skills?

Edit the corresponding variables in `cognitive-core.conf`:

```bash
CC_HOOKS="setup-env validate-bash validate-read validate-write post-edit-lint"
CC_AGENTS="coordinator reviewer architect tester"
CC_SKILLS="session-resume code-review fitness pre-commit"
```

Only listed components are active.

### What is `settings.json` and should I edit it?

`.claude/settings.json` configures Claude Code permissions and hook bindings. The installer generates it; after that it is user-managed. `update.sh` never overwrites it.

</details>

<details>
<summary><strong>Skills</strong></summary>

### How do I invoke a skill?

Type the slash command in a Claude Code session: `/code-review`, `/fitness`, `/project-board list`. Skills with `user-invocable: true` in their YAML frontmatter are available.

### Skills appear multiple times in the skill list

Fixed in [#147](https://github.com/mindcockpit-ai/cognitive-core/issues/147). Caused by orphaned `.claude/commands/` stubs. Run `update.sh` to clean them up automatically, or delete `.claude/commands/` manually and restart the session.

### What is the YAML frontmatter in SKILL.md?

Required metadata at the top of every skill definition. Test suite `02-skill-frontmatter.sh` validates it.

```yaml
---
name: my-skill
description: What this skill does.
user-invocable: true
allowed-tools: [Bash, Read, Grep]
---
```

Key fields: `name`, `description`, `user-invocable`, `allowed-tools`. See `core/skills/smoke-test/SKILL.md` for an advanced example with ability registry.

### What are D/S/H ability types?

Complex skills decompose steps by LLM involvement:

| Type | LLM? | CI-testable? | Example |
|------|------|-------------|---------|
| **D** (Deterministic) | No | Yes | `preflight.sh` — check server reachability |
| **S** (Synthetic) | Yes | No | Format results as markdown |
| **D/S** | LLM provides input | Partially | LLM composes issue body, script creates it |
| **H** (Human) | No | No | User approves closure |

D-type abilities are extracted into `scripts/` and validated by test suites. See [#195](https://github.com/mindcockpit-ai/cognitive-core/issues/195).

### How do I create a new skill?

1. Create `core/skills/<name>/SKILL.md` with valid YAML frontmatter
2. Add the skill name to `CC_SKILLS` in `cognitive-core.conf`
3. Run `bash tests/suites/02-skill-frontmatter.sh` to validate
4. Run `./install.sh /tmp/test --force` to test installation

</details>

<details>
<summary><strong>Hooks</strong></summary>

### How do hooks work?

Hooks intercept Claude Code tool calls via JSON on stdin/stdout:

- **PreToolUse**: runs before tool execution. Can **deny** (outputs JSON) or **allow** (silent exit 0).
- **PostToolUse**: runs after execution. Can **warn** but cannot block (the action already happened).
- **SessionStart**: injects context at session start.

All hooks source `core/hooks/_lib.sh` for JSON parsing and deny helpers.

### validate-write warns about a secret but the file was already written

PostToolUse hooks cannot prevent writes — the write has already occurred by the time the hook runs. This is an architectural limitation of Claude Code's hook system. The hook warns you to remove the secret manually.

### validate-fetch keeps asking about the same domain

Known issue [#119](https://github.com/mindcockpit-ai/cognitive-core/issues/119). The "don't ask again" preference does not persist within a session. Workaround: add the domain to `CC_ALLOWED_DOMAINS` in `cognitive-core.conf` or switch to `CC_SECURITY_LEVEL="minimal"`.

### How do I write a custom hook?

Use this template:

```bash
#!/bin/bash
set -euo pipefail
HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${HOOKS_DIR}/_lib.sh"
_cc_load_config

INPUT=$(cat)
TOOL_NAME=$(_cc_json_get "$INPUT" "tool_name")

if [[ "$TOOL_NAME" == "Bash" ]]; then
    COMMAND=$(_cc_json_get "$INPUT" "tool_input.command")
    if [[ "$COMMAND" =~ dangerous_pattern ]]; then
        _cc_json_pretool_deny "Blocked: reason"
        exit 0
    fi
fi
exit 0
```

Key rule: use POSIX ERE for regex (no `\s`, `\b`, `\w`) — macOS compatibility.

### Integrity check reports mismatches at session start

`setup-env.sh` compares installed hook checksums against the framework source directory (not `version.json`). Mismatches mean either you modified a hook (intentional — safe to ignore) or the framework was updated but `update.sh` was not run. Fix: `cd /path/to/cognitive-core && ./update.sh /path/to/your-project`.

</details>

<details>
<summary><strong>Agents</strong></summary>

### How does agent routing work?

The **project-coordinator** (Opus) is the hub. It reads your request, matches keywords, and delegates to the right specialist:

| Keywords | Routes to |
|----------|-----------|
| "design", "architecture" | solution-architect |
| "review code", "standards" | code-standards-reviewer |
| "write tests", "coverage" | test-specialist |
| "research", "evaluate library" | research-analyst |
| "slow query", "database" | database-specialist |
| "pentest", "vulnerability" | security-analyst |

### Why can't the research-analyst write files?

Least-privilege enforcement. Each agent's frontmatter declares `tools` (allowed) and `disallowedTools`. The research-analyst is restricted from Write/Edit because research should not modify project files. The code-standards-reviewer cannot access WebFetch/WebSearch because code review is local.

### How do I add a new agent?

Create `core/agents/<name>.md` with YAML frontmatter:

```yaml
---
name: my-agent
description: When to use this agent.
tools: Bash, Read, Grep
model: sonnet
---
```

Add the agent name to `CC_AGENTS` in `cognitive-core.conf`. Test with `bash tests/suites/07-agent-permissions.sh`.

### An agent seems stuck — what do I do?

Agent health monitoring has configurable timeouts in `cognitive-core.conf`:

```bash
CC_AGENT_TIMEOUT_IMPLEMENT=30   # minutes
CC_AGENT_AUTO_KILL=false        # set true to auto-terminate
```

If stuck, end the agent's task manually or restart the session.

</details>

<details>
<summary><strong>Testing</strong></summary>

### How do I run the tests?

```bash
cd /path/to/cognitive-core
bash tests/run-all.sh              # ANSI output
bash tests/run-all.sh --json       # structured JSON (used by CI and website)
bash tests/suites/03-hook-protocol.sh   # single suite
```

All 20 suites (800+ assertions) must pass before every commit.

### How do I write a new test?

1. Create `tests/suites/NN-my-feature.sh` (next available number)
2. Source `tests/lib/test-helpers.sh`
3. Use `suite_start "NN -- Name"` / assertions / `suite_end`

Key assertion functions: `assert_eq`, `assert_contains`, `assert_file_exists`, `assert_hook_denies`, `assert_hook_allows`.

### ShellCheck suite fails

Suite `01-shellcheck.sh` requires ShellCheck to be installed. If missing, the suite skips gracefully. Install: `brew install shellcheck` (macOS) or `apt install shellcheck` (Linux).

### Can I generate JUnit XML reports?

Yes: `JUNIT_REPORT_DIR=/tmp/junit bash tests/run-all.sh`. Reports are written to the specified directory.

</details>

<details>
<summary><strong>Updating</strong></summary>

### How does update.sh work?

1. Reads `version.json` to identify tracked files
2. Computes SHA256 checksums of installed files vs. framework source
3. Updates files you have **not** modified
4. Preserves files you **have** customized (warns you to review manually)
5. Installs new framework files added since your last install
6. Writes an updated `version.json`

```bash
cd /path/to/cognitive-core && git pull
./update.sh /path/to/your-project
```

### update.sh says "No version.json found"

You need to run `install.sh` first. `update.sh` only works on projects with an existing installation.

### update.sh skipped my files — why?

You modified those files since installation. The updater detects this via checksum comparison and refuses to overwrite your changes. Review manually:

```bash
diff .claude/hooks/validate-bash.sh /path/to/cognitive-core/core/hooks/validate-bash.sh
```

### How do I force-update everything?

Re-run the installer with `--force`: `./install.sh /path/to/project --force`. This overwrites all files including your customizations.

</details>

<details>
<summary><strong>Troubleshooting</strong></summary>

### Nothing happens when I start a Claude session

1. Check `.claude/settings.json` exists and references the hooks
2. Verify hooks are executable: `ls -la .claude/hooks/`
3. Run `chmod +x .claude/hooks/*.sh` if permissions are wrong
4. Ensure `cognitive-core.conf` exists in the project root

See also: `docs/recipes/recipe-no-output.md`

### "python3 not found" warning during install/update

Python 3 is optional but recommended. Without it, the installer falls back to less reliable sed-based JSON parsing. Install Python 3.10+ for best results.

### Hooks work locally but not in CI

CI runners may not have `jq`, `shellcheck`, or the same Bash version. The `_lib.sh` library uses `jq` when available and falls back to `sed`. Ensure your CI image has Bash 4+.

### macOS: regex errors in hooks

Hooks use POSIX ERE (Extended Regular Expressions). GNU extensions like `\s`, `\b`, `\w` break on macOS BSD grep/sed. If you write custom hooks, avoid these. Use `[[:space:]]` instead of `\s`, etc.

### How do I check framework health?

```bash
cd /path/to/cognitive-core
bash tests/run-all.sh
```

Live health dashboard: [multivac42.ai/#health](https://multivac42.ai/#health)

### Where are security events logged?

`.claude/cognitive-core/security.log` in your project directory. Every deny, ask, and fetch audit event is recorded.

### How do I reset cognitive-core completely?

```bash
rm -rf .claude/hooks .claude/agents .claude/skills .claude/cognitive-core
rm -f .claude/settings.json .claude/AGENTS_README.md cognitive-core.conf
# Then re-install
./install.sh /path/to/project
```

</details>

<details>
<summary><strong>Contributing</strong></summary>

### What is the commit format?

```
type(scope): subject
```

Types: `feat`, `fix`, `docs`, `test`, `chore`, `refactor`
Scopes: `hooks`, `agents`, `skills`, `adapters`, `install`, `cicd`, `packs`, `docs`, `security`

No AI/Claude references in commits.

### What must pass before I submit a PR?

1. `bash tests/run-all.sh` — all 20 suites pass
2. `./install.sh /tmp/test-project --force` — install flow works
3. `./update.sh /tmp/test-project` — update flow works
4. ShellCheck clean (if shellcheck is installed)
5. POSIX ERE only in regex (no `\s`, `\b`, `\w`)

### What are the priority contribution areas?

1. **Adapters** — new platforms (Gemini, Mistral, Cursor)
2. **Skills** — domain-specific composable skills
3. **Language packs** — language-specific skills and rules
4. **Testing** — coverage improvements, edge cases

### What license applies to contributions?

FSL-1.1-ALv2 (Functional Source License). You can use, modify, and redistribute for any purpose except offering it as a competing commercial product. After 2 years, each version converts to Apache 2.0.

</details>

---

*Last updated: 2026-03-29. Source material: CLAUDE.md, README.md, CONTRIBUTING.md, docs/SECURITY.md, install.sh, update.sh, GitHub issues.*
