# Research Report: Claude Code Agent Teams Analysis

**Date**: 2026-03-12
**Researcher**: research-analyst
**Related Issue**: cognitive-core #32 (Agent Learning Framework), framework issue #3
**Status**: Complete

---

## Executive Summary

Claude Code's **Agent Teams** is an experimental feature (since v2.1.32) that orchestrates multiple Claude Code instances as a coordinated team with shared task lists and inter-agent messaging. It represents Anthropic's native multi-agent coordination layer, distinct from the subagent system. While powerful for parallel work, it has significant limitations that make it complementary to — rather than a replacement for — cognitive-core's hub-and-spoke agent architecture. A hybrid adoption strategy is recommended.

---

## 1. What Is Agent Teams Mode?

### Architecture

Agent Teams coordinates multiple **independent Claude Code sessions** (each with its own context window) working on a shared project. The architecture consists of four components:

| Component | Role |
|-----------|------|
| **Team Lead** | The main Claude Code session that creates the team, spawns teammates, and coordinates work |
| **Teammates** | Separate Claude Code instances that each work on assigned tasks |
| **Task List** | Shared list of work items (stored on disk) that teammates claim and complete |
| **Mailbox** | Messaging system for inter-agent communication |

### Seven Core Primitives (Tools)

1. **TeamCreate** — Initializes team namespace and config file at `~/.claude/teams/{team-name}/config.json`
2. **TaskCreate** — Defines work units as JSON files on disk at `~/.claude/tasks/{team-name}/`
3. **TaskUpdate** — Allows agents to claim, update, and complete tasks
4. **TaskList** — Provides shared task visibility for self-coordination
5. **Agent** (with `team_name`) — Spawns teammates within the team context
6. **SendMessage** — Enables direct peer-to-peer communication (message, broadcast, shutdown_request, plan_approval_response)
7. **TeamDelete** — Cleanup after team dissolution

### Communication Model

- **Direct messaging**: Lead can message any teammate; teammates can message each other
- **Broadcast**: Send to all teammates simultaneously (costly — scales with team size)
- **Automatic delivery**: Messages delivered as new conversation turns; no polling needed
- **Idle notifications**: When a teammate finishes and stops, they automatically notify the lead
- **Peer DM visibility**: When teammates DM each other, the lead gets brief summaries

### Task Coordination

Tasks flow through: `pending` -> `in_progress` (owner claimed) -> `completed`. Dependencies are managed automatically — when a dependency completes, blocked tasks unblock. File locking prevents race conditions on concurrent claims. Teammates self-claim the next available unblocked task when idle.

### Display Modes

- **In-process** (default): All teammates run inside the main terminal. `Shift+Down` cycles through teammates.
- **Split panes**: Each teammate gets its own tmux/iTerm2 pane. Requires tmux or iTerm2.

---

## 2. Current Status

### Release Timeline

- **v2.1.32**: Agent Teams introduced as experimental (research preview)
- **Opus 4.6 launch**: Agent Teams shipped as a flagship feature alongside 1M token context
- **March 2026**: Still experimental, disabled by default

### Enablement

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Or in shell: `export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`

### Known Limitations (from official docs)

| Limitation | Impact |
|-----------|--------|
| No session resumption for in-process teammates | `/resume` and `/rewind` do not restore teammates |
| Task status can lag | Teammates sometimes fail to mark tasks completed, blocking dependents |
| Shutdown can be slow | Teammates finish current request before shutting down |
| One team per session | Cannot run multiple teams simultaneously |
| No nested teams | Teammates cannot spawn their own teams |
| Lead is fixed | Cannot promote a teammate to lead |
| Permissions set at spawn | All teammates start with lead's permission set; no per-teammate modes |
| Split panes limited | Not supported in VS Code integrated terminal, Windows Terminal, or Ghostty |

### Open GitHub Issues (Critical)

| Issue | Title | Status |
|-------|-------|--------|
| #24316 | Allow custom `.claude/agents/` definitions as agent team teammates | Open |
| #26107 | Agent Teams should use existing agents | Closed |
| #30703 | Custom agent definitions silently ignored for team agents | Open |
| #30140 | Shared channel for agent teams — persistent, ordered group communication | Open |
| #28175 | Agent teams don't create agents on own worktree | Open |
| #32731 | Teammates have fewer tools than subagents | Open |
| #23620 | Agent team lost when lead's context gets compacted | Open |

