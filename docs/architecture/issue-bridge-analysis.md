# Actualized Issue Bridge Analysis: cognitive-core + dev-notes

> Generated: 2026-04-02
> Context: TomasWolaschka's 16-perspective comparison in #200 settled the architectural direction.
> Decision: **issue-bridge (bash) is the default for all deterministic workflows.**

## The Decision (from #200 comment)

| Approach | Score | Role Going Forward |
|----------|:-----:|---------------------|
| **issue-bridge (bash)** | **+13** | **Default for all deterministic workflows** |
| n8n | +7 | Demoted — infrastructure/licensing overhead not justified |
| .md Skill | +5 | Kept for cognitive tasks only (LLM reasoning IS the value) |
| smoke-test (.md) | -1 | **Must migrate** — worst of both worlds |

**Principle**: "Workflow by default, agency by necessity" stays — but the workflow engine is **bash + cron**, not n8n.

Full comparison: [`docs/workflow-approaches-comparison.md`](../workflow-approaches-comparison.md)

---

## Three-Lane Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              cognitive-core v2.x Architecture                 │
│                                                              │
│  LANE 1: issue-bridge    LANE 2: .md Skill    LANE 3: Hooks │
│  (bash daemon)           (LLM cognitive)      (deterministic)│
│  Score: +13              Score: +5             Already done   │
│                                                              │
│  Deterministic work      LLM reasoning work   Safety gates   │
│  Zero tokens             Tokens justified      Zero tokens   │
│  Cron/daemon             Manual invocation     Every call     │
└─────────────────────────────────────────────────────────────┘
```

---

## Lane 1: Migrate to issue-bridge Style (bash daemon)

These issues should produce **bash daemons/scripts**, not .md skills or n8n workflows.

| Issue | Current State | issue-bridge Action |
|-------|---------------|---------------------|
| **#195** Ability-type decomposition | D-type scripts created | D-type scripts ARE issue-bridge abilities. Complete migration by removing .md orchestration layer. |
| **#168** Checkbox auto-tick | Proposed as D-type script | Build as `cc-auto-tick.sh` — pure bash, zero LLM |
| **#167** Session-resume via script | Proposed | Build as bash script with JSON state file |
| **#151** Auto-status transitions | Proposed | Board API calls via bash + cron trigger |
| **#178** WP gate (plan before code) | Proposed | PreToolUse hook check (file exists?). Already Lane 3 pattern. |
| **#157** Advisory agent routing | 3-layer context injection | **Deprioritize** — in issue-bridge world, routing is explicit `case` statements in bash |
| **#154** Orphaned subprocess cleanup | Proposed | `cc-cleanup.sh` cron job — natural bash pattern |
| **#199** Auto-branch for updates | Proposed | `cc-update-branch.sh` — git operations are bash-native |
| **#203** Release management commands | Extends project-board | Pure API calls → bash script, not .md skill |
| **#200** n8n epic | **REFRAMED** | Epic becomes: "deterministic workflow engine via issue-bridge bash patterns" |
| **#202** n8n delivery model | **REFRAMED** | Delivery is `install.sh` + bash scripts + cron. No Docker/K3s dependency. |

---

## Lane 2: Keep as .md Skill (LLM reasoning is the value)

These stay because the LLM IS the product, not overhead.

| Issue / Skill | Why .md is Correct |
|---------------|-------------------|
| **#141** cognitive-core assistant (RAG) | LLM reasoning over unstructured knowledge — cannot be bash |
| **#135** Research methodology framework | Source authority classification requires NLP judgment |
| **code-review** skill | Analyzing code quality requires language understanding |
| **acceptance-verification** (S-type steps) | Criterion assessment requires reasoning over evidence |
| **workflow-analysis** skill | Business process understanding is inherently cognitive |
| **security-baseline** skill | OWASP pattern matching against code requires LLM |

---

## Lane 3: Hooks — No Change (already deterministic)

All hook issues stay. Hooks are already bash, already deterministic, already tested.

| Issue | Status |
|-------|--------|
| **#171** ask-only enforcement bypass | P0 fix |
| **#172** @MockBean dead code | P0 fix |
| **#170** Spring Boot enforce-standards | New hook |
| **#119** validate-fetch persistence | Bug fix |
| **#176** Version cache TTL | Bug fix |
| **#187** Nonce/state-file markers | Security improvement |
| **#209** Toxic flow analysis | New hook |
| **#210** MCP-Scan integration | New hook |
| **#208** MCP Server | New capability |
| **#125-#132** EU AI Act | Governance |
| **#120** EU AI Act epic | Regulatory |

---

## What Changes from Previous Analysis

| Previous (n8n as target) | Now (issue-bridge as target) |
|--------------------------|------------------------------|
| #200 = build n8n connector | #200 = extract `cc-workflow` bash library |
| #201 = document n8n infra | #201 = **deprioritize** (n8n for internal tools, not framework delivery) |
| #202 = n8n delivery model | #202 = **close or reframe** (delivery remains `install.sh` + bash) |
| smoke-test scripts → n8n nodes | smoke-test scripts → **standalone bash daemon** (remove .md wrapper) |
| D-type → n8n Code node | D-type → **bash function in cc-workflow lib** |
| S-type → n8n LLM node | S-type → **`claude -p` call from bash** (only when justified) |
| H-type → n8n Approval node | H-type → **interactive prompt or webhook** |

---

## The smoke-test Migration (poster child)

The smoke-test skill decomposed in #195/#196 is the **first migration candidate**:

```
CURRENT (smoke-test .md + D-type scripts):
  SKILL.md orchestrates → calls scripts → LLM formats table
  Score: -1 (worst of both worlds)

