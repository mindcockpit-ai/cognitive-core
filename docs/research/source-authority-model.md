# Source Authority Model (T1-T5)

**Status**: Implemented | **Category**: Novel — no equivalent in any AI coding framework
**Location**: `core/agents/research-analyst.md`, `core/agents/project-coordinator.md`

---

## Problem

AI agents browse the web, search GitHub, and read Stack Overflow to inform development decisions. But not all sources are equal. A promotional blog post from a tool vendor carries different weight than the official RFC. AI-generated "slop" articles — technically plausible but unverified content — pollute search results and can lead agents to adopt wrong patterns, outdated libraries, or insecure practices.

No existing AI coding framework distinguishes between source quality. Cursor, GitHub Copilot, Devin, Cline, Continue.dev, AutoGPT, CrewAI, and LangChain agents all treat web search results as equally authoritative.

## Solution

A 5-tier classification system embedded directly in agent instructions:

| Tier | Authority | Weight | Examples | Trust Level |
|------|-----------|--------|----------|-------------|
| **T1** | Official / Primary | 1.0 | Official docs, RFCs, API specs, vendor changelogs, peer-reviewed papers | Accept as ground truth |
| **T2** | Verified Expert | 0.8 | Core maintainer blogs, conference talks by authors, official tutorials | Trust, verify edge cases |
| **T3** | Community Consensus | 0.6 | High-vote SO answers, popular GitHub discussions, ThoughtWorks Radar | Trust if corroborated |
| **T4** | Individual Experience | 0.4 | Personal blogs, Medium articles, tutorial sites, single-person benchmarks | Verify before recommending |
| **T5** | Unverified / AI-generated | 0.2 | Forum comments, AI slop, promotional content, undated posts | **Discard by default** |

## Rules

1. **T5 sources are noise** — never base a recommendation on T5 alone
2. **Decisions require T1 or T2 backing** — if the best source is T3, flag it explicitly
3. **Conflicting sources — higher tier wins**: T1 says X, T3 says not-X → follow T1
4. **Recency within tier**: A 2025 T2 source outweighs a 2020 T2 for evolving technologies
5. **Star count is not authority**: 50K stars with no official backing = T3
6. **Promotional content is always T5**: If a source links to its own product in every recommendation, it is promotional regardless of technical accuracy

## AI Slop Detection

Red flags that downgrade a source to T5:
- Generic phrasing without specifics ("this tool is great for all use cases")
- No version numbers, dates, or concrete benchmarks
- Claims that cannot be verified in official docs
- Rigid two-part structure: "insight paragraph" + "link to our repo" (bot pattern)
- Confident claims about internal implementation details of closed-source tools

## Competitive Analysis

| Framework / Tool | Source Quality Classification | Authority Weighting |
|------------------|------------------------------|-------------------|
| **cognitive-core** | T1-T5 with numeric weights, embedded in agents | Yes — decisions require T1-T2 |
| Cursor | Rules for coding standards, no source classification | No |
| GitHub Copilot | Custom instructions, no research governance | No |
| Devin | Audit logs for actions, no source credibility | No |
| Cline / Continue.dev | Coding rules only | No |
| AutoGPT / CrewAI / LangChain | Web browsing capability, no quality filter | No |
| Enterprise AI Governance (IBM, Databricks) | Data provenance for model training, not research | Different domain |

**Closest academic parallel**: The CRAAP test (Currency, Relevance, Authority, Accuracy, Purpose) from library science — but this is not embedded in any development tool.

## Research Sources

| Finding | Source | Authority |
|---------|--------|-----------|
| No AI coding framework has source classification | Survey of Cursor, Copilot, Devin, Cline, OpenHands, CrewAI, LangChain docs | T1 (official docs) |
| CRAAP test for information literacy | California State University, Chico — library science standard | T1 (academic) |
| Enterprise AI governance focuses on data provenance | Databricks blog, Elevate Consulting | T2-T3 |
| ThoughtWorks Radar classifies technologies, not sources | ThoughtWorks Radar FAQ | T1 |

## Impact

Every research output from cognitive-core agents now includes:
- Source authority classification per finding
- Weighted recommendations
- Discarded T5 source count
- Highest authority level backing each decision

This prevents the framework from consuming AI-generated hallucinations and ensures decisions are traceable to authoritative sources.
