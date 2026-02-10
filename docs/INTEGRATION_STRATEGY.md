# Cognitive-Core Integration Strategy

**Version**: 1.0.0
**Purpose**: Seamlessly integrate cognitive-core into any project to enforce quality, share patterns, and enable evolutionary development.

---

## Overview

Cognitive-core acts as a **development companion** that:
1. Provides domain-specific skill templates
2. Enforces quality through fitness functions
3. Shares patterns across projects
4. Guides both human and AI contributors

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     COGNITIVE-CORE INTEGRATION MODEL                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐    │
│  │  cognitive-core  │     │  Project Skills  │     │  Project Code    │    │
│  │  (Templates)     │────▶│  (.claude/skills)│────▶│  (src/, lib/)    │    │
│  └──────────────────┘     └──────────────────┘     └──────────────────┘    │
│          │                         │                        │               │
│          │                         │                        │               │
│          ▼                         ▼                        ▼               │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    EVOLUTIONARY CI/CD PIPELINE                        │  │
│  │  Pre-commit → Build → Test → Fitness → Deploy → Monitor              │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Integration Levels

### Level 1: Skill Templates (Quick Start)

Copy relevant templates to your project:

```bash
# Clone cognitive-core
git clone https://github.com/mindcockpit-ai/cognitive-core.git

# Copy templates to your project
mkdir -p your-project/.claude/skills

# For Perl/Dancer2 project (like TIMS)
cp -r cognitive-core/skills/cellular/templates/perl-dancer2/* \
      your-project/.claude/skills/perl-patterns/

# For Python/FastAPI project
cp -r cognitive-core/skills/cellular/templates/python-fastapi/* \
      your-project/.claude/skills/python-patterns/

# For Java/Spring project
cp -r cognitive-core/skills/cellular/templates/java-spring/* \
      your-project/.claude/skills/spring-patterns/
```

### Level 2: Git Submodule (Synchronized Updates)

Keep cognitive-core synchronized with your project:

```bash
# Add as submodule
git submodule add https://github.com/mindcockpit-ai/cognitive-core.git \
    .cognitive-core

# Create symlinks to skills
ln -s ../.cognitive-core/skills/atomic .claude/skills/atomic
ln -s ../.cognitive-core/skills/molecular .claude/skills/molecular

# Update when needed
git submodule update --remote
```

### Level 3: Full Integration (Recommended)

Complete integration with project-specific customization:

```
your-project/
├── .claude/
│   ├── skills/
│   │   ├── atomic/          # Symlink to cognitive-core
│   │   ├── molecular/       # Symlink to cognitive-core
│   │   └── cellular/        # Project-specific (customized)
│   │       ├── domain-patterns/
│   │       └── project-fitness/
│   └── CLAUDE.md            # Project instructions
├── .cognitive-core/         # Submodule
├── .github/
│   └── workflows/
│       └── evolutionary-cicd.yml
├── docker/
│   └── Dockerfile.test
└── src/
```

---

## Project Customization

### Step 1: Create Project CLAUDE.md

Your `CLAUDE.md` references cognitive-core patterns:

```markdown
# Project Development Guide

## Skill Integration

This project uses cognitive-core for quality enforcement.

### Active Skills
- `/perl-patterns` - Perl/Moose/Dancer2 standards
- `/fitness` - Code quality evaluation
- `/pre-commit` - Pre-commit checks

### Fitness Gates
| Gate | Threshold | Enforcement |
|------|-----------|-------------|
| lint | 0.60 | Warning |
| commit | 0.80 | Block |
| merge | 0.90 | Block |
| deploy | 0.95 | Block |

## Project-Specific Rules

[Your domain-specific rules here]
```

### Step 2: Customize Cellular Skills

Create domain-specific skills extending cognitive-core templates:

```markdown
---
name: tims-patterns
extends: global:perl-patterns
description: TIMS-specific Perl patterns
---

# TIMS Patterns

Extends global perl-patterns with TIMS-specific rules.

## Domain Layer Rules

### Required: Moose for All Domain Models

\`\`\`perl
# CORRECT: Moose-based domain model
package TIMS::Domain::NetworkElement;
use Moose;
use namespace::autoclean;

has 'id' => (is => 'ro', isa => 'Int', required => 1);
has 'name' => (is => 'ro', isa => 'Str', required => 1);

__PACKAGE__->meta->make_immutable;
1;
\`\`\`

## Repository Pattern

[Project-specific repository rules]

## Additional Fitness Criteria

| Function | Threshold | Description |
|----------|-----------|-------------|
| `moose_usage` | 100% | All domain models use Moose |
| `repository_pattern` | 100% | No direct DB access |
| `oracle_dates` | 100% | Correct DateTime handling |
```

### Step 3: Define Project Fitness Functions

Create fitness functions based on your CLAUDE.md rules:

```yaml
# .claude/skills/cellular/project-fitness/fitness.yaml
name: tims-fitness
version: 1.0.0
extends: molecular:fitness

functions:
  # From CLAUDE.md critical rules
  moose_usage:
    description: All business modules use Moose
    pattern: "^package TIMS::"
    required: "use Moose;"
    threshold: 1.0

  oracle_datetime:
    description: Correct DateTime handling
    anti_pattern: "now\\(\\)"
    message: "Use DateTime->now, not now()"
    threshold: 1.0

  array_reference:
    description: Pass arrays by reference
    anti_pattern: "my @\\w+ = @\\$"
    message: "Iterate directly over reference"
    threshold: 0.95

  repository_pattern:
    description: No HashRefInflator usage
    anti_pattern: "HashRefInflator"
    message: "Use domain models instead"
    threshold: 1.0

  try_tiny:
    description: Use Try::Tiny for exceptions
    pattern: "eval {"
    anti_pattern: true
    message: "Use Try::Tiny, not eval"
    threshold: 1.0

gates:
  lint:
    threshold: 0.60
    functions: [moose_usage, try_tiny]

  commit:
    threshold: 0.80
    functions: [moose_usage, oracle_datetime, try_tiny]

  merge:
    threshold: 0.90
    functions: all

  deploy:
    threshold: 0.95
    functions: all
```