TARGET (issue-bridge bash daemon):
  cc-smoke-test.sh → runs preflight.sh → runs execute-test.sh
                   → formats table (printf, no LLM)
                   → runs check-issues.sh → runs create-issue.sh
                   → cron-schedulable, zero tokens
  Score: +13
```

---

## #195 as the Bridge

The ability-type decomposition is the **classification system** for lane assignment:

| #195 Type | Lane | Implementation |
|-----------|------|----------------|
| **D** (deterministic) | Lane 1 | Bash function in `cc-workflow` lib |
| **D/S** (LLM provides input, script executes) | Lane 1 | Bash script + optional `claude -p` for input |
| **S/D** (script provides data, LLM interprets) | Lane 1 or 2 | Bash collects data, `claude -p` interprets if needed |
| **S** (pure LLM) | Lane 2 | Keep as .md skill |
| **H** (human decision) | Lane 1 | Interactive prompt or webhook |

---

## n8n's New Role

n8n is **not eliminated** — it's **repositioned**:

| Role | Status |
|------|--------|
| **Internal tooling** | `dev.n8n.mindcockpit.ai` stays for mindcockpit-internal orchestration |
| **Framework delivery** | cognitive-core does NOT depend on n8n. Customers get bash scripts. |
| **#201** | Stays open as P3 internal docs, not a framework dependency |

---

## Evolution Path

| Step | Action | Outcome |
|------|--------|---------|
| **1. Now** | Extract common patterns from dev-notes `cc-bridge-poll.sh` into `core/lib/cc-workflow.sh` | Reusable bash library: config, JSON state, logging, `--dry-run`, flock |
| **2. Next** | Convert smoke-test from .md + scripts to standalone bash daemon | First complete issue-bridge skill. Remove SKILL.md orchestration. |
| **3. Then** | Convert `lint-debt`, `project-board` deterministic commands | Three validated implementations before abstracting library |
| **4. Keep** | `.md` skills where LLM is the value | code-review, security-baseline, workflow-analysis |
| **5. Reframe** | #200 epic title | "deterministic workflow engine via issue-bridge bash patterns" |

---

## References

- [#200 — deterministic workflow engine epic](https://github.com/mindcockpit-ai/cognitive-core/issues/200)
- [#201 — n8n infrastructure docs](https://github.com/mindcockpit-ai/cognitive-core/issues/201)
- [#202 — delivery model](https://github.com/mindcockpit-ai/cognitive-core/issues/202)
- [#195 — ability-type decomposition](https://github.com/mindcockpit-ai/cognitive-core/issues/195)
- [#196 — smoke-test implementation](https://github.com/mindcockpit-ai/cognitive-core/issues/196)
- [Workflow approaches comparison](../workflow-approaches-comparison.md)
- [dev-notes issue-bridge PR](https://github.com/wolaschka/dev-notes/pull/19)
