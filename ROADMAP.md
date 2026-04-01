# cognitive-core Roadmap

## Vision

A portable, vendor-agnostic AI-augmented development framework that governs the entire development lifecycle — from research quality to production deployment. Multi-adapter, multi-provider, enterprise-ready.

---

## v1.0.0 — Released (2026-03-18)

[Release Notes](https://github.com/mindcockpit-ai/cognitive-core/releases/tag/v1.0.0) | [CHANGELOG](./CHANGELOG.md)

### Industry Firsts (Novel — no equivalent in any competing framework)

| Feature | Description | Research Paper |
|---------|-------------|---------------|
| **Source Authority Model (T1-T5)** | 5-tier research quality classification. AI slop (T5) auto-discarded | [Paper](docs/research/source-authority-model.md) |
| **Team-Aware Estimation** | Tasks tagged (human/AI/human+AI). Human review = critical path | [Paper](docs/research/team-aware-estimation.md) |
| **Graduated Fitness Gates** | Quality thresholds 60% → 95% across pipeline | [Paper](docs/research/graduated-fitness-gates.md) |
| **Recursive Epic Verification** | Criteria-level verification across parent-child issue hierarchy | [Paper](docs/research/recursive-epic-verification.md) |

### Core Framework

| Feature | Details |
|---------|---------|
| 10 specialist agents | Hub-and-spoke coordination, smart delegation, least-privilege |
| 47 composable skills | 20 core + 26 language-pack + 1 database-pack |
| 9 security hooks | validate-bash, validate-read, validate-write, validate-fetch, setup-env, compact-reminder, post-edit-lint, angular/spring-boot version guards |
| 11 rules | 1 core (testing) + 10 language-specific (path-scoped with YAML frontmatter) |
| 11 language packs | Angular, React, Spring Boot, Python, Perl, Node.js, Go, Rust, C#, Java, Struts+JSP |
| 3 database packs | PostgreSQL, Oracle, MySQL |

### Multi-Adapter

| Adapter | Platform | AI Model | Status |
|---------|----------|----------|--------|
| claude | Claude Code CLI | Claude (any) | Production |
| aider | Aider + Ollama | Local models (Mistral, Llama) | Production |
| intellij | IntelliJ + DevoxxGenie | Any provider | Production |
| vscode | VS Code (Copilot, Continue.dev, Cline) | Any provider | Production (v1.3.0) |

### Enterprise Governance

| Feature | Details |
|---------|---------|
| Board workflow | 7-column lifecycle with enforced transition matrix |
| SOX compliance | Different-approver enforcement, dual approval |
| WIP limits | Configurable per-column |
| Blocked state | Label-based impediment tracking |
| Agile metrics | Cycle time, lead time, throughput, flow efficiency |
| Approval gate | CI automation respects human approval (stops at To Be Tested) |
| Multi-provider | GitHub Projects, Jira, YouTrack |
| PM recipes | 7 role-based workflows (Scrum Master, PM, QA, CTO, BA, Compliance, Release) |

### Quality & Certification

| Metric | Value |
|--------|-------|
| Test suites | 16 suites, 809+ assertions, all passing |
| Claude Certified Architect | 959/1000 (Grade A, all 5 domains) |
| Workflow Maturity Audit | 4.79/5.0 (+63% above industry average) |

### Infrastructure

| Feature | Details |
|---------|---------|
| release-please | Automated semantic versioning from conventional commits |
| CI pipeline | 7 jobs, cross-platform (macOS + Ubuntu), JUnit reports |
| AI moderator | GitHub spam/slop detection on issues and comments |
| Website auto-update | framework-health.json pushed from CI to multivac42.ai |

---

## v1.x — In Progress

| # | Feature | Priority | Size | Status |
|---|---------|----------|------|--------|
| [#81](https://github.com/mindcockpit-ai/cognitive-core/issues/81) | VS Code adapter (Copilot + Continue.dev + Cline) | P1-high | L | **Shipped (v1.3.0)** |
| [#82](https://github.com/mindcockpit-ai/cognitive-core/issues/82) | Eclipse adapter (Copilot + EclipseLlama) | P2-medium | XL | Feasibility complete |
| [#83](https://github.com/mindcockpit-ai/cognitive-core/issues/83) | Cursor IDE adapter | P2-medium | M | Feasibility complete |
| [#84](https://github.com/mindcockpit-ai/cognitive-core/issues/84) | Windsurf adapter (Cascade + workflows) | P3-low | M | Feasibility complete |
| [#85](https://github.com/mindcockpit-ai/cognitive-core/issues/85) | Neovim adapter (codecompanion + avante) | P3-low | L | Feasibility complete |
| [#93](https://github.com/mindcockpit-ai/cognitive-core/issues/93) | Integration test suite — end-to-end verification | P1-high | XL | Planned |
| [#120](https://github.com/mindcockpit-ai/cognitive-core/issues/120) | **EU AI Act compliance — 13-issue epic** (Art. 50 + voluntary Art. 9-15) | P0-critical | XL | Epic planned |
| [#100](https://github.com/mindcockpit-ai/cognitive-core/issues/100) | Step-by-step tutorials | P1-high | L | Planned |
| [#97](https://github.com/mindcockpit-ai/cognitive-core/issues/97) | Introduction video + video course | P2-medium | L | Planned |

### EU AI Act Compliance Epic ([#120](https://github.com/mindcockpit-ai/cognitive-core/issues/120))

No AI coding framework — commercial or open source — addresses EU AI Act compliance. cognitive-core is building it.

| # | Feature | Pillar | Status |
|---|---------|--------|--------|
| [#121](https://github.com/mindcockpit-ai/cognitive-core/issues/121) | AI interaction disclosure in session startup | Art. 50 Transparency | Planned |
| [#122](https://github.com/mindcockpit-ai/cognitive-core/issues/122) | AI identity markers in agent YAML frontmatter | Art. 50 Transparency | Planned |
| [#123](https://github.com/mindcockpit-ai/cognitive-core/issues/123) | Git trailers for AI provenance | Art. 50 Transparency | Planned |
| [#124](https://github.com/mindcockpit-ai/cognitive-core/issues/124) | System card — capabilities, limitations, failure modes | Art. 9-15 Risk Mgmt | Planned |
| [#125](https://github.com/mindcockpit-ai/cognitive-core/issues/125) | Structured JSON Lines audit log format | Art. 9-15 Risk Mgmt | Planned |
| [#126](https://github.com/mindcockpit-ai/cognitive-core/issues/126) | Date-based non-destructive log rotation | Art. 9-15 Risk Mgmt | Planned |
| [#127](https://github.com/mindcockpit-ai/cognitive-core/issues/127) | Per-file SHA-256 integrity checksums for audit logs | Art. 9-15 Risk Mgmt | Planned |
| [#128](https://github.com/mindcockpit-ai/cognitive-core/issues/128) | Emergency stop mechanism via marker file | Art. 9-15 Risk Mgmt | Planned |
| [#129](https://github.com/mindcockpit-ai/cognitive-core/issues/129) | Minimum security level enforcement | Art. 9-15 Risk Mgmt | Planned |
| [#130](https://github.com/mindcockpit-ai/cognitive-core/issues/130) | Adversarial hook bypass testing suite | Art. 9-15 Risk Mgmt | Planned |
| [#131](https://github.com/mindcockpit-ai/cognitive-core/issues/131) | Art. 95 Code of Conduct for voluntary adoption | Art. 95 Governance | Planned |
| [#132](https://github.com/mindcockpit-ai/cognitive-core/issues/132) | Audit log schema + SIEM integration guide | Art. 95 Governance | Planned |

---

## Enterprise Customization — Available

Your stack. Your rules. Your workflow. [Research paper](docs/research/enterprise-customization-model.md)

### Available Now (Professional Services)

| Offering | What You Get | Effort |
|----------|-------------|--------|
| **Stack Assessment** | Audit + config + custom rules for your standards | 1-2 days |
| **Custom Language Pack** | pack.conf + rules + skills + fitness checks for your stack | 2-5 days |
| **Custom Agents** | Specialist agents for proprietary APIs and frameworks | 1-3 days |
| **Custom Skills** | Process automation for your deployment, review, testing workflows | 3-8 days |
| **Custom Hooks** | Security policies specific to your organization | 1-3 days |
| **Team Training** | Half-day or full-day workshop | 0.5-1 day |

### In Development

| # | Feature | Description |
|---|---------|-------------|
| [#110](https://github.com/mindcockpit-ai/cognitive-core/issues/110) | Enterprise Pack Manifest | Bundle custom components into installable, updateable packs |
| | Private Pack Registry | Point update.sh to private git repo for enterprise-specific updates |
| | Config Overlay | Enterprise defaults + project-specific overrides |

### Planned (Premium)

| Feature | Description |
|---------|-------------|
| Fleet management | Orchestrate framework updates across entire organizations |
| Compliance dashboards | Audit artifacts for SOX, ISO 27001, ITIL |
| Custom adapters | VS Code, Eclipse, or any IDE your team uses |
| On-premises deployment | Full data sovereignty |
| EU AI Act alignment | 13-issue compliance epic in pipeline — see [#120](https://github.com/mindcockpit-ai/cognitive-core/issues/120) |
| Audit log export | Security events to external SIEM (Splunk, ELK) |

---

## Research

| Topic | Paper | Status |
|-------|-------|--------|
| Source Authority Model | [docs/research/source-authority-model.md](docs/research/source-authority-model.md) | Published |
| Team-Aware Estimation | [docs/research/team-aware-estimation.md](docs/research/team-aware-estimation.md) | Published |
| Graduated Fitness Gates | [docs/research/graduated-fitness-gates.md](docs/research/graduated-fitness-gates.md) | Published |
| Recursive Epic Verification | [docs/research/recursive-epic-verification.md](docs/research/recursive-epic-verification.md) | Published |
| Board Workflow Governance | [docs/research/board-workflow-governance.md](docs/research/board-workflow-governance.md) | Published |
| Workflow Maturity Audit v2 | [docs/research/workflow-maturity-audit-v2.md](docs/research/workflow-maturity-audit-v2.md) | Published |
| DNA-Inspired Skill Storage | [docs/research/dna-inspired-storage.md](docs/research/dna-inspired-storage.md) | Theoretical |
| IP Protection Strategy | [#98](https://github.com/mindcockpit-ai/cognitive-core/issues/98) | Planned |
| Consultant Model Feasibility | [#96](https://github.com/mindcockpit-ai/cognitive-core/issues/96) | Planned |
| EU AI Act Compliance | [Epic #120](https://github.com/mindcockpit-ai/cognitive-core/issues/120) — 13 issues, 3 pillars | In Pipeline |

---

## Changelog

| Version | Date | Highlights |
|---------|------|------------|
| v1.3.0 | 2026-03-28 | VS Code adapter, inter-session coordination, closure guard, prompt linter, 809+ assertions |
| v1.2.0 | 2026-03-23 | Gitignore policy (16 IDEs + 11 language packs), 16 suites / 809 assertions |
| v1.1.0 | 2026-03-18 | Shared MCP server, batch-review skill, W3C PROV provenance, A2A state machine |
| v1.0.0 | 2026-03-18 | 4 novel features, enterprise governance, 3 adapters, 959/1000 certification |
| v0.2.0 | 2026-02-17 | Security guard, connected projects, CI/CD, landing page |
| v0.1.0 | 2026-02 | Initial release with core architecture |

---

*Last updated: 2026-03-30*
