# cognitive-core

A vendor-agnostic, biomimetic skill framework for AI agents.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

## Why cognitive-core?

Most AI agent frameworks focus on **capability** (what agents can do). cognitive-core focuses on **quality** (how well they do it) and **portability** (running the same skills across different AI providers).

| Existing Frameworks | cognitive-core Difference |
|---------------------|---------------------------|
| Capability-focused | **Quality-focused** (fitness functions) |
| Vendor lock-in | **Universal YAML** + adapters |
| Chain/graph models | **Biological hierarchy** (atomic→organism) |
| Trust-all execution | **Immune system** security layers |

## Core Principles

🧬 **Biomimetic Architecture**
Skills evolve like biological systems—from atomic primitives to complex organisms.

📊 **Fitness-First Development**
Measurable quality gates at every stage. Code survives or goes extinct based on fitness.

🔒 **Immune System Security**
Defense-in-depth with innate (fast rules) and adaptive (learned patterns) protection layers.

🌐 **Vendor-Agnostic Design**
Write skills once in universal YAML, run on Claude, OpenAI, Ollama, or any future agent.

## The Biomimetic Hierarchy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SKILL HIERARCHY                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  LEVEL 4: ORGANISM        Complete workflows, multi-step processes          │
│           ▲               /implement-feature, /migrate-legacy               │
│           │                                                                 │
│  LEVEL 3: CELLULAR        Domain-specific combinations                      │
│           ▲               /perl-patterns, /oracle-patterns                  │
│           │                                                                 │
│  LEVEL 2: MOLECULAR       Composed operations                               │
│           ▲               /pre-commit, /code-review, /fitness               │
│           │                                                                 │
│  LEVEL 1: ATOMIC          Universal primitives                              │
│                           /validate, /search, /format, /extract             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Evolutionary CI/CD

Inspired by Search-Based Software Engineering (SBSE), cognitive-core treats software development as an evolutionary process:

```
MUTATION           SELECTION              SURVIVAL
(Development)      (Quality Gates)        (Production)

┌──────────┐      ┌──────────┐           ┌──────────┐
│ Developer│ ───▶ │ Fitness  │ ───▶      │ Canary   │
│ writes   │      │ Functions│           │ Deploy   │
│ code     │      └────┬─────┘           └────┬─────┘
└──────────┘           │                      │
                  FAIL │                 FAIL │
                       ▼                      ▼
                 ┌──────────┐           ┌──────────┐
                 │ Rejected │           │ Rollback │
                 │(extinct) │           │(extinct) │
                 └──────────┘           └──────────┘
```

### Quality Gates (Selection Pressure)

| Gate | Threshold | Selection Pressure |
|------|-----------|-------------------|
| Lint | 0.60 | Low |
| Commit | 0.80 | Medium |
| Test | 0.85 | Medium-High |
| Merge | 0.90 | High |
| Deploy | 0.95 | Critical |

## Immune System Security

Based on Artificial Immune Systems (AIS) research:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    DEFENSE-IN-DEPTH STACK                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Layer 5: AUDIT & MONITORING        (Nervous System)                        │
│  Layer 4: HUMAN OVERSIGHT           (Consciousness)                         │
│  Layer 3: RUNTIME ISOLATION         (Quarantine)                            │
│  Layer 2: CAPABILITY ENFORCEMENT    (Adaptive Immunity)                     │
│  Layer 1: INPUT/OUTPUT GUARDRAILS   (Innate Immunity)                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/mindcockpit-ai/cognitive-core.git

# Copy skills to your agent's skill directory
# For Claude Code:
cp -r cognitive-core/skills/* ~/.claude/skills/

# For project-specific skills:
cp -r cognitive-core/skills/cellular/templates/* .claude/skills/
```

### Using Skills

```bash
# Validate input (atomic)
/validate email user@example.com

# Run pre-commit checks (molecular)
/pre-commit lib/MyModule.pm

# Evaluate fitness (molecular)
/fitness --gate=commit src/

# Deploy with survival monitoring (molecular)
/deploy production --strategy=canary
```

### Creating Custom Skills

```yaml
# .claude/skills/my-skill/SKILL.md
---
name: my-skill
extends: global:validate          # Inherit from atomic skill
description: Domain-specific validation
argument-hint: [target]
allowed-tools: Read, Grep
---

# My Skill

Custom instructions here...
```

## Universal Skill Format

cognitive-core uses a universal YAML format that adapters translate for each AI provider:

```yaml
# skills/molecular/code-review/skill.yaml
name: code-review
version: 1.0.0
description: Comprehensive code review with quality gates

inputs:
  - name: target
    type: file|directory
    required: true
  - name: depth
    type: enum[quick|standard|deep]
    default: standard

capabilities:
  - file_read
  - pattern_search
  - static_analysis

fitness:
  security: 0.25
  architecture: 0.25
  quality: 0.25
  performance: 0.25

outputs:
  - type: report
    format: markdown
  - type: score
    range: [0.0, 1.0]
```

## Adapters

| Adapter | Status | Description |
|---------|--------|-------------|
| **Claude** | ✅ Ready | Claude Code SKILL.md format |
| **OpenAI** | 🚧 Planned | GPT Actions / Assistants |
| **Ollama** | 🚧 Planned | Local LLM support |
| **LangChain** | 🚧 Planned | Chain integration |

## Project Structure

```
cognitive-core/
├── docs/
│   ├── architecture/          # Biomimetic, evolutionary, security docs
│   ├── adapters/              # Adapter implementation guides
│   └── best-practices/        # Usage patterns and tips
├── skills/
│   ├── atomic/                # Universal primitives
│   ├── molecular/             # Composed operations
│   └── cellular/              # Domain templates
├── adapters/
│   ├── claude/                # Claude Code adapter
│   ├── openai/                # OpenAI adapter
│   └── ollama/                # Ollama adapter
└── examples/
    └── tims/                  # Reference implementation
```

## Scientific Foundation

cognitive-core is built on peer-reviewed research:

- **SBSE**: Harman & Jones, "Search-Based Software Engineering" (ACM 2001)
- **AIS**: Artificial Immune Systems for intrusion detection (Wiley 2025)
- **CaMeL**: Google DeepMind's capability-based security (2025)
- **Constitutional AI**: Anthropic's value alignment approach
- **Fitness Functions**: ThoughtWorks' architectural fitness

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Areas of Interest

- 🔌 New adapters (Gemini, Mistral, etc.)
- 🧬 Domain-specific cellular skills
- 📊 Fitness function implementations
- 🔒 Security layer enhancements
- 📚 Documentation and examples

## Roadmap

- [x] Core architecture design
- [x] Claude Code adapter
- [x] Atomic and molecular skills
- [ ] OpenAI adapter
- [ ] Ollama adapter
- [ ] GitHub Actions integration
- [ ] Fitness dashboard
- [ ] Community skill marketplace

## License

MIT License - see [LICENSE](LICENSE) for details.

## About

cognitive-core is developed by [mindcockpit.ai](https://mindcockpit.ai), building AI-enhanced infrastructure for enterprise modernization.

---

*"In nature, every improvement is tested. cognitive-core brings natural selection to software development."*