**Critical gap**: Custom agent definitions (`.claude/agents/*.md`) are **silently ignored** when used as team agent types. Only `model` and `agent_type` work correctly. The system prompt, hooks, skills, and disallowedTools from frontmatter are all dropped. This is a confirmed bug (#30703) as of v2.1.68.

---

## 3. Case Studies

### Anthropic's C Compiler Project (Flagship Case Study)

Anthropic tasked **16 parallel Claude instances** with writing a Rust-based C compiler from scratch:

| Metric | Value |
|--------|-------|
| **Sessions** | ~2,000 Claude Code sessions over two weeks |
| **Cost** | $20,000 (2B input tokens, 140M output tokens) |
| **Output** | 100,000-line Rust compiler |
| **Result** | Compiled bootable Linux 6.9 on x86, ARM, and RISC-V |
| **Test pass rate** | 99% on GCC torture test suite |

Key insights from Anthropic's engineering team:
- **Testing infrastructure is critical**: "Claude will work autonomously to solve whatever problem I give it. So it's important that the task verifier is nearly perfect."
- **Specialization through role assignment** improved output — agents focused on deduplication, performance, code quality critique, and documentation separately
- Coordination used a **simple lock-based mechanism**: agents claimed tasks by writing files, Git's native sync prevented duplicates

### Code Review Feature (Production Use of Agent Teams)

Anthropic launched **Code Review** (March 9, 2026) as a production feature built on agent team primitives:

- Dispatches a team of agents on every PR
- Agents look for bugs in parallel, verify to filter false positives, rank by severity
- **54% of PRs** receive substantive comments (up from 16% with older approaches)
- **Less than 1% incorrect findings**
- Large PRs (>1,000 lines): 84% get findings, averaging 7.5 issues
- Cost: $15-$25 per review, ~20 minutes completion time
- Available for Team and Enterprise plans

### Community Reports

- **QA Swarm** (alexop.dev): 5 Sonnet-based teammates tested a blog site in parallel in ~3 minutes. Each agent used curl to fetch pages and parse HTML. Cost: ~800K tokens for 3-person team.
- **Developer sentiment**: "The failure modes are similar to managing actual junior engineers — agents get stuck on details, sometimes ignore constraints, occasionally deliver exactly what you asked for but not what you meant."

---

## 4. How It Works Technically

### Spawning a Team

Tell Claude in natural language:

```
Create an agent team with 3 teammates to refactor these modules in parallel.
Use Sonnet for each teammate.
```

Claude creates the team, spawns teammates, and coordinates work based on the prompt.

### Task File System

Teams and tasks are stored locally as JSON files:

```
~/.claude/teams/{team-name}/config.json    # Team config with members array
~/.claude/tasks/{team-name}/               # Task files (one per task)
```

Team config contains a `members` array with each teammate's `name`, `agentId`, and `agentType`.

### Context and Communication

Each teammate loads the same project context as a regular session: `CLAUDE.md`, MCP servers, and skills. It also receives the spawn prompt from the lead. **The lead's conversation history does NOT carry over.**

### Quality Gates

Two hook events enforce quality:

- `TeammateIdle`: Runs when a teammate is about to go idle. Exit code 2 sends feedback and keeps the teammate working.
- `TaskCompleted`: Runs when a task is being marked complete. Exit code 2 prevents completion and sends feedback.

### Plan Approval Mode

Teammates can be required to plan before implementing. The lead reviews and approves/rejects plans before the teammate proceeds:

```
Spawn an architect teammate to refactor the auth module.
Require plan approval before they make any changes.
```

---

## 5. Comparison with cognitive-core's Approach

### Architecture Comparison

| Dimension | cognitive-core (current) | Claude Code Agent Teams |
|-----------|--------------------------|-------------------------|
| **Orchestration model** | Hub-and-spoke: project-coordinator delegates to specialists via subagent spawning | Peer-to-peer: lead spawns teammates that communicate directly with each other |
| **Agent definition** | `.claude/agents/*.md` with rich YAML frontmatter (model, tools, disallowedTools, hooks, skills, memory) | Natural language prompts at spawn time; `.claude/agents/` definitions exist but are **silently ignored** by team agents (#30703) |
| **Communication** | One-way: subagent reports results back to coordinator | Multi-directional: teammates message each other, lead, and user |
| **Context sharing** | Subagent results return to coordinator's context window | Each teammate has fully independent context; no shared memory |
| **Task management** | Coordinator manages via internal planning; no shared task system | Shared task list on disk with dependency tracking and self-claiming |
| **Tool isolation** | Per-agent via `tools`/`disallowedTools` frontmatter (enforced) | All teammates inherit lead's permissions; no per-teammate restrictions |
| **Persistent memory** | Via `memory: user\|project\|local` frontmatter field | Not supported for teammates (only for standalone subagents) |
| **Skill preloading** | Via `skills` frontmatter field | Not supported for teammates (#30703) |
| **Lifecycle hooks** | Per-agent hooks in frontmatter | Silently ignored for team agents; only global hooks work |
| **Cost** | Lower: subagents summarize results back | Higher: each teammate is a separate full Claude instance |
| **Parallelism** | Sequential delegation (one subagent at a time unless background) | True parallel execution across independent sessions |
| **Human interaction** | Through coordinator only | Can message any teammate directly |

### What cognitive-core Does Better

1. **Agent specialization is deterministic**: Tool restrictions via `disallowedTools` physically prevent agents from performing unauthorized actions. Agent Teams relies on natural language prompts, which can be ignored.

2. **Rich agent definitions**: Model, tools, hooks, skills, memory, and system prompts are all defined declaratively in a single `.md` file. Agent Teams teammates are generic `general-purpose` agents with no per-teammate customization.

3. **Cost efficiency**: The subagent model returns summarized results to the coordinator, preserving tokens. Agent Teams maintains a full context window per teammate.

4. **Reproducibility**: Agent definitions are version-controlled `.md` files. Agent Teams teams are ephemeral and prompt-dependent.

5. **Domain knowledge injection**: Skills and persistent memory allow agents to accumulate and reuse domain knowledge. Agent Teams teammates start fresh every time.

### What Agent Teams Does Better

1. **True parallelism**: Multiple agents work simultaneously on different aspects of a problem, each in their own context window. cognitive-core's subagent model is largely sequential.

2. **Inter-agent communication**: Teammates can message each other directly, debate hypotheses, and coordinate without going through a hub. cognitive-core's subagents can only report back to the coordinator.

3. **Self-coordination**: The shared task list with dependency management and self-claiming reduces coordinator overhead. cognitive-core requires the coordinator to explicitly manage all delegation.

4. **Human-in-the-loop flexibility**: Users can message any teammate directly, redirect approaches, and observe all agents simultaneously. cognitive-core routes everything through the coordinator.

5. **Quality gates**: `TeammateIdle` and `TaskCompleted` hooks provide lifecycle checkpoints that cognitive-core lacks.

---

## 6. Migration Path Assessment

### Can cognitive-core Agent Definitions Work with Agent Teams?

**Not today.** The critical blocker is GitHub issue #30703: custom `.claude/agents/` definitions are silently ignored when used as team agent types. Only `model` and `agent_type` are respected; everything else (system prompt, hooks, skills, disallowedTools) is dropped.

Issue #24316 is the comprehensive feature request to close this gap. It proposes:

```
Create a team to refactor the auth module. Spawn these teammates:
- A "researcher" using my code-reviewer agent (read-only, Haiku)
- An "implementer" using my debugger agent (full tools, inherits model)
- A "validator" using my db-reader agent (Bash with SQL validation hooks)
```

This would make the team config reflect the agent type:

```json
{
  "name": "researcher",
  "agentType": "code-reviewer",
  "model": "haiku"
}
```

**Until #24316 or #30703 is resolved, cognitive-core's agent definitions cannot be used as team agent types.**

### Recommended Hybrid Strategy

Given the current state, a phased adoption is recommended:

#### Phase 1: Coexistence (Now)

- **Keep cognitive-core's subagent architecture** for specialized, reproducible work where tool isolation and domain knowledge matter (code review, security analysis, database optimization)
- **Use Agent Teams experimentally** for parallel research, competing hypothesis debugging, and large refactoring tasks where inter-agent communication is valuable
- **Monitor GitHub issues** #30703, #24316, and #30140 for resolution

#### Phase 2: Bridge Layer (When #30703 / #24316 is resolved)

- Create a **cognitive-core skill** (e.g., `/agent-team`) that:
  - Reads cognitive-core agent definitions from `.claude/agents/`
  - Spawns Agent Teams teammates using those definitions
  - Maps `tools`/`disallowedTools` to per-teammate restrictions
  - Injects system prompts via spawn prompts
- This preserves cognitive-core's declarative agent definitions while leveraging Agent Teams' parallelism

#### Phase 3: Native Integration (Future)

- Once Agent Teams supports full `.claude/agents/` frontmatter for teammates:
  - Migrate the project-coordinator's sequential delegation to parallel team execution for suitable tasks
  - Keep hub-and-spoke for tasks requiring sequential dependency chains
  - Add `teamRole` frontmatter field to cognitive-core agent definitions to indicate team-compatible agents
  - Extend the handoff brief protocol to work with Agent Teams' shared task list

### What Would Need to Change in cognitive-core

| Component | Change Required | Effort |
|-----------|----------------|--------|
| Agent definitions (`.claude/agents/*.md`) | Add optional `teamRole` field; no breaking changes | Low |
| `project-coordinator.md` | Add team-aware delegation logic alongside subagent delegation | Medium |
| `AGENTS_README.md` | Document when to use subagent vs team delegation | Low |
| New skill: `/agent-team` | Bridge skill that maps cognitive-core agents to Agent Teams teammates | Medium |
| `cognitive-core.conf` | Add `agentTeams` section for default team configurations | Low |
| Hooks | Add `TeammateIdle` and `TaskCompleted` hooks to cognitive-core | Medium |

---

## 7. Cost Analysis

| Approach | Typical Token Usage | Relative Cost |
|----------|-------------------|---------------|
| Single session | ~100K tokens | 1x |
| cognitive-core subagent delegation (3 agents) | ~440K tokens | 4.4x |
| Agent Teams (3 teammates) | ~800K tokens | 8x |
| Agent Teams (5 teammates) | ~1.2M tokens | 12x |

Agent Teams costs scale linearly with teammate count. Each teammate maintains a full context window. The recommended 5-6 tasks per teammate with 3-5 teammates balances throughput against cost.

---

## 8. Key Recommendations

1. **Do not migrate to Agent Teams yet.** The custom agent definition bug (#30703) makes it impossible to preserve cognitive-core's agent specialization in a team context.

2. **Experiment with Agent Teams for suitable tasks.** Enable the experimental flag and test with research, parallel review, and debugging tasks. Document lessons learned.

3. **Watch these GitHub issues closely:**
   - [#30703](https://github.com/anthropics/claude-code/issues/30703) — Custom agent definitions silently ignored for team agents
   - [#24316](https://github.com/anthropics/claude-code/issues/24316) — Allow custom `.claude/agents/` definitions as team teammates
   - [#30140](https://github.com/anthropics/claude-code/issues/30140) — Shared channel for persistent group communication

4. **Plan a bridge skill** (`/agent-team`) as a cognitive-core contribution that maps agent definitions to Agent Teams teammates once the upstream blockers are resolved.

5. **Consider Code Review adoption.** Anthropic's production Code Review feature (built on Agent Teams) could complement cognitive-core's `code-standards-reviewer` agent for PR-level review.

6. **Update cognitive-core issue #3** with this analysis and the phased adoption plan.

---

## Sources

- [Official Agent Teams Documentation](https://code.claude.com/docs/en/agent-teams)
- [Official Subagents Documentation](https://code.claude.com/docs/en/sub-agents)
- [From Tasks to Swarms: Agent Teams in Claude Code — alexop.dev](https://alexop.dev/posts/from-tasks-to-swarms-agent-teams-in-claude-code/)
- [Building a C Compiler with Agent Teams — Anthropic Engineering](https://www.anthropic.com/engineering/building-c-compiler)
- [Code Review for Claude Code — Claude Blog](https://claude.com/blog/code-review)
- [TeammateTool System Prompt — Piebald-AI](https://github.com/Piebald-AI/claude-code-system-prompts/blob/main/system-prompts/tool-description-teammatetool.md)
- [GitHub #24316: Allow custom agents as team teammates](https://github.com/anthropics/claude-code/issues/24316)
- [GitHub #30703: Custom agent definitions silently ignored](https://github.com/anthropics/claude-code/issues/30703)
- [GitHub #26107: Agent Teams should use existing agents](https://github.com/anthropics/claude-code/issues/26107)
- [GitHub #30140: Shared channel for agent teams](https://github.com/anthropics/claude-code/issues/30140)
- [GitHub #32731: Teammates have fewer tools than subagents](https://github.com/anthropics/claude-code/issues/32731)
- [Claude Code Agent Teams Complete Guide — claudefa.st](https://claudefa.st/blog/guide/agents/agent-teams)
- [Claude Code Agent Teams — Cobus Greyling (Medium)](https://cobusgreyling.medium.com/claude-code-agent-teams-ca3ec5f2d26a)
- [Agent Teams in Claude Code — Daniel Avila (Medium)](https://medium.com/@dan.avila7/agent-teams-in-claude-code-d6bb90b3333b)
- [Claude Code Swarm Orchestration Skill — kieranklaassen (Gist)](https://gist.github.com/kieranklaassen/4f2aba89594a4aea4ad64d753984b2ea)
- [Anthropic launches code review tool — TechCrunch](https://techcrunch.com/2026/03/09/anthropic-launches-code-review-tool-to-check-flood-of-ai-generated-code/)
- [Anthropic launches multi-agent code review — The New Stack](https://thenewstack.io/anthropic-launches-a-multi-agent-code-review-tool-for-claude-code/)
- [Claude Code Agent Teams vs. Claude-Flow: A Real-World Bake-Off — Derek Ashmore (Medium)](https://medium.com/@derekcashmore/claude-code-agent-teams-vs-claude-flow-a-real-world-bake-off-97e24f6ca9b9)
