# The Parsimony Principle — Research Report

**Date**: 2026-03-15
**Related issue**: [#63](https://github.com/mindcockpit-ai/cognitive-core/issues/63)
**Status**: Adopted as design principle

## Executive Summary

Occam's Razor — "prefer the simplest solution that works" — is well-established in software engineering (KISS, YAGNI, Unix philosophy) and increasingly critical in AI agent design. Anthropic's own engineering guidance explicitly advocates simplicity for agent systems. Research shows simpler agent architectures measurably outperform complex ones.

For cognitive-core, the principle maps naturally onto the biomimetic philosophy: biological parsimony (energy minimization, neural sparsity, the free energy principle) is one of evolution's most fundamental patterns. Named **"The Parsimony Principle"** to fit the framework's vocabulary.

## Evidence

### Software Engineering

Occam's Razor manifests through three related principles:

| Principle | Focus | Relationship |
|-----------|-------|-------------|
| **KISS** | Implementation simplicity | Systems work best when kept simple |
| **YAGNI** | Feature restraint | Do not build what is not yet needed |
| **Unix Philosophy** | Compositional simplicity | Do one thing well; compose small tools |

Critical nuance from Fred Brooks: "simplest" means **fewest assumptions**, not simplest-looking. The operational form distinguishes **essential complexity** (inherent in the problem) from **accidental complexity** (introduced by the engineer). Occam's Razor eliminates accidental complexity while respecting essential complexity.

### AI/LLM Agent Systems

#### Anthropic's Position

Three Anthropic engineering publications converge on the same message:

**"Building Effective Agents" (2024):**
> "We recommend finding the simplest solution possible, and only increasing complexity when needed."

**"Effective Context Engineering" (2025):**
> "Find the smallest set of high-signal tokens that maximize the likelihood of your desired outcome."
> "Do the simplest thing that works will likely remain our best advice."

**"Writing Tools for Agents" (2025):**
> "More tools don't always lead to better outcomes."
> "Too many tools or overlapping tools can also distract agents from pursuing efficient strategies."

#### Research Evidence

- **In-Context Learning and Occam's Razor (arXiv:2410.14086)**: LLMs have an inherent simplicity bias baked into their training objective — next-token prediction is mathematically equivalent to a data compression technique that constrains model complexity.
- **smolagents (HuggingFace)**: 30% fewer LLM calls through simplicity (~1000 LOC agent logic), higher benchmark performance.
- **LlamaIndex research**: Pushing complexity into tools themselves (fewer, better tools) outperforms many simple tools requiring agent coordination.

#### Framework Landscape

| Framework | Simplicity Stance | Outcome |
|-----------|------------------|---------|
| **smolagents** | Explicit minimalism | 30% fewer LLM calls |
| **CrewAI** | Lean, minimal abstractions | Fast prototyping |
| **PydanticAI** | Rejects complex abstractions | 2025 counter-movement |
| **LangChain** | Flexibility over simplicity | Criticized for over-engineering |

### Biological Parsimony

Biology operates on parsimony at every scale:

| Biological System | Mechanism | cognitive-core Analog |
|-------------------|-----------|----------------------|
| **Neural sparsity** | Brain activates only 1-15% of neurons at any time | Activate only needed agents |
| **Metabolic optimization** | Evolution minimizes energy per unit output | Minimal tool allocation per skill |
| **Walk/run transition** | Automatic switch at equal-energy crossover | Graduated hook responses |
| **Free energy principle** | Living systems minimize prediction error with simplest models | Simplest hypothesis first |
| **Phylogenetic parsimony** | Fewest evolutionary changes = preferred hypothesis | Fewest assumptions |

The forest metaphor already in the README says "A forest has no CEO — yet it has thrived for 400 million years." A forest also does not waste energy. Occam's Razor **is** the mechanism by which evolution selects for efficiency.

## Counter-Arguments

### Security: Defense-in-Depth

Defense-in-depth is the explicit opposite of parsimony: multiple overlapping layers exist because no single layer stops all threats. cognitive-core's 9 hooks covering different vectors are defense-in-depth that should NOT be simplified.

**Resolution**: Parsimony applies **within** each security layer (graduated response, minimal rules per level) but NOT across layers.

### Essential Complexity

A framework with 10 agents, 46 skills, and 9 hooks is not over-engineered if each component addresses a distinct need. Users genuinely need code review AND testing AND security analysis AND database optimization.

**Resolution**: Target accidental complexity, not essential complexity.

### No Free Lunch Theorem

The NFL theorems prove no single approach (including simple ones) is universally superior.

**Resolution**: Parsimony is a **heuristic** (prefer simplicity when in doubt), not a **law** (simplicity always wins).

## Implementation

The principle was adopted in commit implementing issue #63, touching:

1. **README.md** — "The Parsimony Principle" subsection in Philosophy
2. **CLAUDE.md** — Rule 9 (survives context compaction)
3. **project-coordinator.md** — Simplicity-first routing before delegation
4. **solution-architect.md** — Simplicity ranking in Decision Framework
5. **code-standards-reviewer.md** — Over-engineering check in Review Process
6. **research-analyst.md** — Simplest-hypothesis-first in Research Process

## References

### Software Engineering
- [Simplicity in Software Design: KISS, YAGNI and Occam's Razor](https://effectivesoftwaredesign.com/2013/08/05/simplicity-in-software-design-kiss-yagni-and-occams-razor/)
- [Occam's Razor in Software Development (Naveen Muguda)](https://naveenkumarmuguda.medium.com/occams-razor-in-software-development-56ee3e8b8ce8)

### AI Agent Design (Anthropic)
- [Building Effective Agents](https://www.anthropic.com/research/building-effective-agents)
- [Writing Tools for Agents](https://www.anthropic.com/engineering/writing-tools-for-agents)
- [Effective Context Engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### AI Agent Frameworks
- [smolagents (HuggingFace)](https://huggingface.co/blog/smolagents)
- [Dumber LLM Agents Need More Constraints and Better Tools (LlamaIndex)](https://www.llamaindex.ai/blog/dumber-llm-agents-need-more-constraints-and-better-tools-17a524c59e12)

### Research
- [In-Context Learning and Occam's Razor (arXiv:2410.14086)](https://arxiv.org/abs/2410.14086)

### Biological Parsimony
- [A Free Energy Principle for Biological Systems (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC3510653/)
- [Teaching the Principle of Biological Optimization (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC3599908/)

### Security Counter-Argument
- [Defense in Depth (CISA)](https://www.cisa.gov/sites/default/files/recommended_practices/NCCIC_ICS-CERT_Defense_in_Depth_2016_S508C.pdf)
