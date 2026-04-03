# Four Workflow Approaches Compared — 16 Perspectives

> Generated: 2026-04-02
> Context: Analysis of cognitive-core skills/agents + dev-notes issue-bridge against n8n deterministic workflow principles (#200)

## Scope

Compared four approaches to implementing cognitive-core skills/agents, evaluated against 16 perspectives including licensing.

## The Four Approaches

| Style | Example | How It Works |
|-------|---------|-------------|
| **.md Skill** | `code-review`, `acceptance-verification` | Markdown + YAML frontmatter. LLM interprets natural-language steps at runtime |
| **smoke-test Style** | `smoke-test`, `lint-debt` | .md skill but every step is deterministic. LLM is pure overhead |
| **issue-bridge Style** | `cc-bridge-poll.sh` (dev-notes) | Pure bash daemon. JSON config, shared lib, cron. LLM called only where needed |
| **n8n Workflow** | Proposed in #200 | Visual JSON workflow. Deterministic nodes + optional AI nodes. Server-based |

## Overall Scorecard

| Perspective | .md Skill | smoke-test (.md) | issue-bridge (bash) | n8n |
|-------------|:---------:|:-----------------:|:-------------------:|:---:|
| Determinism | - | - | ++ | ++ |
| Cost/execution | - | -- | ++ | + |
| Authoring speed | ++ | + | - | 0 |
| Debugging | -- | -- | + | ++ |
| Scheduling | -- | -- | ++ | ++ |
| Infrastructure | ++ | ++ | ++ | -- |
| Portability | 0 | 0 | ++ | 0 |
| Testability | -- | -- | + | ++ |
| Diffability/VDI | ++ | ++ | + | -- |
| Error handling | + | 0 | + | ++ |
| Collaboration | 0 | 0 | 0 | + |
| Complexity ceiling | - | - | + | ++ |
| Context/memory | ++ | + | -- | -- |
| Security | + | + | + | ++ |
| Licensing | ++ | ++ | ++ | - |
| **Score** | **+5** | **-1** | **+13** | **+7** |
| **Overall** | Best for cognitive tasks | Worst of both worlds | **Best for deterministic workflows** | Best for teams needing visual editor |

**Legend**: ++ = 2, + = 1, 0 = 0, - = -1, -- = -2

## Detailed Analysis Per Perspective

### 1. Determinism & Reproducibility

| | .md Skill | smoke-test (.md) | issue-bridge (bash) | n8n |
|-|-----------|------------------|---------------------|-----|
| Same input → same output? | No — LLM may vary steps, formatting, tool choices | No — despite deterministic logic, LLM interprets differently each run | **Yes** — bash is deterministic | **Yes** — node graph is fixed |
| Can you guarantee step order? | No — LLM may reorder | No | Yes — script flow | Yes — graph edges |
| **Verdict** | Worst | Bad (deterministic work through non-deterministic interpreter) | **Best** | **Best** |

### 2. Cost Per Execution

| | .md Skill | smoke-test (.md) | issue-bridge (bash) | n8n |
|-|-----------|------------------|---------------------|-----|
| LLM tokens | ~15-30K | ~15-25K | ~0 (only for claude -p) | 0 (unless AI node) |
| Cost per run | $0.03-0.15 | $0.03-0.15 | $0.00 for orchestration | $0.00 + hosting |
| At 10 runs/day | $0.30-1.50/day | $0.30-1.50/day | $0.00 | $0.00 + ~$5-20/mo server |
| **Verdict** | Expensive | **Waste** (paying for LLM to do scripted work) | **Best** | Good (hosting cost) |

### 3. Authoring Speed

| | .md Skill | smoke-test (.md) | issue-bridge (bash) | n8n |
|-|-----------|------------------|---------------------|-----|
| Time to create | 30-60 min | 1-2 hours | 4-8 hours | 4-6 hours |
| Time to add a step | 2 min (write prose) | 5 min | 15-30 min (write bash) | 10-15 min (drag node) |
| Learning curve | Write markdown | Write markdown | Bash + jq + API knowledge | n8n UI + node concepts |
| **Verdict** | **Best** | Good | Slowest | Medium |

### 4. Debugging & Observability

| | .md Skill | smoke-test (.md) | issue-bridge (bash) | n8n |
|-|-----------|------------------|---------------------|-----|
| Execution trace | Scroll conversation log | Scroll conversation log | Structured log file per run | Per-node input/output/timing |
| Replay failed run | No | No | Re-run script with same input | Click "retry" in UI |
| Intermediate state | Lost after compaction | Lost after compaction | Logged per step (if coded) | Always captured |
| **Verdict** | Worst | Worst | Good (if you build logging) | **Best** |

### 5. Scheduling & Autonomy

| | .md Skill | smoke-test (.md) | issue-bridge (bash) | n8n |
|-|-----------|------------------|---------------------|-----|
| Runs without human? | No — needs `/smoke-test` | No — needs `/smoke-test` | **Yes** — cron */3 | **Yes** — built-in cron/webhook |
| Trigger types | Manual only | Manual only | cron | cron, webhook, event, manual |
| 3 AM failure alert | Nobody sees it | Nobody sees it | Logged, can add notification | Slack/email/PagerDuty native |
| **Verdict** | Cannot | Cannot | **Good** | **Best** |

### 6. Infrastructure & Dependencies

| | .md Skill | smoke-test (.md) | issue-bridge (bash) | n8n |
|-|-----------|------------------|---------------------|-----|
| Runtime needs | Claude Code | Claude Code | bash, jq, gh, flock | Node.js, PostgreSQL, Docker |
| Server required | No (runs locally) | No (runs locally) | No (cron on any box) | **Yes** (dedicated server) |
| Setup time | 0 | 0 | 5 min (run setup.sh) | 1-2 hours |
| Maintenance | None | None | Minimal (log rotation) | Updates, DB backup, monitoring |
| **Verdict** | **Best** | **Best** | Good | Heaviest |

### 7. Portability & Vendor Lock-in

| | .md Skill | smoke-test (.md) | issue-bridge (bash) | n8n |
|-|-----------|------------------|---------------------|-----|
| Locked to | Claude Code tool names | Claude Code tool names | bash (universal) | n8n node schema |
| Can switch LLM? | Yes (instructions are model-agnostic) | Yes | Yes (change `claude` binary) | Yes (AI node supports multiple) |
| Can run without vendor? | No (needs LLM runtime) | No (needs LLM runtime) | **Yes** (pure bash) | Partially (needs n8n runtime) |
| **Verdict** | Medium | Medium | **Best** | Medium |

### 8. Testability

| | .md Skill | smoke-test (.md) | issue-bridge (bash) | n8n |
|-|-----------|------------------|---------------------|-----|
| Unit test the workflow? | No framework exists | No | Yes (`bash -n`, mock inputs) | Yes (mock data, test nodes) |
| Integration test? | Run it and check output | Run it and check output | `--dry-run` flag built in | Test execution in editor |
| Schema validation? | No (prose) | No (prose) | Validate JSON config | Validate node connections |
| **Verdict** | Worst | Worst | Good | **Best** |

### 9. Diffability & VDI Readability

| | .md Skill | smoke-test (.md) | issue-bridge (bash) | n8n |
|-|-----------|------------------|---------------------|-----|
| Git diff quality | **Excellent** — readable prose | **Excellent** | Good — bash is readable | **Terrible** — coordinate noise, nested JSON |
| GitHub browser review | Perfect for VDI | Perfect for VDI | Good | Nearly unusable |
| **Verdict** | **Best** | **Best** | Good | Worst |

### 10. Error Handling & Recovery

| | .md Skill | smoke-test (.md) | issue-bridge (bash) | n8n |
|-|-----------|------------------|---------------------|-----|
| Transient failure | LLM may retry (unpredictable) | LLM may retry | Coded retry logic or fail | Retry node with backoff |
| Novel error | LLM adapts and reasons | LLM adapts | Script fails, logged | Node fails, logged |
| Dead letter / fallback | No | No | `on_fail` in code | Error workflow chains |
| **Verdict** | Best for novel errors | Medium | Good for expected errors | **Best overall** |

### 11. Collaboration

| | .md Skill | smoke-test (.md) | issue-bridge (bash) | n8n |
|-|-----------|------------------|---------------------|-----|
| Non-developers can modify? | No (needs Claude Code) | No | No (bash scripting) | **Yes** (visual editor) |
| Pair-reviewable in GitHub? | Yes | Yes | Yes | No (JSON noise) |
| **Verdict** | Medium | Medium | Medium | Best for non-devs, worst for code review |

### 12. Complexity Ceiling

| | .md Skill | smoke-test (.md) | issue-bridge (bash) | n8n |
|-|-----------|------------------|---------------------|-----|
| Max manageable steps | ~15-20 before LLM drifts | ~15-20 | ~50+ (structured code) | 100+ (visual graph) |
| Cross-workflow deps | Implicit (prose references) | Implicit | Explicit (function calls) | Explicit (sub-workflows) |
| Breaks at | Ambiguity, long instructions | Same | Bash complexity | Workflow graph complexity |
| **Verdict** | Lowest ceiling | Low | High | **Highest** |

### 13. Context & Memory

| | .md Skill | smoke-test (.md) | issue-bridge (bash) | n8n |
|-|-----------|------------------|---------------------|-----|
| Cross-step reasoning | **Excellent** — LLM holds full context | Good | None (must serialize) | None (must serialize) |
| Session persistence | Conversation-scoped | Conversation-scoped | File-based (sessions.json) | Database-backed |
| Emergent insights | Yes — LLM notices unexpected patterns | Possible | No | No |
| **Verdict** | **Best** | Good | Weakest | Weak |

### 14. Security

| | .md Skill | smoke-test (.md) | issue-bridge (bash) | n8n |
|-|-----------|------------------|---------------------|-----|
| Input sanitization | Hooks (validate-bash etc.) | Hooks | Explicit (temp files, no interpolation) | Node-level validation |
| Credential handling | Environment vars | Environment vars | Environment vars | Built-in credential store |
| Blast radius | Limited by `--allowedTools` | Limited by tools | Limited by bash permissions | Limited by node permissions |
| Audit trail | Conversation log (ephemeral) | Conversation log | Log file (persistent) | Execution log (persistent) |
| **Verdict** | Good (hooks help) | Good | Good (explicit security) | **Best** (credential store, audit) |

### 15. Migration Effort

| From → To | .md → bash | .md → n8n | bash → n8n | n8n → bash |
|-----------|-----------|-----------|-----------|-----------|
| Effort | 4-8 hours/skill | 4-6 hours/skill | 2-3 hours/workflow | 3-4 hours/workflow |
| Risk | Low (rewrite) | Medium (new platform) | Low (node mapping) | Low (script extraction) |
| Can coexist? | Yes | Yes | Yes | Yes |

### 16. Licensing

| | .md Skill | smoke-test (.md) | issue-bridge (bash) | n8n |
|-|-----------|------------------|---------------------|-----|
| License | Your code, your rules | Your code | Your code | **Sustainable Use License** (NOT open source) |
| Commercial use | Unrestricted | Unrestricted | Unrestricted | Internal use: free. Reselling/SaaS: **prohibited** |
| Enterprise features (SSO, LDAP, audit) | N/A | N/A | N/A | **Paid license required** (~$1-2K/mo) |
| Self-host community | N/A | N/A | N/A | Free, no execution limits |
| Vendor risk | Anthropic pricing | Anthropic pricing | **None** | n8n license changes |
| Truly open alternatives | — | — | — | Temporal (MIT), Airflow (Apache 2.0) |
| **Verdict** | **No restrictions** | **No restrictions** | **No restrictions** | Restricted — fine for internal use, problematic if cognitive-core is distributed to enterprises |

**Key licensing concern for cognitive-core**: If cognitive-core is distributed as a framework (which it is — marketplace, plugin installs to customer projects), and it depends on n8n, customers would need their own n8n license. This adds friction and cost to adoption. The bash approach has zero licensing implications.

## Recommendation

**issue-bridge style is the best overall approach for deterministic workflows** (+13 score). It wins on the dimensions that matter most: cost, determinism, infrastructure, portability, and licensing — without catastrophic weakness anywhere.

**.md skills remain best for cognitive tasks** where LLM reasoning IS the value: code-review, security analysis, architecture recommendations, fact extraction.

**smoke-test style is the worst of both worlds** (-1 score) — pays full LLM token cost for deterministic work, gets neither the flexibility of .md nor the efficiency of bash.

**n8n scores well (+7) but brings problematic trade-offs**: heavy infrastructure, terrible diffs (breaking the VDI workflow), and licensing restrictions that would burden cognitive-core adopters.

## Evolution Path

1. **Now**: Polish issue-bridge patterns (structured logging, `--dry-run`, standardized config/lib)
2. **Next**: Convert `smoke-test` to issue-bridge style bash daemon — validate the pattern
3. **Then**: Extract common patterns into reusable `cc-workflow` library after 3+ implementations
4. **Keep as .md**: All skills where LLM reasoning is the core value

## References

- [#200 — feat: deterministic workflow engine — rebuild agents & skills with n8n](https://github.com/mindcockpit-ai/cognitive-core/issues/200)
- [#201 — docs: document n8n infrastructure on K3s cluster](https://github.com/mindcockpit-ai/cognitive-core/issues/201)
- [dev-notes issue-bridge PR](https://github.com/wolaschka/dev-notes/pull/19)
- [n8n Sustainable Use License](https://github.com/n8n-io/n8n/blob/master/LICENSE.md)
