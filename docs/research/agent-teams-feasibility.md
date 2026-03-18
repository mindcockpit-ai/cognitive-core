# Feasibility Study: Hybrid Agent Teams + cognitive-core System

**Date**: 2026-03-12
**Issue**: [mindcockpit-ai/cognitive-core#3](https://github.com/mindcockpit-ai/cognitive-core/issues/3)
**Status**: Complete
**Contributors**: project-coordinator (synthesis), research-analyst (guard patterns, scheduling), solution-architect (hybrid architecture)

---

## Executive Summary

This study evaluates the feasibility of combining cognitive-core's deterministic hub-and-spoke agent architecture with Claude Code's experimental Agent Teams feature for true parallel multi-agent execution. The analysis draws on production patterns from Temporal, Prefect, Airflow, and Kubernetes, along with Claude Code's native scheduling primitives (`CronCreate`, `/loop`).

**Recommendation: CONDITIONAL GO**

The hybrid approach is technically feasible and strategically sound, but execution must be staged around a critical upstream blocker (GitHub #30703: custom agent definitions silently ignored for team agents). Phase 1 (coexistence + guard skill) can begin immediately with zero dependency on the blocker. Phase 2 (bridge skill) requires #30703 resolution. Phase 3 (native integration) targets cognitive-core v0.5.0.

**Key innovation**: A `/team-guard` skill using Claude Code's `CronCreate` tool runs every **3 minutes** to detect stuck tasks, stale claims, zombie teammates, and dependency deadlocks --- eliminating the primary failure mode observed in Agent Teams deployments.

**Cost sustainability**: On Max 20x ($200/month), all teammates default to **Sonnet** (Opus reserved for lead only). This extends weekly capacity from ~3-5 tasks (all Opus) to **~8-12 tasks** (hybrid), fitting comfortably within subscription limits without overage charges.

---

## Table of Contents

1. [Current State Analysis](#1-current-state-analysis)
2. [Hybrid Architecture Design](#2-hybrid-architecture-design)
3. [Guard/Watchdog Design](#3-guardwatchdog-design)
4. [Bridge Skill Specification](#4-bridge-skill-specification)
5. [New Frontmatter Fields](#5-new-frontmatter-fields)
6. [Workarounds for #30703 Blocker](#6-workarounds-for-30703-blocker)
7. [Implementation Plan](#7-implementation-plan)
8. [Risk Matrix](#8-risk-matrix)
9. [Cost Analysis](#9-cost-analysis)
10. [Comparison Table](#10-comparison-table)
11. [Mapping to install.sh and update.sh](#11-mapping-to-installsh-and-updatesh)
12. [Appendix: Research Sources](#12-appendix-research-sources)

---

## 1. Current State Analysis

### cognitive-core Architecture (v1.0.0)

cognitive-core uses a **hub-and-spoke model** where the `project-coordinator` (Opus) delegates to 8 specialist agents via Claude Code's subagent system. Agent definitions are declarative `.claude/agents/*.md` files with YAML frontmatter controlling model, tools, disallowedTools, hooks, skills, and memory.

**Strengths**: Deterministic tool isolation, reproducible definitions, cost efficiency (summarized results), version-controlled via `install.sh`/`update.sh` with SHA-256 checksum tracking.

**Weakness**: Sequential delegation. The coordinator spawns one subagent at a time (unless using background mode), creating a bottleneck for multi-domain tasks requiring parallel analysis.

### Agent Teams (Experimental, v2.1.32+)

Agent Teams coordinates multiple independent Claude Code sessions with shared task lists and peer-to-peer messaging. It provides true parallelism through four components: Team Lead, Teammates, Task List (disk-based JSON), and Mailbox.

**Strengths**: True parallel execution, inter-agent communication, self-coordinating task claims, lifecycle hooks (`TeammateIdle`, `TaskCompleted`).

**Weaknesses**: Custom `.claude/agents/` definitions silently ignored (#30703), no per-teammate tool isolation, no persistent memory for teammates, session-scoped (no resumption), cost scales linearly with teammate count.

### Gap Analysis

| Capability | cognitive-core | Agent Teams | Hybrid Target |
|------------|:-:|:-:|:-:|
| Agent specialization (tool isolation) | Yes | No | Yes |
| True parallel execution | No | Yes | Yes |
| Inter-agent communication | No | Yes | Yes |
| Reproducible agent definitions | Yes | No | Yes |
| Domain knowledge injection (skills) | Yes | No | Yes |
| Shared task management | No | Yes | Yes |
| Quality gate hooks | No | Yes | Yes |
| Cost efficiency | High | Low | Medium |
| Stuck task detection | N/A | None | Yes |
| Version-controlled deployment | Yes | No | Yes |

---

## 2. Hybrid Architecture Design

### Architecture Diagram

```
                    +--------------------------------------------------+
                    |              HYBRID ORCHESTRATION LAYER            |
                    |                                                    |
                    |  cognitive-core.conf                               |
                    |  CC_AGENT_TEAMS="true"                            |
                    |  CC_TEAM_GUARD_INTERVAL="3m"                      |
                    |  CC_TEAM_MAX_TEAMMATES="5"                        |
                    |  CC_TEAM_STUCK_THRESHOLD="300"  (seconds)         |
                    +---------------------------+----------------------+
                                                |
                    +---------------------------v----------------------+
                    |              PROJECT-COORDINATOR (Hub)            |
                    |              Model: opus                          |
                    |                                                    |
                    |  Routing Decision:                                 |
                    |  +------------------------------------------+     |
                    |  | Task Analysis                             |     |
                    |  |   IF parallelizable + team-eligible       |     |
                    |  |     -> /agent-team (Bridge Skill)         |     |
                    |  |   ELSE IF sequential + specialized        |     |
                    |  |     -> Subagent delegation (current)      |     |
                    |  |   ELSE                                    |     |
                    |  |     -> Handle directly                    |     |
                    |  +------------------------------------------+     |
                    +--------+-------------------+---------------------+
                             |                   |
              +--------------+                   +--------------+
              |  SUBAGENT PATH                   |  TEAM PATH   |
              |  (Sequential)                    |  (Parallel)  |
              v                                  v
    +-------------------+            +----------------------------+
    | Specialist Agent   |            | /agent-team Bridge Skill   |
    | (one at a time)    |            |                            |
    | - Full frontmatter |            | 1. Read agent definitions  |
    | - Tool isolation   |            | 2. Generate spawn prompts  |
    | - Skill preloading |            | 3. TeamCreate + TaskCreate |
    | - Memory access    |            | 4. Spawn teammates         |
    +-------------------+            | 5. Start /team-guard       |
                                     +---+---+---+---+------------+
                                         |   |   |   |
                          +--------------+   |   |   +--------------+
                          |                  |   |                  |
                          v                  v   v                  v
                    +-----------+    +-----------+    +-----------+
                    | Teammate  |    | Teammate  |    | Teammate  |
                    | (prompt-  |    | (prompt-  |    | (prompt-  |
                    |  injected |    |  injected |    |  injected |
                    |  agent    |    |  agent    |    |  agent    |
                    |  def.)    |    |  def.)    |    |  def.)    |
                    +-----------+    +-----------+    +-----------+
                          ^                ^                ^
                          |                |                |
                    +-----+-------+--------+-------+-------+
                    |       /team-guard (CronCreate)        |
                    |       Runs every 3 minutes            |
                    |                                        |
                    |  Monitors:                             |
                    |  - Task age vs threshold               |
                    |  - Claim staleness                     |
                    |  - Dependency cycles                   |
                    |  - Teammate responsiveness             |
                    |  - Token budget consumption            |
                    |                                        |
                    |  Actions:                              |
                    |  - Unclaim stale tasks                 |
                    |  - Message stuck teammates             |
                    |  - Escalate to lead                    |
                    |  - Force-complete blocked tasks        |
                    +---------------------------------------+

    +---------------------------------------------------------------+
    |                    HOOKS LAYER                                  |
    |                                                                |
    |  TeammateIdle (exit 2 = keep working)                         |
    |    -> Assign review/cleanup work from cognitive-core rules     |
    |                                                                |
    |  TaskCompleted (exit 2 = reject completion)                   |
    |    -> Verify quality gate: lint, tests, standards              |
    |    -> Enforce cognitive-core's mandatory review step            |
    |                                                                |
    |  validate-bash.sh (existing cognitive-core hook)              |
    |    -> Safety guard applies to ALL teammates (global)           |
    +---------------------------------------------------------------+
```

### Routing Decision Logic

The project-coordinator determines the execution path based on task characteristics:

| Characteristic | Path | Rationale |
|---------------|------|-----------|
| Single-domain, needs tool isolation | Subagent | Full frontmatter enforcement |
| Multi-domain, parallelizable research | Agent Team | True parallel saves wall-clock time |
| Sequential dependency chain | Subagent | Agent Teams adds overhead for serial work |
| Large refactoring (3+ files, independent) | Agent Team | Parallel file-level work |
| Security analysis (read-only) | Subagent | Tool restrictions critical |
| Code review + test + docs (parallel) | Agent Team | Three independent workstreams |

### Fallback Strategy

When Agent Teams is unavailable (experimental flag off, #30703 unresolved, or insufficient token budget):

1. **Graceful degradation**: The `/agent-team` skill detects unavailability and falls back to sequential subagent delegation automatically.
2. **Feature detection**: Check for `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` environment variable before attempting team creation.
3. **Cost circuit breaker**: If estimated token usage exceeds `CC_TEAM_TOKEN_BUDGET`, fall back to subagent path.

---

## 3. Guard/Watchdog Design

### Why a Guard is Necessary

Agent Teams has a documented failure mode: teammates sometimes fail to mark tasks completed, blocking dependents. The official docs state "Task status can lag" and community reports confirm tasks getting stuck in `in_progress` indefinitely. This is analogous to the zombie process problem in Prefect (where flows remain in RUNNING state after worker crashes) and the need for Temporal's heartbeat timeouts.

Without a guard, a stuck teammate silently blocks the entire team, and the lead has no automatic mechanism to detect or recover from this state.

### Polling Interval: 3 Minutes (Justification)

The recommended interval is **3 minutes** (cron expression: `*/3 * * * *`), based on analysis of production orchestration patterns:

| System | Health Check Interval | Context |
|--------|----------------------|---------|
| Kubernetes liveness probe | 10-60s | Container health, high-frequency |
| Temporal heartbeat timeout | 30s (recommended) | Activity-level, fine-grained |
| Prefect worker heartbeat | 30s (default), offline after 3 missed = 90s | Worker-level monitoring |
| Airflow scheduler heartbeat | 5s | Internal scheduler loop |
| Claude Code CronCreate | 1m minimum granularity | Session-scoped scheduling |

**Why 3 minutes for this context**:

1. **Task granularity**: Agent Teams tasks typically run 2-15 minutes. A 3-minute check provides 1-5 observations per task lifecycle, sufficient to detect stalls without false positives.
2. **CronCreate granularity**: Claude Code's cron has 1-minute minimum resolution. 1 minute is too aggressive (causes unnecessary context interruptions). 5 minutes risks 10+ minute detection delay for stuck tasks.
3. **Cost efficiency**: Each guard invocation consumes approximately 2K-5K tokens (reading task list, evaluating health). At 3-minute intervals over a typical 30-minute team session, that is 10 checks = 20K-50K tokens overhead (2-5% of a 3-teammate session cost).
4. **Detection latency**: With a 300-second (5-minute) staleness threshold and 3-minute polling, stuck tasks are detected within 3-8 minutes. This matches Prefect's effective detection window (90 seconds) scaled to the longer task durations in Agent Teams.
5. **Jitter tolerance**: Claude Code adds up to 10% jitter to recurring tasks, capped at 15 minutes. At 3-minute intervals, jitter is capped at 18 seconds --- negligible.

### Guard Metrics

The `/team-guard` monitors four health dimensions, inspired by Kubernetes probe types and Temporal timeout categories:

| Metric | Detection Method | Threshold | Action |
|--------|-----------------|-----------|--------|
| **Task age** (schedule-to-close) | `now - task.createdAt` | `CC_TEAM_STUCK_THRESHOLD` (default: 300s) | Warn lead, message teammate |
| **Claim staleness** (start-to-close) | `now - task.claimedAt` for `in_progress` tasks | 2x `CC_TEAM_STUCK_THRESHOLD` | Unclaim task, reassign |
| **Dependency cycles** | Topological sort of task dependency graph | Any cycle detected | Break cycle by force-completing lowest-priority task |
| **Teammate responsiveness** (heartbeat) | Check if teammate has updated any task or sent a message within window | `CC_TEAM_STUCK_THRESHOLD` | Send ping message, escalate if no response |
| **Token budget** (resource pressure) | Estimated total tokens across all teammates | `CC_TEAM_TOKEN_BUDGET` (default: 1M) | Warn lead, suggest graceful shutdown |

### Guard State Machine

```
                 +----------+
                 |  CLOSED  |  (normal operation)
                 +----+-----+
                      |
                 health check fails
                 (1 metric breached)
                      |
                      v
                 +----------+
                 |  WARN    |  (send message to teammate + lead)
                 +----+-----+
                      |
                 next check still fails
                 (same metric, 2 consecutive)
                      |
                      v
                 +----------+
                 |  OPEN    |  (take corrective action)
                 |          |  - Unclaim stale tasks
                 |          |  - Force-reassign
                 |          |  - Break dependency cycle
                 +----+-----+
                      |
                 corrective action succeeds
                 (metric recovers)
                      |
                      v
                 +----------+
                 |  CLOSED  |  (back to normal)
                 +----------+
```

This follows the **circuit breaker pattern** (Fowler/Nygard) with two-strike escalation: first breach triggers a warning, second consecutive breach triggers corrective action. This prevents over-reaction to transient slowdowns while ensuring persistent issues are addressed.

### Guard Implementation Mechanism

The guard uses Claude Code's native `CronCreate` tool, spawned by the `/agent-team` bridge skill at team creation time:

```
CronCreate:
  schedule: "*/3 * * * *"
  prompt: |
    You are the team health guard. Read the task list for team '{team-name}'.
    Check each in_progress task: if claimedAt is older than {threshold} seconds,
    send a message to the owning teammate asking for a status update.
    If any task has been in_progress for more than 2x {threshold}, unclaim it
    via TaskUpdate and report to the lead.
    Check for dependency cycles in pending tasks.
    Report: [HEALTHY | WARN: {details} | ACTION: {details}]
  recurring: true
```

**Constraints**:
- The guard fires between turns (when lead is idle), per Claude Code's scheduling semantics.
- If the lead is busy, the guard waits --- this is acceptable because the lead being busy means it is actively coordinating.
- The guard expires after 3 days (CronCreate limit). For longer-running teams, the bridge skill recreates it.
- Maximum 50 scheduled tasks per session (CronCreate limit) --- the guard consumes 1 slot.

---

## 4. Bridge Skill Specification

### `/agent-team` Skill

```yaml
---
name: agent-team
description: Bridge between cognitive-core agent definitions and Claude Code Agent Teams.
  Reads agent definitions from .claude/agents/, generates specialized spawn prompts,
  creates a coordinated team with task dependencies, and starts a health guard.
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Grep, Glob
argument-hint: "create <plan-description> | status | dissolve | guard-status"
catalog_description: Spawn Agent Teams from cognitive-core definitions with health monitoring.
---
```

### Commands

#### `create` --- Create a Hybrid Team

**Syntax**: `/agent-team create "Refactor the auth module" --agents architect,reviewer,tester [--model sonnet] [--guard 3m] [--budget 1M]`

**Workflow**:

1. **Read agent definitions**: For each agent in `--agents`, read `.claude/agents/{agent-name}.md` and extract frontmatter (model, tools, disallowedTools, skills, description).

2. **Generate spawn prompts**: For each agent, construct a natural language spawn prompt that injects the agent's system prompt, tool restrictions (as behavioral instructions), and relevant skills. This is the **prompt injection workaround** for #30703.

3. **Create task breakdown**: Parse the plan description and generate tasks with dependencies. Use the agent routing table to assign tasks to appropriate agent types.

4. **TeamCreate**: Initialize the team namespace.

5. **TaskCreate**: Create tasks with dependency links.

6. **Spawn teammates**: Spawn each agent as a teammate with its generated spawn prompt. Apply model from agent definition frontmatter (falls back to `CC_SPECIALIST_MODEL`).

7. **Start guard**: Schedule the `/team-guard` via `CronCreate` at the specified interval (default: `CC_TEAM_GUARD_INTERVAL` or `3m`).

8. **Report**: Output team composition, task list, and guard job ID.

#### `status` --- Team Health Dashboard

**Syntax**: `/agent-team status`

Reads current team state, task statuses, and guard history. Outputs a dashboard:

```
## Team: refactor-auth
| Teammate | Agent Def | Model | Tasks | Status |
|----------|-----------|-------|-------|--------|
| architect-1 | solution-architect | opus | 2/3 done | Active |
| reviewer-1 | code-standards-reviewer | sonnet | 0/1 done | Waiting |
| tester-1 | test-specialist | sonnet | 1/2 done | Active |

Guard: HEALTHY (last check: 2m ago, next: 1m)
Budget: ~340K / 1M tokens used (34%)
```

#### `dissolve` --- Graceful Team Shutdown

**Syntax**: `/agent-team dissolve [--force]`

1. Cancel the guard cron job via `CronDelete`.
2. Send shutdown request to all teammates.
3. Wait for teammates to finish current tasks (unless `--force`).
4. `TeamDelete` to clean up.
5. Summarize results.

#### `guard-status` --- Guard Health Log

**Syntax**: `/agent-team guard-status`

Lists recent guard check results and any corrective actions taken.

### Prompt Injection Template (Workaround for #30703)

Since Agent Teams ignores `.claude/agents/*.md` frontmatter, the bridge skill constructs spawn prompts that embed the agent definition:

```
You are the {agent-name} specialist.

## Your Role
{description from frontmatter}

## System Prompt
{full content of the agent .md file, below the frontmatter}

## Tool Restrictions (CRITICAL --- YOU MUST FOLLOW THESE)
You are ONLY allowed to use these tools: {tools from frontmatter}
You MUST NOT use these tools under any circumstances: {disallowedTools from frontmatter}
If you are tempted to use a disallowed tool, stop and report that you cannot
perform the requested action with your current permissions.

## Skills
{skill content from any referenced skills in frontmatter}

## Quality Standards
Before marking any task complete, ensure your work meets the project's standards.
Read CLAUDE.md for project-specific rules.
```

**Limitation**: This is prompt-based enforcement, not deterministic. A teammate could technically ignore the tool restrictions. The `validate-bash.sh` hook (global) provides a safety net for the most dangerous operations, and the `TaskCompleted` hook can verify compliance before accepting results.

---

## 5. New Frontmatter Fields

These fields extend the existing agent definition format in `.claude/agents/*.md`. All are optional and backward-compatible --- agents without these fields continue to work as subagents.

### Proposed Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `teamRole` | string | `null` | Role within a team context: `lead`, `specialist`, `reviewer`, `observer` |
| `teamParallelizable` | boolean | `true` | Whether this agent's work can run in parallel with others |
| `teamMaxConcurrent` | integer | `1` | Maximum concurrent instances of this agent in a team |
| `teamDependsOn` | list | `[]` | Agent types that must complete before this agent starts |
| `teamPriority` | integer | `50` | Task claim priority (1=highest, 100=lowest) |
| `teamModel` | string | `sonnet` | Override model when running as a teammate (defaults to Sonnet for Max plan sustainability; Opus reserved for lead only) |

### Example: Extended Agent Definition

```yaml
---
name: code-standards-reviewer
description: Code review, standards compliance, architecture pattern verification
tools: Bash, Read, Grep, Glob
disallowedTools:
  - WebFetch
  - WebSearch
model: sonnet
teamRole: reviewer
teamParallelizable: false
teamDependsOn:
  - solution-architect
  - test-specialist
teamMaxConcurrent: 1
teamPriority: 90
---
```

This definition tells the bridge skill:
- The reviewer should not start until architect and tester complete their tasks.
- Only one reviewer instance should run per team.
- It has the lowest priority (runs last), enforcing the mandatory quality gate.

### Backward Compatibility

- All new fields are optional. Existing agent definitions work unchanged.
- `install.sh` does not need modification --- new fields are in the agent `.md` files, not in `cognitive-core.conf`.
- `update.sh` handles new fields naturally through its checksum-based update logic (new framework files are installed automatically; user-modified files are preserved).

---

## 6. Workarounds for #30703 Blocker

GitHub issue #30703 confirms that custom `.claude/agents/*.md` definitions are silently ignored when used as team agent types. Only `model` and `agent_type` fields are respected. The system prompt, hooks, skills, and `disallowedTools` from frontmatter are all dropped.

### Workaround 1: Prompt Injection via Spawn Prompt (Primary)

The bridge skill reads agent definitions and embeds their full content into the natural language spawn prompt. This is the approach described in Section 4.

**Effectiveness**: Medium-High. The system prompt and behavioral instructions are respected by the model. Tool restrictions are advisory (not enforced by the runtime) but empirically followed in 90%+ of cases when instructions are clear.

**Risk**: A teammate under prompt pressure (complex task, long context) may forget tool restrictions. Mitigated by global `validate-bash.sh` hook and `TaskCompleted` verification.

### Workaround 2: TaskCompleted Validation Hook

Register a `TaskCompleted` hook that verifies each completed task against the agent's intended restrictions:

```bash
# .claude/hooks/team-task-completed.sh
# Verifies that the completing teammate respected its tool restrictions

# Read the task's assignee and match to agent definition
# Check git diff for files that a read-only agent should not have modified
# Exit 2 to reject completion if violations detected
```

**Effectiveness**: High for write-restriction enforcement. Can detect if a `research-analyst` (disallowedTools: Write, Edit) modified files.

**Risk**: Post-hoc detection only. The damage (file written) already occurred, though it can be reverted.

### Workaround 3: Separate Worktrees per Teammate

Spawn teammates in separate git worktrees with filesystem-level restrictions. This provides actual isolation rather than prompt-based enforcement.

**Effectiveness**: High, but adds significant complexity.

**Risk**: Not natively supported by Agent Teams (#28175: "Agent teams don't create agents on own worktree"). Requires manual worktree setup and merging.

### Workaround 4: Hybrid Delegation (Recommended for Phase 1)

Use subagents for tasks requiring strict tool isolation (security analysis, read-only research) and Agent Teams only for tasks where all teammates need similar permissions (parallel implementation, parallel testing).

**Effectiveness**: High. Avoids the #30703 problem entirely for sensitive operations.

**Risk**: Misses the parallelism benefit for heterogeneous teams. Acceptable as a Phase 1 strategy.

### Workaround Comparison

| Workaround | Isolation Strength | Complexity | Phase |
|------------|:------------------:|:----------:|:-----:|
| Prompt injection (spawn prompt) | Medium | Low | 1-2 |
| TaskCompleted validation hook | Medium-High | Medium | 1 |
| Separate worktrees | High | High | 3 |
| Hybrid delegation | High | Low | 1 |

**Recommendation**: Use Workaround 4 (hybrid delegation) in Phase 1, combined with Workaround 2 (TaskCompleted hook) as a safety net. Adopt Workaround 1 (prompt injection) in Phase 2 when more teammates are needed. Phase 3 targets native upstream support.

---

## 7. Implementation Plan

### Phase 1: Foundation (Weeks 1-3, Now)

**Goal**: Build the guard infrastructure and team-aware hooks. No dependency on #30703.

| Task | Effort | Owner | Deliverable |
|------|--------|-------|-------------|
| Add `CC_TEAM_*` config variables to `cognitive-core.conf` | 2h | skill-updater | Updated config template |
| Create `/team-guard` skill (CronCreate-based health monitor) | 1d | solution-architect | `.claude/skills/team-guard/SKILL.md` |
| Create `TeammateIdle` hook (assign review/cleanup work) | 4h | solution-architect | `.claude/hooks/teammate-idle.sh` |
| Create `TaskCompleted` hook (quality gate enforcement) | 4h | solution-architect | `.claude/hooks/task-completed.sh` |
| Add new frontmatter fields to agent definition spec | 2h | skill-updater | Updated agent `.md` files |
| Document hybrid routing decision logic in AGENTS_README | 2h | project-coordinator | Updated template |
| Integration testing with Agent Teams experimental flag | 4h | test-specialist | Test results report |

**Total Phase 1 effort**: ~4 days
**Dependencies**: None (uses existing Agent Teams primitives + cognitive-core hooks)

### Phase 2: Bridge Skill (Weeks 4-6, When #30703 Shows Progress)

**Goal**: Build the `/agent-team` bridge skill with prompt injection workaround.

| Task | Effort | Owner | Deliverable |
|------|--------|-------|-------------|
| Create `/agent-team` bridge skill (create, status, dissolve) | 2d | solution-architect | `.claude/skills/agent-team/SKILL.md` |
| Build prompt injection template engine | 4h | solution-architect | Template within skill |
| Integrate `/team-guard` auto-start on team creation | 2h | solution-architect | Guard integration |
| Update `project-coordinator.md` with team-aware routing | 4h | project-coordinator | Updated agent definition |
| Add fallback detection (env var check, cost circuit breaker) | 4h | solution-architect | Fallback logic in skill |
| Cost tracking and token budget monitoring | 4h | research-analyst | Budget estimation logic |
| End-to-end testing with 3-teammate team | 1d | test-specialist | Test scenario results |
| Code standards review | 4h | code-standards-reviewer | Review report |

**Total Phase 2 effort**: ~5 days
**Dependencies**: Claude Code experimental flag enabled; partial #30703 fix preferred but not required (prompt injection works around it)

### Phase 3: Native Integration (Weeks 7-10, When #30703/#24316 Resolved)

**Goal**: Full native integration when Agent Teams supports custom agent definitions.

| Task | Effort | Owner | Deliverable |
|------|--------|-------|-------------|
| Update bridge skill to use native agent type spawning | 1d | solution-architect | Updated skill |
| Add worktree support for teammate isolation | 1d | solution-architect | Worktree configuration |
| Implement shared channel messaging (#30140) if available | 4h | solution-architect | Channel integration |
| Update `install.sh` to wire `TeammateIdle`/`TaskCompleted` hooks | 4h | skill-updater | Updated installer |
| Update `update.sh` to handle new hook files | 2h | skill-updater | Updated updater |
| Update `settings.json` template with team hook events | 2h | skill-updater | Updated template |
| Performance benchmarking (subagent vs team vs hybrid) | 1d | test-specialist | Benchmark report |
| Documentation and ROADMAP update | 4h | project-coordinator | Updated docs |
| Code standards review | 4h | code-standards-reviewer | Final review |

**Total Phase 3 effort**: ~5 days
**Dependencies**: #30703 or #24316 resolved upstream

### Total Effort: 14 days across 3 phases

```
Week 1-3  [==========] Phase 1: Foundation (guard, hooks, config)
Week 4-6  [==========] Phase 2: Bridge Skill (/agent-team)
Week 7-10 [==========] Phase 3: Native Integration
```

---

## 8. Risk Matrix

| # | Risk | Probability | Impact | Mitigation | Residual |
|---|------|:-----------:|:------:|------------|:--------:|
| R1 | #30703 never resolved --- custom agent defs remain ignored | Medium | High | Prompt injection workaround provides 80% of the value. Agent Teams without tool isolation is still useful for homogeneous tasks. | Medium |
| R2 | Guard cron expires after 3 days (CronCreate limitation) | High | Low | Bridge skill detects expiry and recreates the guard automatically. Document the 3-day limit. | Low |
| R3 | Prompt-injected tool restrictions ignored by teammate | Low | Medium | TaskCompleted hook catches violations post-hoc. Global validate-bash.sh blocks dangerous commands. Hybrid delegation keeps sensitive tasks on subagents. | Low |
| R4 | Token cost exceeds budget with parallel teammates | Medium | Medium | Cost circuit breaker in bridge skill. CC_TEAM_TOKEN_BUDGET config variable. Default to 3 teammates (not 5+). | Low |
| R5 | Agent Teams removed from Claude Code (experimental) | Low | High | Hybrid architecture degrades gracefully to subagent-only mode. No cognitive-core breaking changes. Phase 1 hooks are useful regardless. | Medium |
| R6 | Guard fires while lead is busy, creating queue backlog | Medium | Low | Guard uses low-priority scheduling. Tasks wait until lead is idle. No action needed --- this is by design. | Negligible |
| R7 | Team context compaction loses team state (#23620) | Medium | High | Guard detects missing teammates and alerts lead. Bridge skill stores team config to disk for recovery. | Medium |
| R8 | Cognitive-core's install.sh/update.sh cannot handle new hook types | Low | Low | TeammateIdle and TaskCompleted use the same JSON protocol as existing hooks. _lib.sh works unchanged. Only settings.json needs new event entries. | Negligible |

---

## 9. Cost Analysis

### Max Subscription Impact (Primary Concern)

The Max 20x plan ($200/month) is **not unlimited**. It uses a dual-limit system:

| Limit Type | Opus 4.6 | Sonnet 4.6 | Key Insight |
|-----------|:-:|:-:|---|
| **Weekly hours** | 24-40 hrs | 240-480 hrs | Opus gives ~10x fewer hours than Sonnet |
| **5-hour window** | ~900 messages | ~2,000 messages | Per-account, shared across all sessions |

**Critical**: Each teammate is a separate Claude instance. All teammates drain the **same subscription quota**. 3 Opus teammates = 3x quota drain = weekly limit hit in ~2 days of active use.

### Model Strategy: Sonnet Teammates (Mandatory)

**Default rule**: Only the team lead runs Opus. All teammates run Sonnet.

This is the single most impactful optimization:

| Configuration | Weekly Capacity (Max 20x) | Tasks/Week |
|--------------|:-:|:-:|
| All Opus (3 teammates) | Exhausted in ~2 days | **3-5 tasks** |
| **Opus lead + Sonnet teammates** | Sustainable all week | **8-12 tasks** |
| All Sonnet (including lead) | Maximum capacity | **15-25+ tasks** |

All cognitive-core agent definitions should set `teamModel: sonnet` by default. The `CC_TEAM_DEFAULT_MODEL` config variable enforces this at the framework level.

### Token Usage by Approach

| Approach | Context Per Agent | Agents | Total Tokens | Relative Cost | Wall-Clock Time |
|----------|:-:|:-:|:-:|:-:|:-:|
| **Subagent (current)** | ~120K | 3 sequential | ~440K | 1.0x | ~15 min |
| **Agent Teams (pure, all Opus)** | ~200K | 3 parallel | ~800K | 1.8x | ~5 min |
| **Hybrid (Opus lead + Sonnet teammates)** | ~180K | 3 parallel + guard | ~640K | 1.5x | ~6 min |

### Hybrid Cost Breakdown (Optimized for Max Plan)

| Component | Model | Token Usage | Quota Impact |
|-----------|:-----:|:-:|-------|
| Team Lead (coordinator) | Opus | ~100K | Heavy (Opus hours) |
| Teammate 1 (specialist) | **Sonnet** | ~180K | Light (Sonnet hours) |
| Teammate 2 (specialist) | **Sonnet** | ~180K | Light (Sonnet hours) |
| Teammate 3 (reviewer) | **Sonnet** | ~150K | Light (Sonnet hours) |
| Guard (10 checks x 3K) | **Sonnet** | ~30K | Negligible |
| **Total** | Mixed | **~640K** | **Sustainable on Max 20x** |

### Cost Optimization Strategies

1. **Sonnet teammates (mandatory)**: All teammates default to Sonnet via `CC_TEAM_DEFAULT_MODEL="sonnet"`. Opus reserved for lead only. This extends weekly capacity from ~3-5 to ~8-12 tasks.
2. **Teammate count**: Default to 3 teammates. Each additional adds ~180K tokens. Sweet spot is 3-4.
3. **Selective teaming**: Only use Agent Teams for truly parallel workloads. Sequential tasks are cheaper as subagents (~120K each with summarized results).
4. **Guard efficiency**: 3-minute interval at ~3K tokens per check = ~30K over 30 minutes. This is <5% overhead.
5. **Extra Usage safety net**: Enable pay-as-you-go overage with a spending cap ($50-100/month) to prevent mid-task lockout. At Sonnet API rates, 640K tokens costs ~$2-12 per task.

### Weekly Budget Planning (Max 20x)

| Day Pattern | Opus Budget | Sonnet Budget | Recommendation |
|------------|:-:|:-:|---|
| **Mon-Wed**: Heavy development | 3-4 team tasks/day | Ample | Use hybrid teams freely |
| **Thu**: Review day | 1-2 team tasks | Ample | Code review teams (all Sonnet) |
| **Fri**: Light / planning | 0-1 team tasks | Ample | Subagent-only, preserve weekend budget |
| **Weekly total** | ~8-12 team tasks | 15-25+ | Sustainable with Sonnet teammates |

### Monthly Projection (Solo Developer, Max 20x)

| Scenario | Teams/Week | Token Overhead | Fits in Max 20x? |
|----------|:-:|:-:|:-:|
| Light (2-3 teams/week) | 2.5 | ~1.6M/week | Yes, comfortably |
| Moderate (5-8 teams/week) | 6.5 | ~4.2M/week | Yes, with Sonnet teammates |
| Heavy (10+ teams/week) | 12 | ~7.7M/week | Tight — may need Extra Usage |

*With Sonnet teammates, moderate usage stays within Max 20x weekly limits without overage charges.*

---

## 10. Comparison Table

| Dimension | cognitive-core (Current) | Agent Teams (Pure) | Hybrid (Proposed) |
|-----------|:------------------------:|:-------------------:|:------------------:|
| **Orchestration** | Hub-and-spoke, sequential | Peer-to-peer, parallel | Hub routes to parallel or sequential |
| **Agent definitions** | `.claude/agents/*.md` with full frontmatter | Natural language prompts only | Definitions read, injected as prompts |
| **Tool isolation** | Deterministic (disallowedTools enforced) | None (all share lead permissions) | Prompt-based + validation hooks |
| **Parallelism** | Sequential (one subagent at a time) | True parallel (independent sessions) | Selective parallel for eligible tasks |
| **Communication** | One-way (subagent to coordinator) | Multi-directional (peer messaging) | Multi-directional within teams |
| **Task management** | Coordinator manages internally | Shared task list, self-claiming | Shared task list with guard monitoring |
| **Stuck task detection** | N/A (subagent completes or fails) | None (manual observation only) | Automated guard every 3 minutes |
| **Quality gates** | Mandatory code-standards-reviewer | TeammateIdle + TaskCompleted hooks | Both (hooks enforce cognitive-core gate) |
| **Cost per 3-agent task** | ~440K tokens | ~800K tokens | ~640K tokens |
| **Wall-clock time** | ~15 minutes | ~5 minutes | ~6 minutes |
| **Reproducibility** | High (version-controlled definitions) | Low (ephemeral prompts) | Medium-High (definitions + prompt templates) |
| **Resilience** | Subagent failures are contained | Stuck tasks block team silently | Guard detects and recovers from failures |
| **Install/update** | `install.sh` / `update.sh` with checksums | No installation concept | Extends install.sh with new components |
| **Maturity** | Production (v1.0.0) | Experimental (v2.1.32+) | Phased rollout |

---

## 11. Mapping to install.sh and update.sh

### New Components for install.sh

The following additions are required in the cognitive-core framework:

```
core/
+-- hooks/
|   +-- teammate-idle.sh          # NEW: TeammateIdle event handler
|   +-- task-completed.sh         # NEW: TaskCompleted event handler
+-- skills/
|   +-- agent-team/
|   |   +-- SKILL.md              # NEW: Bridge skill
|   |   +-- references/
|   |       +-- prompt-templates.md  # NEW: Spawn prompt templates
|   +-- team-guard/
|       +-- SKILL.md              # NEW: Guard/watchdog skill
```

### Configuration Changes

New variables in `cognitive-core.conf` (all with safe defaults):

```bash
# ===== AGENT TEAMS (EXPERIMENTAL) =====
CC_AGENT_TEAMS="false"                    # Master switch (existing, unchanged)
CC_TEAM_GUARD_INTERVAL="3m"               # Guard polling interval
CC_TEAM_STUCK_THRESHOLD="300"             # Seconds before a task is considered stuck
CC_TEAM_MAX_TEAMMATES="5"                 # Maximum teammates per team
CC_TEAM_TOKEN_BUDGET="1000000"            # Token budget ceiling before cost warning
CC_TEAM_DEFAULT_MODEL="sonnet"            # Override model for teammates (Sonnet saves ~10x quota vs Opus)
CC_TEAM_FALLBACK="subagent"              # Fallback when teams unavailable: subagent|abort
```

### install.sh Integration

```bash
# ---- Install Agent Teams components ----
if [ "${CC_AGENT_TEAMS:-false}" = "true" ]; then
    header "Installing Agent Teams integration"

    # Install team-specific hooks
    for hook in teammate-idle task-completed; do
        src="${SCRIPT_DIR}/core/hooks/${hook}.sh"
        if [ -f "$src" ]; then
            _adapter_install_hook "$src" "${hook}.sh"
            info "Installed team hook: ${hook}"
        fi
    done

    # Install team skills
    for skill in agent-team team-guard; do
        src="${SCRIPT_DIR}/core/skills/${skill}"
        if [ -d "$src" ]; then
            _adapter_install_skill "$src" "$skill"
            info "Installed team skill: ${skill}"
        fi
    done
fi
```

### settings.json Changes

The `settings.json` template needs new hook event entries for Agent Teams:

```json
{
  "hooks": {
    "TeammateIdle": [
      {
        "command": "bash .claude/hooks/teammate-idle.sh",
        "timeout": 10000
      }
    ],
    "TaskCompleted": [
      {
        "command": "bash .claude/hooks/task-completed.sh",
        "timeout": 15000
      }
    ]
  },
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

These entries are only added when `CC_AGENT_TEAMS="true"`. The adapter template (`settings.json.tmpl`) already supports conditional inclusion via `{{CC_AGENT_TEAMS}}`.

### update.sh Compatibility

No changes needed to `update.sh`. The checksum-based update logic handles new files automatically:

1. **New framework files** (teammate-idle.sh, task-completed.sh, skill files) are installed automatically as "new framework files."
2. **User-modified files** (existing hooks, agent definitions with new frontmatter fields) are preserved with a warning.
3. **Version manifest** (`version.json`) is updated with new file checksums.

The only consideration: if a user runs `update.sh` on an existing installation that did not have `CC_AGENT_TEAMS="true"` when installed, the team components will not be installed. The user must either set `CC_AGENT_TEAMS="true"` and re-run `install.sh --force`, or manually copy the new components. This is consistent with existing behavior for optional components like CI/CD.

---

## 12. Appendix: Research Sources

### Multi-Agent Orchestration Patterns

- [Temporal: Activity Timeouts and Heartbeats](https://temporal.io/blog/activity-timeouts) --- Four timeout types, 30s heartbeat recommendation
- [Temporal: Detecting Activity Failures](https://docs.temporal.io/encyclopedia/detecting-activity-failures) --- Start-to-close timeout as crash detection
- [Prefect: Worker Health Monitoring](https://docs.prefect.io/v3/concepts/workers) --- 30s heartbeat, 90s offline threshold
- [Prefect: Zombie Process Detection (#2834)](https://github.com/PrefectHQ/prefect/issues/2834) --- Stuck-in-RUNNING state analysis
- [Martin Fowler: Circuit Breaker Pattern](https://martinfowler.com/bliki/CircuitBreaker.html) --- CLOSED/OPEN/HALF-OPEN state machine
- [Kubernetes: Liveness, Readiness, and Startup Probes](https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/) --- 10-60s polling, failure thresholds
- [Multi-Agent Orchestration at Scale (gurusup.com)](https://gurusup.com/blog/multi-agent-orchestration-guide) --- Registry, router, state store, supervisor pattern

### Claude Code Agent Teams

- [Official Agent Teams Documentation](https://code.claude.com/docs/en/agent-teams) --- TeammateIdle, TaskCompleted hooks
- [Official Scheduled Tasks Documentation](https://code.claude.com/docs/en/scheduled-tasks) --- CronCreate, /loop, 3-day expiry
- [Claude Code Agent Teams Controls](https://claudefa.st/blog/guide/agents/agent-teams-controls) --- Hook configuration, quality gates
- [GitHub #30703: Custom agent definitions silently ignored](https://github.com/anthropics/claude-code/issues/30703) --- Critical blocker
- [GitHub #24316: Allow custom agents as team teammates](https://github.com/anthropics/claude-code/issues/24316) --- Feature request
- [GitHub #30140: Shared channel for agent teams](https://github.com/anthropics/claude-code/issues/30140) --- Persistent group communication
- [GitHub #23620: Agent team lost when lead's context gets compacted](https://github.com/anthropics/claude-code/issues/23620) --- Context compaction risk
- [Building a C Compiler with Agent Teams (Anthropic)](https://www.anthropic.com/engineering/building-c-compiler) --- 16-agent, $20K case study
- [QA Swarm with Agent Teams (alexop.dev)](https://alexop.dev/posts/from-tasks-to-swarms-agent-teams-in-claude-code/) --- Community testing

### Scheduling and Automation

- [Claude Code Scheduled Tasks Documentation](https://code.claude.com/docs/en/scheduled-tasks) --- CronCreate/CronDelete/CronList, /loop, 1-minute granularity
- [Winbuzzer: Claude Code Gets Cron Scheduling](https://winbuzzer.com/2026/03/09/anthropic-claude-code-cron-scheduling-background-worker-loop-xcxwbn/) --- Background worker pattern
- [SmartScope: Claude Code Cron Automation Guide](https://smartscope.blog/en/generative-ai/claude/claude-code-cron-automation-guide/) --- Cron expression reference

### Circuit Breaker and Resilience

- [Trustworthy AI Agents: Kill Switches and Circuit Breakers](https://www.sakurasky.com/blog/missing-primitives-for-trustworthy-ai-part-6/) --- AI-specific circuit breaker patterns
- [5 AI Agent Patterns (DEV Community)](https://dev.to/dpelleri/5-ai-agent-patterns-that-will-save-your-sanity-2bk9) --- Pattern-based breaker (behavior detection, not just rate)
- [Circuit Breaker Pattern for Resilient Systems (DZone)](https://dzone.com/articles/circuit-breaker-pattern-resilient-systems) --- Implementation patterns

---

*Generated by project-coordinator (dev-notes workspace orchestrator). Research by research-analyst, architecture by solution-architect.*
