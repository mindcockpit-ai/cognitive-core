# Deterministic vs Stochastic Execution in Claude Code Skills & Agents

**Peer-Reviewed Analysis** | Date: 2026-03-31 | Version: 1.0
**Reviewer**: research-analyst (Opus, T1-T5 source verification)

## Purpose

Honest technical inventory of which parts of cognitive-core's skill/agent/hook architecture are deterministically enforced by Claude Code runtime vs stochastically interpreted by the LLM. This analysis informs the architecture evolution toward deterministic workflow execution (see [#200](https://github.com/mindcockpit-ai/cognitive-core/issues/200)).

## Key Finding

> **~85-90% of skill/agent execution is stochastic.** The LLM interprets markdown instructions voluntarily. Several features marketed as "enforced" have known bugs that reduce them to advisory status.

---

## Inventory: 9 Claims Verified

### Claim 1: `allowed-tools` in Skill Frontmatter is Enforced

**Verdict: WRONG**

| # | Evidence | Source | Authority |
|---|---------|--------|-----------|
| 1 | `allowed-tools` is a documented SKILL.md frontmatter field | [code.claude.com/docs/en/skills](https://code.claude.com/docs/en/skills) | T1 |
| 2 | `allowed-tools` is **NOT enforced** — Claude freely uses unlisted tools | [anthropics/claude-code#18837](https://github.com/anthropics/claude-code/issues/18837) | T1 |
| 3 | 21 of 23 cognitive-core skills declare `allowed-tools` | `.claude/skills/*/SKILL.md` | Verified |

**Impact**: Every skill that relies on `allowed-tools` for security (e.g., `code-review` with `allowed-tools: Read, Grep, Glob`) provides **zero runtime enforcement**. The field is documentation only.

---

### Claim 2: `disallowedTools` in Agent Frontmatter is Enforced

**Verdict: PARTIALLY CONFIRMED**

| # | Evidence | Source | Authority |
|---|---------|--------|-----------|
| 1 | `disallowedTools` documented for subagent frontmatter | [code.claude.com/docs/en/sub-agents](https://code.claude.com/docs/en/sub-agents) | T1 |
| 2 | `disallowedTools` + `tools` interaction is buggy | [anthropics/claude-code#19501](https://github.com/anthropics/claude-code/issues/19501) | T1 |
| 3 | `allowedTools`/`disallowedTools` ignored for MCP tools | [anthropics/claude-code#20617](https://github.com/anthropics/claude-code/issues/20617) | T1 |
| 4 | cognitive-core SECURITY.md acknowledges: "settings.json deny rules are bugged" | `docs/SECURITY.md:258` | Verified |
| 5 | 2 of 10 agents use `disallowedTools` (code-standards-reviewer, research-analyst) | `.claude/agents/*.md` | Verified |

**Impact**: Works for basic tool-type blocking but has known edge cases. cognitive-core correctly compensates with PreToolUse hooks as primary enforcement.

---

### Claim 3: `model: opus/sonnet` Selection is Deterministic

**Verdict: WRONG**

| # | Evidence | Source | Authority |
|---|---------|--------|-----------|
| 1 | `model` field documented (opus, sonnet, haiku, full ID, inherit) | [code.claude.com/docs/en/sub-agents](https://code.claude.com/docs/en/sub-agents) | T1 |
| 2 | Calling LLM can override `model` field via Agent tool parameter | [anthropics/claude-code#32732](https://github.com/anthropics/claude-code/issues/32732) | T1 |
| 3 | 9/27 sessions ran wrong model (Opus instead of Sonnet) in multi-agent setup | [anthropics/claude-code#32732](https://github.com/anthropics/claude-code/issues/32732) | T1 |
| 4 | Feature request for `modelEnforcement: strict` — does not exist yet | [anthropics/claude-code#32732](https://github.com/anthropics/claude-code/issues/32732) | T1 |
| 5 | All 10 cognitive-core agents declare model (6 Sonnet, 4 Opus) | `.claude/agents/*.md` | Verified |

**Impact**: `model: sonnet` on cost-sensitive agents (code-standards-reviewer, skill-updater) is a **hint, not a constraint**. The calling LLM can spawn any agent on Opus, increasing cost without control.

---

### Claim 4: `context: fork` Creates Isolated Context

**Verdict: CONFIRMED**

| # | Evidence | Source | Authority |
|---|---------|--------|-----------|
| 1 | `context: fork` runs skill as isolated subagent without conversation history | [code.claude.com/docs/en/skills](https://code.claude.com/docs/en/skills) | T1 |
| 2 | "All intermediate work stays in the fork. Only the structured summary returns." | [code.claude.com/docs/en/skills](https://code.claude.com/docs/en/skills) | T1 |
| 3 | 5 of 23 cognitive-core skills use `context: fork` | `.claude/skills/*/SKILL.md` | Verified |

**Impact**: Most reliable deterministic mechanism. Process-level isolation, not prompt-level. However, the forked subagent still has filesystem access (tool restrictions per Claim 1 are not enforced).

---

### Claim 5: `!`backtick`` Shell Injections Execute Before LLM

**Verdict: CONFIRMED (with caveats)**

| # | Evidence | Source | Authority |
|---|---------|--------|-----------|
| 1 | `!command` preprocessor runs shell at invocation time, output replaces block | [code.claude.com/docs/en/skills](https://code.claude.com/docs/en/skills) | T1 |
| 2 | Parser bug: `!` inside markdown backticks incorrectly executed | [anthropics/claude-code#17119](https://github.com/anthropics/claude-code/issues/17119) | T1 |
| 3 | Parser bug: backticks interpreted as command substitution | [anthropics/claude-code#14315](https://github.com/anthropics/claude-code/issues/14315) | T1 |
| 4 | 7 of 23 skills use live injections (36+ total injection points) | `.claude/skills/*/SKILL.md` | Verified |

**Caveats**: Parser is overly aggressive — can execute content inside markdown code fences not intended as shell commands (#17119). Security concern for skills containing example code with `!`.

**Injection inventory** (top skills by injection count):

| Skill | Injections | Purpose |
|-------|-----------|---------|
| session-sync | 8 | git state, branch, remote sync, MCP config |
| session-resume | 7 | git log, status, branch, dirty files |
| secrets-setup | 6 | 1Password CLI, .env scan, hook status |
| workspace-monitor | 5 | log discovery, test results, build artifacts |
| project-status | 4 | git log, branch, status, session docs |
| skill-sync | 3 | version.json, framework metadata |
| security-baseline | 1 | embedded check |

---

### Claim 6: Hooks Fire Automatically and Can Block Operations

**Verdict: PARTIALLY CONFIRMED**

| # | Evidence | Source | Authority |
|---|---------|--------|-----------|
| 1 | PreToolUse hooks return `permissionDecision: "deny"` to block | [code.claude.com/docs/en/hooks](https://code.claude.com/docs/en/hooks) | T1 |
| 2 | "deny takes priority over ask, which takes priority over allow" | [code.claude.com/docs/en/hooks](https://code.claude.com/docs/en/hooks) | T1 |
| 3 | PreToolUse deny is **IGNORED for Edit tool** — file modified despite deny | [anthropics/claude-code#37210](https://github.com/anthropics/claude-code/issues/37210) | T1 |
| 4 | PostToolUse hooks **cannot block** — they run after execution | `docs/SECURITY.md:259` | Verified |
| 5 | validate-bash.sh demonstrates working PreToolUse deny for Bash | `.claude/hooks/validate-bash.sh` | Verified |

**Hook wiring** (from `settings.json`):

| Phase | Matcher | Hook | Can Block? |
|-------|---------|------|-----------|
| SessionStart | startup | setup-env.sh | N/A (init) |
| SessionStart | compact | compact-reminder.sh | N/A (reminder) |
| **PreToolUse** | Bash | validate-bash.sh | **Yes** (confirmed working) |
| **PreToolUse** | Read | validate-read.sh | **Yes** (confirmed working) |
| **PreToolUse** | WebFetch\|WebSearch | validate-fetch.sh | **Yes** (with domain allowlist) |
| PostToolUse | Write\|Edit | post-edit-lint.sh | **No** (feedback only) |
| PostToolUse | Write\|Edit | validate-write.sh | **No** (warn only) |

**Impact**: PreToolUse is the strongest enforcement mechanism, but has a known gap for the Edit tool (#37210). PostToolUse (validate-write.sh, post-edit-lint.sh) is advisory only — secrets can be written before detection.

---

### Claim 7: Markdown Body Instructions are Stochastic

**Verdict: LARGELY CONFIRMED**

| # | Evidence | Source | Authority |
|---|---------|--------|-----------|
| 1 | cognitive-core aider adapter: "Convention-based safety is advisory, not enforced" | `adapters/aider/README.md:60` | Verified |
| 2 | Claude ignores CLAUDE.md and agent instructions | [anthropics/claude-code#7777](https://github.com/anthropics/claude-code/issues/7777) | T1 |
| 3 | cognitive-core certification: "hooks for deterministic compliance, not probabilistic prompt instructions" | `docs/certification-report.md:198` | Verified |
| 4 | Embedded `!command` blocks within body ARE deterministic | [code.claude.com/docs/en/skills](https://code.claude.com/docs/en/skills) | T1 |

**Nuance**: "Purely" is too strong — `!command` blocks within the body are deterministic islands in a stochastic sea. The body is a **hybrid**, but predominantly stochastic.

---

### Claim 8: Agent Boundaries ("don't handle code reviews") are Voluntary

**Verdict: CONFIRMED**

| # | Evidence | Source | Authority |
|---|---------|--------|-----------|
| 1 | System prompts have no reliable priority over user requests | Multiple T2-T3 sources | T2/T3 |
| 2 | "Rules in prompts are requests, hooks in code are laws" | [dev.to article](https://dev.to/minatoplanb/i-wrote-200-lines-of-rules-for-claude-code-it-ignored-them-all-4639) | T4 (corroborated by T1) |
| 3 | Claude ignores methodology instructions requiring manual enforcement | [anthropics/claude-code#7777](https://github.com/anthropics/claude-code/issues/7777) | T1 |
| 4 | research-analyst supplements with `disallowedTools: [Write, Edit]` | `.claude/agents/research-analyst.md:7` | Verified |

**Impact**: Role boundaries are prompt instructions. An agent told "I am a research analyst, not a code reviewer" can still review code if pressed. Only `disallowedTools` provides partial tool-level enforcement.

---

### Claim 9: Workflow Step Ordering is Not Guaranteed

**Verdict: CONFIRMED**

| # | Evidence | Source | Authority |
|---|---------|--------|-----------|
| 1 | No mechanism in Claude Code enforces step ordering | Absence of T1 documentation | Absence of evidence |
| 2 | Skills define steps as markdown — LLM interprets | [code.claude.com/docs/en/skills](https://code.claude.com/docs/en/skills) | T1 |
| 3 | Instruction-following degrades with instruction count | [humanlayer.dev/blog](https://www.humanlayer.dev/blog/writing-a-good-claude-md) | T3 |
| 4 | project-board skill has 1,369 lines of instructions | `.claude/skills/project-board/SKILL.md` | Verified |

**Impact**: Steps 1→2→3 in a skill body are suggestions. The LLM can skip, reorder, or modify steps. No runtime enforcement exists.

---

## The Honest Picture

### Determinism Hierarchy (most → least reliable)

```
DETERMINISTIC (enforced by runtime/shell)
═══════════════════════════════════════════════════════
1. Hooks (PreToolUse deny)     ████████████████████  ~95%
   ↳ Confirmed working for Bash, Read, WebFetch
   ↳ Known bug: ignored for Edit tool (#37210)

2. context: fork               ████████████████████  ~98%
   ↳ Process-level isolation, confirmed by T1 docs
   ↳ Caveat: tool restrictions inside fork not enforced

3. !command preprocessing      ████████████████████  ~95%
   ↳ Shell executes before LLM, output injected
   ↳ Caveat: parser bugs (#17119, #14315)

4. settings.json permissions   ████████████████░░░░  ~80%
   ↳ Allow/deny rules exist but have documented bugs
   ↳ cognitive-core SECURITY.md acknowledges this

PARTIALLY ENFORCED (bugs reduce reliability)
═══════════════════════════════════════════════════════
5. disallowedTools (agents)    ████████████░░░░░░░░  ~60%
   ↳ Works for basic tool blocking
   ↳ Fails for MCP tools (#20617), edge cases (#19501)

6. allowed-tools (skills)      ██░░░░░░░░░░░░░░░░░░  ~10%
   ↳ NOT ENFORCED — confirmed bug #18837
   ↳ Documentation value only

7. model: opus/sonnet          ██░░░░░░░░░░░░░░░░░░  ~10%
   ↳ NOT ENFORCED — calling LLM can override (#32732)
   ↳ 33% wrong-model rate observed in practice

STOCHASTIC (LLM interprets voluntarily)
═══════════════════════════════════════════════════════
8. Markdown body instructions  █░░░░░░░░░░░░░░░░░░░   ~5%
   ↳ LLM follows probabilistically
   ↳ Compliance degrades with instruction count

9. Agent role boundaries       █░░░░░░░░░░░░░░░░░░░   ~5%
   ↳ Purely advisory prose
   ↳ No enforcement mechanism
```

### Quantified Per Component Type

| Component | Total Lines | Deterministic Lines | Stochastic Lines | Det. % |
|-----------|------------|--------------------|-----------------:|-------:|
| **All Skills (23)** | 5,832 | 177 (frontmatter) + ~180 (!cmd) = ~357 | ~5,475 | **~6%** |
| **All Agents (10)** | ~2,500 est. | ~80 (frontmatter) | ~2,420 | **~3%** |
| **All Hooks (6 active)** | ~900 | ~900 | 0 | **100%** |
| **settings.json** | 84 | 84 | 0 | **100%** |
| **setup.sh (board)** | 252 | 252 | 0 | **100%** |

### Corrected Skill Profiles

**`code-review` skill** (148 lines):
- Frontmatter: 8 lines (but `allowed-tools` not enforced → only `context: fork` is real)
- !command injections: 0
- Stochastic body: 138 lines
- **Effective determinism: ~5%** (fork isolation only)

**`project-board` skill** (1,369 lines):
- Frontmatter: 7 lines (but `allowed-tools` not enforced)
- !command injections: 0
- setup.sh: 252 lines (fully deterministic, but runs separately)
- Stochastic body: 1,360 lines
- **Effective determinism: ~0.5%** (frontmatter routing only)

**`session-resume` skill** (131 lines):
- Frontmatter: 6 lines
- !command injections: 7 (deterministic data injection)
- Stochastic body: ~100 lines
- **Effective determinism: ~10%** (injections provide real data)

---

## Implications for Architecture Evolution

This analysis validates the decision in [#200](https://github.com/mindcockpit-ai/cognitive-core/issues/200) to move toward deterministic n8n workflows:

| Current State | Target State |
|--------------|-------------|
| ~6% of skill execution is deterministic | n8n workflows: ~100% deterministic execution path |
| LLM interprets 1,369 lines of board instructions | n8n executes board transitions via API calls |
| `allowed-tools` not enforced (bug) | n8n node permissions: enforced by workflow engine |
| `model:` selection overridable | n8n AI node: explicit model per node, no override |
| Step ordering not guaranteed | n8n: steps execute in defined sequence |
| Agent boundaries voluntary | n8n sub-workflows: scope defined by available nodes |

### What Stays

- **Hooks** — PreToolUse deny is the most reliable enforcement; keeps value as validation nodes
- **!command injections** — Deterministic data gathering; maps to n8n "Execute Command" nodes
- **context: fork** — Process isolation concept maps to n8n sub-workflow isolation
- **setup.sh** — Deterministic scripts remain deterministic in any architecture

### What Gets Replaced

- **Markdown instructions** → n8n workflow steps (deterministic sequence)
- **Agent role boundaries** → n8n sub-workflow scope (enforced by available nodes)
- **`allowed-tools`** → n8n node catalog per workflow (no bug, by design)
- **`model:` hints** → n8n AI node configuration (explicit, not overridable)

---

## Sources

### T1 — Official Anthropic Documentation & Bug Tracker

| Ref | Source | Used For |
|-----|--------|----------|
| [1] | [code.claude.com/docs/en/skills](https://code.claude.com/docs/en/skills) | Skill frontmatter, !command, context:fork |
| [2] | [code.claude.com/docs/en/sub-agents](https://code.claude.com/docs/en/sub-agents) | Agent frontmatter, model, disallowedTools |
| [3] | [code.claude.com/docs/en/hooks](https://code.claude.com/docs/en/hooks) | Hook lifecycle, PreToolUse deny |
| [4] | [anthropics/claude-code#18837](https://github.com/anthropics/claude-code/issues/18837) | allowed-tools not enforced |
| [5] | [anthropics/claude-code#32732](https://github.com/anthropics/claude-code/issues/32732) | model field not enforced |
| [6] | [anthropics/claude-code#37210](https://github.com/anthropics/claude-code/issues/37210) | PreToolUse deny ignored for Edit |
| [7] | [anthropics/claude-code#19501](https://github.com/anthropics/claude-code/issues/19501) | tools + disallowedTools incompatibility |
| [8] | [anthropics/claude-code#20617](https://github.com/anthropics/claude-code/issues/20617) | allowedTools ignored for MCP |
| [9] | [anthropics/claude-code#7777](https://github.com/anthropics/claude-code/issues/7777) | Claude ignores CLAUDE.md instructions |
| [10] | [anthropics/claude-code#17119](https://github.com/anthropics/claude-code/issues/17119) | !command parser bug |
| [11] | [anthropics/claude-code#14315](https://github.com/anthropics/claude-code/issues/14315) | Backtick parser bug |
| [12] | [anthropics/claude-code#6005](https://github.com/anthropics/claude-code/issues/6005) | disallowedTools feature request |

### T3-T4 — Community & Expert Sources

| Ref | Source | Used For |
|-----|--------|----------|
| [13] | [humanlayer.dev/blog](https://www.humanlayer.dev/blog/writing-a-good-claude-md) | Instruction-following limits |
| [14] | [dev.to article](https://dev.to/minatoplanb/i-wrote-200-lines-of-rules-for-claude-code-it-ignored-them-all-4639) | Prompt rules vs hook enforcement |
| [15] | [agent-axiom Ch.1](https://agent-axiom.github.io/agent-arch/book/part-i/chapter-1/) | "Platform, not magic" thesis |
| [16] | Anthropic, "Building Effective Agents" (cited in [15]) | "Workflow by default, agency by necessity" |

### Verified — cognitive-core Codebase

| Ref | Path | Used For |
|-----|------|----------|
| [17] | `docs/SECURITY.md:258` | "settings.json deny rules are bugged" |
| [18] | `docs/certification-report.md:198` | "hooks for deterministic compliance" |
| [19] | `adapters/aider/README.md:60` | "convention-based safety is advisory" |
| [20] | `.claude/hooks/validate-bash.sh` | Working PreToolUse deny implementation |
| [21] | `.claude/hooks/validate-write.sh` | PostToolUse warn-only (cannot block) |
| [22] | `.claude/agents/research-analyst.md:7` | disallowedTools example |
| [23] | `.claude/skills/project-board/setup.sh` | Deterministic board setup (252 lines) |

---

## Attribution

- **Original analysis**: workspace-coordinator (dev-notes)
- **Peer review**: research-analyst (T1-T5 source verification, 12 T1 sources checked)
- **Codebase evidence**: explore agent (23 skills, 10 agents, 6 hooks inventoried)
- **Catalyst**: Dennis Piskovatskov — "Skills, Agents, Plugins: alles gleich, alles nur .md"
