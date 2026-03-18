# Phase 1 Execution Plan: Agent Teams Hybrid Integration

**Date**: 2026-03-13
**Issue**: [mindcockpit-ai/cognitive-core#3](https://github.com/mindcockpit-ai/cognitive-core/issues/3)
**Phase**: 1 of 3 (Foundation)
**Feasibility Study**: [2026-03-12-agent-teams-hybrid-feasibility-study.md](2026-03-12-agent-teams-hybrid-feasibility-study.md)
**Scope**: 23 tasks across 4 tracks (A-D), organized into 8 work packages over 2 sprints

---

## Table of Contents

1. [Work Package Breakdown](#1-work-package-breakdown)
2. [Dependency Graph](#2-dependency-graph)
3. [Agent Assignments](#3-agent-assignments)
4. [Sprint Plan](#4-sprint-plan)
5. [File Templates](#5-file-templates)
6. [Definition of Done](#6-definition-of-done)
7. [Experimental Flag Dependencies](#7-experimental-flag-dependencies)
8. [Kickoff Brief](#8-kickoff-brief-solution-architect)

---

## 1. Work Package Breakdown

### WP1: Configuration Foundation

**Tasks**: C1, C5
**Effort**: 0.5 day
**Track**: C (Configuration & Definitions)

| Task | Description | Size |
|------|-------------|------|
| C1 | Add `CC_TEAM_*` variables to `cognitive-core.conf.example` | XS |
| C5 | Define `teamRole`, `teamModel`, `teamParallelizable`, `teamDependsOn`, `teamPriority`, `teamMaxConcurrent` frontmatter fields in agent definition spec | S |

**Rationale**: Config variables and the frontmatter specification must be agreed upon first. Every downstream work package references these variables and fields. This is the lowest-effort, highest-leverage starting point.

**Deliverables**:
- Updated `cognitive-core.conf.example` with `CC_TEAM_*` section
- Frontmatter field specification document (embedded in PR description, referenced by WP5)

---

### WP2: Guard Skill (`/team-guard`)

**Tasks**: A1, A2, A3, A4, A5
**Effort**: 2 days
**Track**: A (Guard Infrastructure)

| Task | Description | Size |
|------|-------------|------|
| A1 | Create `/team-guard` skill skeleton (`core/skills/team-guard/SKILL.md`) | S |
| A2 | Implement health check logic (task age, claim staleness, dependency cycles) | M |
| A3 | Implement circuit breaker state machine (CLOSED, WARN, OPEN) | M |
| A4 | Add CronCreate integration (3-minute schedule, auto-recreate on expiry) | S |
| A5 | Add token budget monitoring (`CC_TEAM_TOKEN_BUDGET`) | S |

**Rationale**: The guard skill is the core innovation of the hybrid approach. It eliminates the primary failure mode (stuck tasks) and underpins all team operations. Designing this as a single work package ensures architectural consistency across the health check, circuit breaker, and scheduling components.

**Deliverables**:
- `core/skills/team-guard/SKILL.md` -- complete skill definition

---

### WP3: Team Hooks (`TeammateIdle` + `TaskCompleted`)

**Tasks**: B1, B2, B3, B4, B5
**Effort**: 2 days
**Track**: B (Team Hooks)

| Task | Description | Size |
|------|-------------|------|
| B1 | Create `TeammateIdle` hook skeleton (`core/hooks/teammate-idle.sh`) | S |
| B2 | Implement idle work assignment (review tasks, cleanup from cognitive-core rules) | M |
| B3 | Create `TaskCompleted` hook skeleton (`core/hooks/task-completed.sh`) | S |
| B4 | Implement quality gate verification (lint, tests, standards check) | M |
| B5 | Implement tool restriction validation (detect disallowedTools violations in git diff) | M |

**Rationale**: These hooks are the enforcement layer. They must follow the established hook patterns exactly (_lib.sh sourcing, JSON stdin/stdout protocol, _cc_load_config). Grouping both hooks together allows the implementer to share patterns (both read task JSON, both use _cc_security_log, both output PostToolUse context).

**Deliverables**:
- `core/hooks/teammate-idle.sh` -- TeammateIdle event handler
- `core/hooks/task-completed.sh` -- TaskCompleted event handler

---

### WP4: Installer and Settings Integration

**Tasks**: C2, C3, C4
**Effort**: 1 day
**Track**: C (Configuration & Definitions)

| Task | Description | Size |
|------|-------------|------|
| C2 | Add interactive prompts to `install.sh` for Agent Teams configuration | S |
| C3 | Add conditional install block for team hooks/skills in `install.sh` | S |
| C4 | Update `settings.json.tmpl` with `TeammateIdle`/`TaskCompleted` hook entries + env var | S |

**Rationale**: The installer wires the new hooks and skills into target projects. It depends on WP2 and WP3 being complete (the files must exist in `core/` before `install.sh` can copy them). Grouping the three installer tasks ensures the install flow is tested end-to-end in one pass.

**Deliverables**:
- Updated `install.sh` with Agent Teams section
- Updated `core/templates/settings.json.tmpl` with team hook events

---

### WP5: Agent Definitions and Routing Documentation

**Tasks**: C6, C7
**Effort**: 1 day
**Track**: C (Configuration & Definitions)

| Task | Description | Size |
|------|-------------|------|
| C6 | Update all 9 agent `.md` files with new frontmatter fields (sensible defaults) | M |
| C7 | Update `AGENTS_README.md` template with hybrid routing documentation | S |

**Rationale**: This work package applies the frontmatter spec from WP1 across all agent definitions. It is a breadth task (9 files, mechanical changes) rather than a depth task, making it a natural fit for a single focused session. The AGENTS_README update documents the hybrid routing logic for end users.

**Agent files to update** (9 total):
1. `core/agents/project-coordinator.md`
2. `core/agents/solution-architect.md`
3. `core/agents/code-standards-reviewer.md`
4. `core/agents/test-specialist.md`
5. `core/agents/research-analyst.md`
6. `core/agents/database-specialist.md`
7. `core/agents/security-analyst.md`
8. `core/agents/skill-updater.md`
9. `core/agents/angular-specialist.md`

**Deliverables**:
- 9 updated agent `.md` files with team frontmatter
- Updated `core/templates/AGENTS_README.md.tmpl`

---

### WP6: Integration Testing

**Tasks**: D1, D2, D3, D4
**Effort**: 1.5 days
**Track**: D (Testing & Documentation)

| Task | Description | Size |
|------|-------------|------|
| D1 | Test `/team-guard` with mock stuck tasks (Agent Teams experimental flag) | M |
| D2 | Test `TeammateIdle`/`TaskCompleted` hooks with real Agent Teams session | M |
| D3 | Test `install.sh` with `CC_AGENT_TEAMS=true` (fresh install + force reinstall) | S |
| D4 | Test backward compatibility (existing installs without team config) | S |

**Rationale**: Testing is isolated into its own work package because it requires the experimental Agent Teams flag enabled and tests against all prior deliverables. D1-D2 need a live Agent Teams session. D3-D4 test the installer in both new-install and upgrade scenarios.

**Deliverables**:
- Test results report (documented in issue comment or `docs/test-reports/`)
- Bug fixes raised as sub-tasks if failures found

---

### WP7: Documentation and Close-out

**Tasks**: D5, D6
**Effort**: 0.5 day
**Track**: D (Testing & Documentation)

| Task | Description | Size |
|------|-------------|------|
| D5 | Update ROADMAP.md -- link issue #3, mark Multi-Agent Orchestration as In Progress | XS |
| D6 | Write Phase 1 completion report | S |

**Rationale**: Documentation is deferred until all implementation and testing is complete. The completion report summarizes what was built, test results, known issues, and readiness for Phase 2.

**Deliverables**:
- Updated `ROADMAP.md`
- Phase 1 completion report (in dev-notes `workspace/reports/`)

---

### WP8: Code Standards Review (Mandatory Quality Gate)

**Tasks**: Cross-cutting (not in the original 23-task list; added per cognitive-core workflow standards)
**Effort**: 0.5 day
**Track**: Cross-cutting

This work package runs incrementally after WP2, WP3, WP4, and WP5. Each review pass covers the deliverables of the preceding work package.

| Review Pass | Scope | Timing |
|-------------|-------|--------|
| Review 1 | WP2 deliverables (team-guard SKILL.md) | After WP2 completes |
| Review 2 | WP3 deliverables (teammate-idle.sh, task-completed.sh) | After WP3 completes |
| Review 3 | WP4 deliverables (install.sh changes, settings.json.tmpl) | After WP4 completes |
| Review 4 | WP5 deliverables (9 agent files, AGENTS_README template) | After WP5 completes |

**Criteria**:
- Hook scripts follow `_lib.sh` conventions (source, _cc_load_config, JSON protocol)
- SKILL.md follows frontmatter schema (name, description, user-invocable, allowed-tools, argument-hint)
- Shell scripts pass `shellcheck` (POSIX ERE patterns, no bashisms in grep, macOS + Linux compat)
- Config variables follow `CC_` naming convention
- Agent frontmatter fields are backward-compatible (all optional, sensible defaults)
- No hardcoded paths (use `$CC_PROJECT_DIR`, `$SCRIPT_DIR` etc.)

**Deliverables**:
- Review report per pass with PASS/FAIL/RECOMMENDATIONS

---

## 2. Dependency Graph

```
                      WP1: Config Foundation
                      (C1, C5) [0.5d]
                     /         |         \
                    /          |          \
                   v           v           v
    WP2: Guard Skill    WP3: Team Hooks    WP5: Agent Defs
    (A1-A5) [2d]        (B1-B5) [2d]       (C6,C7) [1d]
         |                   |                  |
         |    +--------------+                  |
         |    |                                 |
         v    v                                 |
    WP4: Installer/Settings                     |
    (C2,C3,C4) [1d]                             |
         |                                      |
         +------------------+-------------------+
                            |
                            v
                     WP6: Integration Testing
                     (D1-D4) [1.5d]
                            |
                            v
                     WP7: Docs & Close-out
                     (D5,D6) [0.5d]

    WP8: Code Standards Review (incremental, after each WP)
    ├── Review 1: after WP2
    ├── Review 2: after WP3
    ├── Review 3: after WP4
    └── Review 4: after WP5
```

### Critical Path

```
WP1 (0.5d) --> WP2 (2d) --> WP4 (1d) --> WP6 (1.5d) --> WP7 (0.5d)
                                                          Total: 5.5 days
```

WP3 and WP5 are on parallel tracks and do not extend the critical path unless they slip past WP2's completion date.

### Parallelization Opportunities

| Time Window | Parallel Tracks | Notes |
|-------------|-----------------|-------|
| After WP1 | WP2 + WP3 + WP5 | All three can start simultaneously |
| After WP2 | WP4 (if WP3 done) + WP8-R1 | WP4 needs both WP2 and WP3 |
| After WP3 | WP8-R2 | Review runs while WP4 starts |

---

## 3. Agent Assignments

| Work Package | Primary Agent | Rationale |
|--------------|---------------|-----------|
| WP1 | **skill-updater** | Config file changes, spec definition -- this is framework plumbing |
| WP2 | **solution-architect** | Novel design work: circuit breaker, health checks, CronCreate integration |
| WP3 | **solution-architect** | Hook architecture requires understanding of both Agent Teams API and cognitive-core hook protocol |
| WP4 | **skill-updater** | Installer and template changes -- directly in skill-updater's domain |
| WP5 | **skill-updater** | Mechanical updates to 9 agent files + template -- framework maintenance |
| WP6 | **test-specialist** | Integration testing with experimental features |
| WP7 | **project-coordinator** | Documentation, ROADMAP, completion report |
| WP8 | **code-standards-reviewer** | Mandatory quality gate -- review against hook/skill/config conventions |

### Workload Distribution

| Agent | Work Packages | Total Effort | Sprint |
|-------|---------------|:------------:|:------:|
| solution-architect | WP2, WP3 | 4 days | 1 |
| skill-updater | WP1, WP4, WP5 | 2.5 days | 1+2 |
| test-specialist | WP6 | 1.5 days | 2 |
| code-standards-reviewer | WP8 (4 passes) | 0.5 day | 1+2 |
| project-coordinator | WP7 | 0.5 day | 2 |

---

## 4. Sprint Plan

### Sprint 1: Core Implementation (Week 1-2)

**Goal**: Deliver the guard skill, both team hooks, config foundation, and agent definition updates.

| Day | Activity | Agent | WP |
|-----|----------|-------|----|
| Day 1 (Mon) | Config variables + frontmatter spec | skill-updater | WP1 |
| Day 2 (Tue) | Guard skill: skeleton + health check logic | solution-architect | WP2 |
| Day 3 (Wed) | Guard skill: circuit breaker + CronCreate + token budget | solution-architect | WP2 |
| Day 3 (Wed) | Agent definition updates (parallel) | skill-updater | WP5 |
| Day 4 (Thu) | Code review: guard skill | code-standards-reviewer | WP8-R1 |
| Day 4 (Thu) | TeammateIdle hook: skeleton + idle work assignment | solution-architect | WP3 |
| Day 5 (Fri) | TaskCompleted hook: skeleton + quality gate + tool restriction | solution-architect | WP3 |
| Day 6 (Mon) | AGENTS_README template + finalize agent defs | skill-updater | WP5 |
| Day 7 (Tue) | Code review: team hooks + agent defs | code-standards-reviewer | WP8-R2, R4 |

**Sprint 1 Deliverables**:
- [x] `cognitive-core.conf.example` with `CC_TEAM_*` variables
- [x] `core/skills/team-guard/SKILL.md`
- [x] `core/hooks/teammate-idle.sh`
- [x] `core/hooks/task-completed.sh`
- [x] 9 agent `.md` files with team frontmatter
- [x] `core/templates/AGENTS_README.md.tmpl` with hybrid routing
- [x] Code review reports for WP2, WP3, WP5

---

### Sprint 2: Integration and Validation (Week 3)

**Goal**: Wire everything into the installer, test end-to-end, document completion.

| Day | Activity | Agent | WP |
|-----|----------|-------|----|
| Day 8 (Wed) | Install.sh prompts + conditional block + settings.json.tmpl | skill-updater | WP4 |
| Day 9 (Thu) | Code review: installer changes | code-standards-reviewer | WP8-R3 |
| Day 9 (Thu) | Integration testing: team-guard with mock tasks | test-specialist | WP6 (D1) |
| Day 10 (Fri) | Integration testing: hooks with Agent Teams session | test-specialist | WP6 (D2) |
| Day 11 (Mon) | Integration testing: install.sh + backward compat | test-specialist | WP6 (D3, D4) |
| Day 12 (Tue) | ROADMAP update + Phase 1 completion report | project-coordinator | WP7 |

**Sprint 2 Deliverables**:
- [x] Updated `install.sh` with Agent Teams section
- [x] Updated `core/templates/settings.json.tmpl`
- [x] Test results report
- [x] Updated `ROADMAP.md`
- [x] Phase 1 completion report
- [x] Code review report for WP4

---

### Sprint Milestone Summary

| Milestone | Target | Gate |
|-----------|--------|------|
| M1: Config spec finalized | Day 1 | WP1 complete |
| M2: Guard skill complete | Day 3 | WP2 complete + WP8-R1 pass |
| M3: Team hooks complete | Day 5 | WP3 complete + WP8-R2 pass |
| M4: Agent defs updated | Day 6 | WP5 complete + WP8-R4 pass |
| M5: Installer wired | Day 8 | WP4 complete + WP8-R3 pass |
| M6: All tests pass | Day 11 | WP6 complete |
| M7: Phase 1 signed off | Day 12 | WP7 complete, all gates green |

---

## 5. File Templates

### 5.1 `cognitive-core.conf.example` -- New Section (WP1/C1)

**File**: `/Users/pewo/workspace/cognitive-core/cognitive-core.conf.example`
**Action**: Append new section after `CC_MCP_SERVERS`

```bash
# ===== AGENT TEAMS (EXPERIMENTAL) =====
# Master switch: enables Agent Teams integration (requires Claude Code experimental flag)
CC_AGENT_TEAMS="false"
# Guard polling interval (CronCreate expression component, default 3 minutes)
CC_TEAM_GUARD_INTERVAL="3m"
# Seconds before a task is considered stuck (no progress reported)
CC_TEAM_STUCK_THRESHOLD="300"
# Maximum teammates per team (including lead)
CC_TEAM_MAX_TEAMMATES="5"
# Token budget ceiling before cost circuit breaker triggers (total across all teammates)
CC_TEAM_TOKEN_BUDGET="1000000"
# Default model for teammates (Sonnet saves ~10x quota vs Opus on Max plan)
CC_TEAM_DEFAULT_MODEL="sonnet"
# Fallback strategy when Agent Teams is unavailable: subagent|abort
CC_TEAM_FALLBACK="subagent"
```

---

### 5.2 `core/skills/team-guard/SKILL.md` (WP2/A1-A5)

**File**: `/Users/pewo/workspace/cognitive-core/core/skills/team-guard/SKILL.md`
**Action**: Create new directory and file

```markdown
---
name: team-guard
description: Watchdog for Agent Teams — monitors task health, detects stuck teammates, enforces circuit breaker pattern, and tracks token budget. Runs as a CronCreate job (default every 3 minutes).
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob
argument-hint: "start | stop | status | check"
catalog_description: Agent Teams health monitor with circuit breaker and token budget tracking.
---

# Team Guard — Agent Teams Health Monitor

Watchdog service that monitors Agent Teams for stuck tasks, stale claims,
zombie teammates, and token budget overruns. Uses CronCreate for periodic
execution and implements a three-state circuit breaker (CLOSED, WARN, OPEN).

## Arguments

- `$ARGUMENTS` — subcommand:
  - `start` (default) — Create the CronCreate job and begin monitoring
  - `stop` — Delete the CronCreate job
  - `status` — Show current circuit breaker state and team health
  - `check` — Run a single health check (used by CronCreate callback)

## Configuration

From `cognitive-core.conf`:

| Variable | Default | Description |
|----------|---------|-------------|
| `CC_TEAM_GUARD_INTERVAL` | `3m` | Polling interval |
| `CC_TEAM_STUCK_THRESHOLD` | `300` | Seconds before task is stuck |
| `CC_TEAM_MAX_TEAMMATES` | `5` | Maximum teammates |
| `CC_TEAM_TOKEN_BUDGET` | `1000000` | Token ceiling |
| `CC_TEAM_DEFAULT_MODEL` | `sonnet` | Teammate model override |

## Circuit Breaker States

```
CLOSED (healthy)
  |
  | stuck_count >= 1 OR token_budget > 80%
  v
WARN (degraded)
  |
  | stuck_count >= 3 OR token_budget > 95% OR zombie detected
  v
OPEN (halted)
  |
  | manual reset OR all tasks resolved
  v
CLOSED
```

### State Transitions

| From | To | Trigger | Action |
|------|----|---------|--------|
| CLOSED | WARN | 1+ stuck tasks OR token budget > 80% | Log warning, notify lead |
| WARN | OPEN | 3+ stuck tasks OR budget > 95% OR zombie | Pause new task claims, alert lead |
| OPEN | CLOSED | Manual `/team-guard reset` OR all resolved | Resume operations, log recovery |
| WARN | CLOSED | All stuck tasks resolved AND budget < 80% | Auto-recover, log |

## Health Check Logic (`check` subcommand)

The health check runs every `CC_TEAM_GUARD_INTERVAL` via CronCreate. Each check:

1. **Task age scan**: List all claimed tasks. Flag any with age > `CC_TEAM_STUCK_THRESHOLD`.
2. **Claim staleness**: Detect tasks claimed but with no file modifications in the task's scope.
3. **Zombie detection**: Check if any teammates have disconnected (no heartbeat).
4. **Dependency cycle scan**: Detect circular waits (A waits for B, B waits for A).
5. **Token budget check**: Sum token usage across teammates, compare to `CC_TEAM_TOKEN_BUDGET`.

### Output

Each check writes results to `.claude/cognitive-core/team-guard-state.json`:

```json
{
  "timestamp": "ISO-8601",
  "circuitState": "CLOSED|WARN|OPEN",
  "stuckTasks": [],
  "zombieTeammates": [],
  "tokenUsage": { "total": 0, "budget": 1000000, "percentage": 0 },
  "dependencyCycles": [],
  "checksRun": 0,
  "lastTransition": "ISO-8601"
}
```

## CronCreate Integration (`start` subcommand)

```bash
# Create the guard cron job
# CronCreate runs the check subcommand every 3 minutes
# Note: CronCreate jobs expire after 3 days — the guard detects
# expiry on next manual invocation and offers to recreate.
```

The start command:
1. Check if a guard cron already exists (avoid duplicates)
2. Create the CronCreate job with the configured interval
3. Run an initial health check immediately
4. Log the guard start to security.log

## Stop Subcommand

Deletes the CronCreate job and clears the guard state file.

## Status Subcommand

Reads `.claude/cognitive-core/team-guard-state.json` and displays:

```
## Team Guard Status

Circuit breaker: CLOSED (healthy)
Last check: 2026-03-13T10:30:00Z (3 minutes ago)
Checks run: 47
Stuck tasks: 0
Zombie teammates: 0
Token usage: 234,000 / 1,000,000 (23.4%)
Guard cron: Active (expires 2026-03-16T10:00:00Z)
```

## Error Handling

- If `CC_AGENT_TEAMS` is not `true`: print "Agent Teams not enabled. Set CC_AGENT_TEAMS=true in cognitive-core.conf" and stop
- If CronCreate is not available: fall back to manual checks, warn user
- Guard errors never crash the framework (all checks wrapped in `_cc_guard_run` equivalent)
- State file corruption: reinitialize to CLOSED state with warning
```

---

### 5.3 `core/hooks/teammate-idle.sh` (WP3/B1-B2)

**File**: `/Users/pewo/workspace/cognitive-core/core/hooks/teammate-idle.sh`
**Action**: Create new file

```bash
#!/bin/bash
# cognitive-core hook: TeammateIdle
# Assigns review or cleanup work to idle teammates based on cognitive-core rules.
# Triggered by Claude Code when a teammate has no pending tasks.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"
_cc_load_config

# Guard: only active when Agent Teams is enabled
if [ "${CC_AGENT_TEAMS:-false}" != "true" ]; then
    exit 0
fi

# Read stdin JSON (TeammateIdle event payload)
INPUT=$(cat)

# Extract teammate context
TEAMMATE_ID=$(echo "$INPUT" | _cc_json_get ".teammate_id")
TEAMMATE_MODEL=$(echo "$INPUT" | _cc_json_get ".teammate_model")

# ---- Determine idle work assignment ----
# Priority order:
# 1. Pending code review tasks (mandatory quality gate)
# 2. Lint/format cleanup on recently modified files
# 3. Test coverage gaps on changed modules
# 4. Documentation updates for modified APIs

IDLE_TASK=""

# TODO (B2): Implement idle work assignment logic
# - Check git diff for recently modified files needing review
# - Check for lint warnings in modified files
# - Check test coverage on changed modules
# - Assign appropriate task based on teammate capabilities

if [ -n "$IDLE_TASK" ]; then
    _cc_security_log "INFO" "teammate-idle" "Assigned: ${IDLE_TASK} to teammate ${TEAMMATE_ID}"
fi

# Output context for the idle teammate
if [ -n "$IDLE_TASK" ]; then
    _cc_json_posttool_context "Idle teammate assignment: ${IDLE_TASK}"
fi

exit 0
```

---

### 5.4 `core/hooks/task-completed.sh` (WP3/B3-B5)

**File**: `/Users/pewo/workspace/cognitive-core/core/hooks/task-completed.sh`
**Action**: Create new file

```bash
#!/bin/bash
# cognitive-core hook: TaskCompleted
# Enforces quality gates on completed teammate tasks:
# 1. Lint verification on modified files
# 2. Tool restriction validation (disallowedTools from agent frontmatter)
# 3. Test execution on affected modules
# Exits 0 = accept, Exit 2 = reject task completion
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"
_cc_load_config

# Guard: only active when Agent Teams is enabled
if [ "${CC_AGENT_TEAMS:-false}" != "true" ]; then
    exit 0
fi

# Read stdin JSON (TaskCompleted event payload)
INPUT=$(cat)

# Extract task context
TASK_ID=$(echo "$INPUT" | _cc_json_get ".task_id")
TEAMMATE_ID=$(echo "$INPUT" | _cc_json_get ".teammate_id")
AGENT_TYPE=$(echo "$INPUT" | _cc_json_get ".agent_type")

VIOLATIONS=""

# ---- Quality Gate 1: Lint verification ----
# TODO (B4): Run CC_LINT_COMMAND on files modified by this task
# - Get list of modified files from git diff
# - Filter by CC_LINT_EXTENSIONS
# - Run lint, collect failures

# ---- Quality Gate 2: Tool restriction validation ----
# TODO (B5): Check if teammate respected disallowedTools
# - Read agent definition for AGENT_TYPE
# - Parse disallowedTools from frontmatter
# - Check git diff: did a read-only agent modify files?
# - Check git log: did a no-WebFetch agent fetch URLs?

# ---- Quality Gate 3: Test execution ----
# TODO (B4): Run tests if CC_TEST_COMMAND is configured
# - Identify test files corresponding to modified source files
# - Run targeted tests
# - Collect failures

# ---- Decision ----
if [ -n "$VIOLATIONS" ]; then
    _cc_security_log "WARN" "task-completed-rejected" "Task ${TASK_ID} by ${TEAMMATE_ID}: ${VIOLATIONS}"
    # Exit 2 = reject task completion (teammate must fix violations)
    echo "{\"status\": \"rejected\", \"reason\": \"${VIOLATIONS}\"}"
    exit 2
fi

_cc_security_log "INFO" "task-completed-accepted" "Task ${TASK_ID} by ${TEAMMATE_ID}: all gates passed"
exit 0
```

---

### 5.5 `install.sh` -- Agent Teams Section (WP4/C2-C3)

**File**: `/Users/pewo/workspace/cognitive-core/install.sh`
**Action**: Insert after the existing skills installation block (around line 408) and before the language pack section (line 411)

```bash
# ---- Install Agent Teams components (conditional) ----
if [ "${CC_AGENT_TEAMS:-false}" = "true" ]; then
    header "Installing Agent Teams integration"

    # Install team-specific hooks
    for hook in teammate-idle task-completed; do
        src="${SCRIPT_DIR}/core/hooks/${hook}.sh"
        if [ -f "$src" ]; then
            _adapter_install_hook "$src" "${hook}.sh"
            info "Installed team hook: ${hook}"
        else
            warn "Team hook not found: ${hook} (skipped)"
        fi
    done

    # Install team skills
    for skill in team-guard; do
        src="${SCRIPT_DIR}/core/skills/${skill}"
        if [ -d "$src" ]; then
            _adapter_install_skill "$src" "$skill"
            info "Installed team skill: ${skill}"
        else
            warn "Team skill not found: ${skill} (skipped)"
        fi
    done

    info "Agent Teams components installed. Enable with CC_AGENT_TEAMS=true in cognitive-core.conf."
fi
```

**Interactive prompts** (insert in the interactive setup section, after `CC_MCP_SERVERS`):

```bash
# Agent Teams (experimental)
echo ""
prompt_choice CC_AGENT_TEAMS "Enable Agent Teams (experimental)?" "true|false" "false"
if [ "$CC_AGENT_TEAMS" = "true" ]; then
    prompt_default CC_TEAM_GUARD_INTERVAL "Guard polling interval" "3m"
    prompt_default CC_TEAM_STUCK_THRESHOLD "Stuck task threshold (seconds)" "300"
    prompt_default CC_TEAM_MAX_TEAMMATES "Max teammates per team" "5"
    prompt_default CC_TEAM_TOKEN_BUDGET "Token budget ceiling" "1000000"
    prompt_choice CC_TEAM_DEFAULT_MODEL "Teammate model" "sonnet|opus" "sonnet"
    prompt_choice CC_TEAM_FALLBACK "Fallback when teams unavailable" "subagent|abort" "subagent"
else
    CC_TEAM_GUARD_INTERVAL="3m"
    CC_TEAM_STUCK_THRESHOLD="300"
    CC_TEAM_MAX_TEAMMATES="5"
    CC_TEAM_TOKEN_BUDGET="1000000"
    CC_TEAM_DEFAULT_MODEL="sonnet"
    CC_TEAM_FALLBACK="subagent"
fi
```

---

### 5.6 `core/templates/settings.json.tmpl` -- Team Hook Entries (WP4/C4)

**File**: `/Users/pewo/workspace/cognitive-core/core/templates/settings.json.tmpl`
**Action**: Add conditional entries. The adapter that processes this template must emit TeammateIdle/TaskCompleted blocks only when `CC_AGENT_TEAMS=true`.

Expected additions to the hooks section:

```json
    "TeammateIdle": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/teammate-idle.sh",
            "timeout": 10000
          }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/task-completed.sh",
            "timeout": 15000
          }
        ]
      }
    ]
```

Expected addition to the env section:

```json
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "{{CC_AGENT_TEAMS_ENV}}"
```

Where `CC_AGENT_TEAMS_ENV` resolves to `"1"` when `CC_AGENT_TEAMS=true`, empty string otherwise.

---

### 5.7 Agent Frontmatter Extension (WP5/C5-C6)

**File**: All 9 agent `.md` files in `core/agents/`
**Action**: Add team-related frontmatter fields after existing fields

Example for `code-standards-reviewer.md`:

```yaml
---
name: code-standards-reviewer
description: Use this agent when you need to review recently written code...
model: sonnet
catalog_description: Reviews code against project conventions and CLAUDE.md guidelines.
disallowedTools:
  - WebFetch
  - WebSearch
# --- Agent Teams fields (optional, backward-compatible) ---
teamRole: reviewer
teamParallelizable: false
teamDependsOn:
  - solution-architect
  - test-specialist
teamMaxConcurrent: 1
teamPriority: 90
teamModel: sonnet
---
```

Default values per agent:

| Agent | teamRole | teamParallelizable | teamDependsOn | teamPriority | teamModel |
|-------|----------|--------------------|---------------|:------------:|-----------|
| project-coordinator | lead | false | [] | 1 | opus |
| solution-architect | specialist | true | [] | 20 | sonnet |
| code-standards-reviewer | reviewer | false | [solution-architect, test-specialist] | 90 | sonnet |
| test-specialist | specialist | true | [solution-architect] | 50 | sonnet |
| research-analyst | specialist | true | [] | 30 | sonnet |
| database-specialist | specialist | true | [] | 40 | sonnet |
| security-analyst | specialist | true | [] | 35 | sonnet |
| skill-updater | specialist | true | [] | 60 | sonnet |
| angular-specialist | specialist | true | [] | 45 | sonnet |

---

### 5.8 AGENTS_README.md.tmpl -- Hybrid Routing Section (WP5/C7)

**File**: `/Users/pewo/workspace/cognitive-core/core/templates/AGENTS_README.md.tmpl`
**Action**: Append new section

```markdown
## Hybrid Routing (Agent Teams)

When `CC_AGENT_TEAMS="true"`, the project-coordinator uses a hybrid routing strategy
to decide between subagent delegation (sequential) and Agent Teams (parallel).

### Decision Logic

```
IF task requires:
├── Tool isolation (disallowedTools enforcement)  → SUBAGENT
├── Read-only analysis (research, security scan)  → SUBAGENT
├── Single specialist domain                      → SUBAGENT
├── Multiple specialists, parallelizable          → AGENT TEAM
├── Implementation + testing in parallel          → AGENT TEAM
└── Review after implementation                   → SUBAGENT (quality gate)
```

### Agent Team Frontmatter Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `teamRole` | string | null | Role: lead, specialist, reviewer, observer |
| `teamParallelizable` | boolean | true | Can run in parallel with other teammates |
| `teamMaxConcurrent` | integer | 1 | Max concurrent instances |
| `teamDependsOn` | list | [] | Agents that must complete first |
| `teamPriority` | integer | 50 | Task claim priority (1=highest) |
| `teamModel` | string | sonnet | Model override for teammates |

### Cost Strategy

All teammates default to Sonnet (`CC_TEAM_DEFAULT_MODEL`).
Only the team lead (project-coordinator) uses Opus.
This extends weekly capacity on Max 20x from ~3-5 to ~8-12 tasks.
```

---

## 6. Definition of Done

### WP1: Configuration Foundation

- [ ] `CC_TEAM_*` variables added to `cognitive-core.conf.example` with comments
- [ ] All variable names follow `CC_TEAM_` prefix convention
- [ ] Default values are safe (teams disabled, Sonnet model, subagent fallback)
- [ ] Frontmatter field specification documented with types, defaults, and examples
- [ ] Existing config variables unchanged (backward compatible)

### WP2: Guard Skill

- [ ] `core/skills/team-guard/SKILL.md` exists with complete frontmatter
- [ ] Frontmatter follows schema: name, description, user-invocable, allowed-tools, argument-hint
- [ ] All 4 subcommands documented: start, stop, status, check
- [ ] Circuit breaker state transitions defined and documented
- [ ] Health check logic covers: task age, claim staleness, zombies, dependency cycles, token budget
- [ ] CronCreate integration documented with 3-day expiry handling
- [ ] State file format defined (JSON schema)
- [ ] Error handling covers: teams not enabled, CronCreate unavailable, state corruption
- [ ] WP8 Review 1: PASS

### WP3: Team Hooks

- [ ] `core/hooks/teammate-idle.sh` exists and is executable
- [ ] `core/hooks/task-completed.sh` exists and is executable
- [ ] Both hooks source `_lib.sh` and call `_cc_load_config`
- [ ] Both hooks read stdin JSON and extract fields via `_cc_json_get`
- [ ] Both hooks guard on `CC_AGENT_TEAMS=true` (no-op when false)
- [ ] `teammate-idle.sh` assigns review/cleanup work based on cognitive-core quality rules
- [ ] `task-completed.sh` runs lint verification on modified files
- [ ] `task-completed.sh` validates tool restrictions from agent frontmatter
- [ ] `task-completed.sh` exits 0 (accept) or 2 (reject) based on violations
- [ ] Both hooks log to security.log via `_cc_security_log`
- [ ] Shell scripts pass `shellcheck` with POSIX ERE patterns
- [ ] WP8 Review 2: PASS

### WP4: Installer and Settings

- [ ] `install.sh` has interactive prompts for all `CC_TEAM_*` variables
- [ ] `install.sh` conditionally installs team hooks and skills when `CC_AGENT_TEAMS=true`
- [ ] `install.sh` skips team components when `CC_AGENT_TEAMS=false` (no errors)
- [ ] `settings.json.tmpl` includes TeammateIdle and TaskCompleted hook entries (conditional)
- [ ] `settings.json.tmpl` includes `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env var (conditional)
- [ ] Template conditional logic is clean (no orphan commas, valid JSON output)
- [ ] WP8 Review 3: PASS

### WP5: Agent Definitions and Routing

- [ ] All 9 agent `.md` files updated with team frontmatter fields
- [ ] All new fields are optional (agents work without them)
- [ ] Default values are sensible per agent role (see Section 5.7 table)
- [ ] `code-standards-reviewer` has `teamDependsOn: [solution-architect, test-specialist]`
- [ ] `project-coordinator` has `teamRole: lead` and `teamModel: opus`
- [ ] AGENTS_README.md.tmpl includes hybrid routing section
- [ ] WP8 Review 4: PASS

### WP6: Integration Testing

- [ ] `/team-guard check` runs without errors (mock scenario)
- [ ] `/team-guard start`/`stop`/`status` subcommands work
- [ ] `TeammateIdle` hook fires and returns valid JSON
- [ ] `TaskCompleted` hook accepts clean completions (exit 0)
- [ ] `TaskCompleted` hook rejects violations (exit 2)
- [ ] `install.sh` with `CC_AGENT_TEAMS=true` installs all team components
- [ ] `install.sh --force` over existing install preserves user modifications
- [ ] Existing installs without `CC_AGENT_TEAMS` config are unaffected
- [ ] Test results documented in issue comment or report file

### WP7: Documentation and Close-out

- [ ] `ROADMAP.md` updated: issue #3 linked, Multi-Agent Orchestration marked In Progress
- [ ] Phase 1 completion report written with: summary, test results, known issues, Phase 2 readiness
- [ ] Issue #3 comment posted with Phase 1 results

### WP8: Code Standards Review

- [ ] Review 1 (WP2): Guard skill follows skill pattern conventions
- [ ] Review 2 (WP3): Hooks follow _lib.sh conventions, shellcheck clean
- [ ] Review 3 (WP4): Installer changes are backward compatible, JSON template valid
- [ ] Review 4 (WP5): Frontmatter is syntactically valid YAML, all fields optional

---

## 7. Experimental Flag Dependencies

### Tasks Requiring Agent Teams Experimental Flag

The following tasks need the Claude Code experimental Agent Teams flag enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`):

| Task | Why | Can Be Developed Without Flag? |
|------|-----|:------------------------------:|
| D1 | Testing team-guard with real Agent Teams session | No |
| D2 | Testing TeammateIdle/TaskCompleted with real teammates | No |

### Tasks Safe Without the Flag

All other tasks (A1-A5, B1-B5, C1-C7, D3-D6) can be developed and tested without the experimental flag. The hooks and skills are designed to no-op gracefully when `CC_AGENT_TEAMS=false`.

### How to Enable the Flag

The flag is set via environment variable or `settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Or via shell:

```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

### Risk: Flag Removal

If Anthropic removes or changes the experimental flag, the impact is limited to D1 and D2 (integration tests). All framework components (guard skill, hooks, config, installer) remain functional as standalone cognitive-core extensions. They simply wait for the upstream feature to become available.

---

## 8. Kickoff Brief: solution-architect

This is the ready-to-use handoff prompt for the first agent to start work on WP2 (Guard Skill).

```
AGENT TEAMS PHASE 1 — WORK PACKAGE 2 KICKOFF
=============================================
From: project-coordinator
To: solution-architect
Date: 2026-03-13
Issue: mindcockpit-ai/cognitive-core#3

CONTEXT
-------
You are implementing the /team-guard skill for the cognitive-core framework.
This is the core innovation of the hybrid Agent Teams integration — a watchdog
that eliminates stuck tasks, the primary failure mode of Agent Teams deployments.

The feasibility study is at:
/Users/pewo/workspace/dev-notes/workspace/reports/2026-03-12-agent-teams-hybrid-feasibility-study.md

The execution plan is at:
/Users/pewo/workspace/dev-notes/workspace/reports/2026-03-13-agent-teams-phase1-execution-plan.md

PREREQUISITE
------------
WP1 (Config Foundation) must be complete before you start. Verify that
cognitive-core.conf.example contains CC_TEAM_* variables. If not, the
skill-updater needs to complete WP1 first.

YOUR TASKS (A1-A5)
-------------------
1. Create the skill directory: core/skills/team-guard/
2. Create SKILL.md following the template in Section 5.2 of the execution plan
3. Implement the complete skill definition covering:
   - 4 subcommands: start, stop, status, check
   - Health check logic: task age, claim staleness, zombie detection, dependency cycles
   - Circuit breaker state machine: CLOSED → WARN → OPEN (with transition rules)
   - CronCreate integration: 3-minute schedule, auto-recreate on 3-day expiry
   - Token budget monitoring: read CC_TEAM_TOKEN_BUDGET, compute usage percentage
   - State file: .claude/cognitive-core/team-guard-state.json

PATTERNS TO FOLLOW
------------------
Study these existing skills for format and conventions:
- /Users/pewo/workspace/cognitive-core/core/skills/project-board/SKILL.md (complex skill with subcommands)
- /Users/pewo/workspace/cognitive-core/core/skills/smoke-test/SKILL.md (config-driven, JSON output)

Key conventions:
- YAML frontmatter: name, description, user-invocable: true, allowed-tools, argument-hint
- $ARGUMENTS for subcommand parsing
- Configuration section referencing cognitive-core.conf variables
- Error handling section at the end
- No hardcoded paths — use CC_PROJECT_DIR and relative references

DESIGN CONSTRAINTS
------------------
- CronCreate jobs expire after 3 days. The guard must detect this and offer
  to recreate. Document this limitation clearly.
- The guard must never crash the framework. All checks should be defensive
  (equivalent to _cc_guard_run wrapper pattern from _lib.sh).
- State file must be valid JSON at all times. Use atomic writes (write to
  .tmp, then mv).
- Token budget monitoring may need to be estimated (exact token counts are
  not always available). Document the estimation approach.

DEFINITION OF DONE
------------------
See WP2 DoD in Section 6 of the execution plan. After completion, the
code-standards-reviewer will perform WP8 Review 1.

AFTER COMPLETION
----------------
Notify the project-coordinator that WP2 is complete. Then proceed to WP3
(Team Hooks) — same agent, same session if context allows.
```

---

## Appendix A: Task-to-Work-Package Mapping

| Task | Track | Description | WP | Sprint |
|------|-------|-------------|:--:|:------:|
| A1 | A | Create team-guard skill skeleton | WP2 | 1 |
| A2 | A | Health check logic | WP2 | 1 |
| A3 | A | Circuit breaker state machine | WP2 | 1 |
| A4 | A | CronCreate integration | WP2 | 1 |
| A5 | A | Token budget monitoring | WP2 | 1 |
| B1 | B | TeammateIdle hook skeleton | WP3 | 1 |
| B2 | B | Idle work assignment logic | WP3 | 1 |
| B3 | B | TaskCompleted hook skeleton | WP3 | 1 |
| B4 | B | Quality gate verification | WP3 | 1 |
| B5 | B | Tool restriction validation | WP3 | 1 |
| C1 | C | CC_TEAM_* config variables | WP1 | 1 |
| C2 | C | install.sh interactive prompts | WP4 | 2 |
| C3 | C | install.sh conditional install block | WP4 | 2 |
| C4 | C | settings.json.tmpl team entries | WP4 | 2 |
| C5 | C | Agent frontmatter field spec | WP1 | 1 |
| C6 | C | Update 9 agent .md files | WP5 | 1 |
| C7 | C | Update AGENTS_README template | WP5 | 1 |
| D1 | D | Test team-guard with mock tasks | WP6 | 2 |
| D2 | D | Test hooks with Agent Teams | WP6 | 2 |
| D3 | D | Test install.sh | WP6 | 2 |
| D4 | D | Test backward compatibility | WP6 | 2 |
| D5 | D | Update ROADMAP.md | WP7 | 2 |
| D6 | D | Phase 1 completion report | WP7 | 2 |

---

## Appendix B: Risk Register (Phase 1 Specific)

| ID | Risk | Probability | Impact | Mitigation | Owner |
|----|------|:-----------:|:------:|------------|-------|
| P1-R1 | TeammateIdle/TaskCompleted JSON protocol differs from documentation | Medium | High | Read Claude Code source/docs before implementing; test early with experimental flag | test-specialist |
| P1-R2 | CronCreate not available in user's Claude Code version | Medium | Medium | Guard skill degrades to manual /team-guard check; document version requirement | solution-architect |
| P1-R3 | settings.json conditional logic breaks JSON syntax | Low | High | Validate generated JSON with jq in tests; code review focuses on template output | code-standards-reviewer |
| P1-R4 | Agent frontmatter YAML parser chokes on list fields (teamDependsOn) | Low | Medium | Test with Claude Code's actual YAML parser; use simple string format as fallback | test-specialist |
| P1-R5 | Scope creep into Phase 2 (bridge skill work pulled forward) | Medium | Medium | Strict WP scoping; project-coordinator blocks Phase 2 tasks until Phase 1 signed off | project-coordinator |

---

*Generated by project-coordinator (dev-notes workspace orchestrator). Issue: mindcockpit-ai/cognitive-core#3.*