---

## AI Agent Integration

### Claude Code Integration

When Claude Code works on a project with cognitive-core:

1. **Reads `.claude/skills/`** - Understands available patterns
2. **Applies fitness functions** - Self-validates before suggesting code
3. **References cross-project patterns** - Shows how similar problems were solved
4. **Enforces CLAUDE.md rules** - Follows project-specific guidelines

### Multi-Agent Orchestration

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        AGENT WORKFLOW WITH COGNITIVE-CORE                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  User Request                                                                │
│       │                                                                      │
│       ▼                                                                      │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐                │
│  │  Coordinator │────▶│  Specialist  │────▶│  Reviewer    │                │
│  │  Agent       │     │  Agent       │     │  Agent       │                │
│  └──────────────┘     └──────────────┘     └──────────────┘                │
│       │                     │                    │                          │
│       │                     │                    │                          │
│       ▼                     ▼                    ▼                          │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    COGNITIVE-CORE SKILLS                              │  │
│  │  - Pattern templates     - Fitness functions    - Cross-references   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Skill Invocation in Agents

Agents can invoke skills during their work:

```markdown
## Agent Prompt Template

When implementing code in this project:

1. Check `/project-patterns` for domain-specific rules
2. Run `/fitness --gate=commit` before suggesting changes
3. Reference `/cross-project` for similar solutions
4. Apply `/pre-commit` checks to validate

If fitness score < threshold, revise before presenting to user.
```

---

## Cross-Project Learning

### Pattern Registry

Cognitive-core maintains a registry of patterns across projects:

```yaml
# patterns/registry.yaml
patterns:
  - id: repository-pattern
    description: Repository pattern for data access
    implementations:
      - project: tims
        language: perl
        path: examples/architecture/perl-ddd/
      - project: webapp
        language: python
        path: examples/architecture/python-fastapi/
      - project: enterprise
        language: java
        path: examples/architecture/java-spring/

  - id: validation-framework
    description: Input validation patterns
    implementations:
      - project: tims
        language: perl
        reference: VALIDATION_FRAMEWORK.md
      - project: webapp
        language: python
        reference: pydantic-validation.md
```

### Cross-Reference Skill

```markdown
---
name: cross-reference
description: Find how patterns are implemented across projects
argument-hint: [pattern-name]
---

# Cross-Reference

Find implementations of a pattern across cognitive-core projects.

## Usage

\`\`\`bash
/cross-reference repository-pattern
/cross-reference validation-framework
/cross-reference error-handling
\`\`\`

## Output

Shows:
1. Pattern description
2. Implementations by language
3. Code examples
4. Fitness criteria
```

---

## Evolutionary CI/CD Integration

### Pipeline Template

Every project using cognitive-core gets evolutionary CI/CD:

```yaml
# .github/workflows/evolutionary-cicd.yml
name: Evolutionary CI/CD

on:
  push:
    branches: [feature/*, bugfix/*]
  pull_request:
    branches: [development, main]

jobs:
  mutation-test:
    runs-on: ubuntu-latest
    container:
      image: project-test-image:latest

    steps:
      - uses: actions/checkout@v4

      # Selection Phase
      - name: Lint Gate (threshold: 0.60)
        run: |
          ./scripts/fitness-check.sh --gate=lint

      - name: Build
        run: ./scripts/build.sh

      - name: Unit Tests
        run: ./scripts/test.sh --unit

      - name: Integration Tests
        run: ./scripts/test.sh --integration

      - name: Commit Gate (threshold: 0.80)
        run: |
          ./scripts/fitness-check.sh --gate=commit

      - name: Security Scan
        run: ./scripts/security-scan.sh

      # Merge Gate
      - name: Merge Gate (threshold: 0.90)
        if: github.event_name == 'pull_request'
        run: |
          ./scripts/fitness-check.sh --gate=merge

  # Survival Phase (only for merged PRs)
  deploy-staging:
    needs: mutation-test
    if: github.ref == 'refs/heads/development'
    runs-on: ubuntu-latest
    steps:
      - name: Deploy Gate (threshold: 0.95)
        run: ./scripts/fitness-check.sh --gate=deploy
      - name: Deploy to Staging
        run: ./scripts/deploy.sh staging
```

---

## Quick Start Checklist

### For New Projects

- [ ] Clone cognitive-core as submodule
- [ ] Create `.claude/skills/` directory
- [ ] Symlink atomic and molecular skills
- [ ] Create project-specific cellular skills
- [ ] Define fitness functions from project rules
- [ ] Create CLAUDE.md referencing skills
- [ ] Add evolutionary CI/CD pipeline
- [ ] Configure pre-commit hooks

### For Existing Projects (like TIMS)

- [ ] Add cognitive-core submodule
- [ ] Extract rules from existing CLAUDE.md
- [ ] Create fitness functions from rules
- [ ] Create project-specific skill templates
- [ ] Add CI/CD pipeline
- [ ] Configure container for isolated testing
- [ ] Document migration in CLAUDE.md

---

## Next Steps

1. See [TIMS Integration Example](./examples/tims-integration/) for a complete implementation
2. Review [Evolutionary CI/CD](./architecture/evolutionary-cicd.md) for pipeline details
3. Check [Fitness Functions](../skills/molecular/fitness/) for evaluation criteria
