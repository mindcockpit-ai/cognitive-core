# Biomimetic Skill Hierarchy

**Version**: 1.0.0
**Based on**: Biological organization, Search-Based Software Engineering (SBSE)

---

## The Biological Analogy

Just as life organizes from atoms to organisms, cognitive-core skills organize in a hierarchy of increasing complexity and specialization:

| Biological Level | Skill Level | Characteristics |
|------------------|-------------|-----------------|
| **Atoms** | Atomic Skills | Indivisible, universal, context-free |
| **Molecules** | Molecular Skills | Combined atoms, specific function |
| **Cells** | Cellular Skills | Domain-specialized, project-aware |
| **Organisms** | Organism Skills | Complete workflows, multi-system |

---

## Level 1: Atomic Skills (Universal Primitives)

### Definition
Atomic skills are the smallest, indivisible units of agent capability. They have no dependencies, work in any context, and serve as building blocks for higher-level skills.

### Characteristics
- **Stateless**: No memory between invocations
- **Context-free**: Work identically across projects
- **Composable**: Designed to be combined
- **Fast**: Minimal processing overhead

### Examples

| Skill | Purpose | Input → Output |
|-------|---------|----------------|
| `/validate` | Input validation | data → valid/invalid |
| `/search` | Pattern search | pattern → matches |
| `/format` | Output formatting | data → formatted |
| `/extract` | Element extraction | source → elements |
| `/summarize` | Content summarization | content → summary |
| `/check-pattern` | Pattern compliance | code → compliance |

### Location
```
~/.claude/skills/           # Global (all projects)
├── validate/
├── search/
├── format/
├── extract/
├── summarize/
└── check-pattern/
```

---

## Level 2: Molecular Skills (Composed Operations)

### Definition
Molecular skills combine multiple atomic skills into coherent operations. They implement specific workflows but remain project-agnostic.

### Characteristics
- **Composed**: Built from atomic skills
- **Workflow-oriented**: Complete a specific task
- **Extensible**: Can be specialized by projects
- **Quality-gated**: Include fitness thresholds

### Examples

| Skill | Composition | Purpose |
|-------|-------------|---------|
| `/pre-commit` | validate + check-pattern + search | Pre-commit quality checks |
| `/code-review` | extract + check-pattern + summarize | Comprehensive code review |
| `/commit` | validate + format | Git commit with conventions |
| `/fitness` | check-pattern + validate | Fitness function evaluation |
| `/deploy` | fitness + validate | Evolutionary deployment |

### Composition Pattern

```yaml
# Molecular skill composition
name: pre-commit
composed-of:
  - validate      # Check syntax
  - check-pattern # Check standards
  - search        # Find anti-patterns

workflow:
  1. validate(syntax)
  2. check-pattern(standards)
  3. search(anti-patterns)
  4. aggregate(results)
```

### Location
```
~/.claude/skills/           # Global molecular skills
├── pre-commit/
├── code-review/
├── commit/
├── fitness/
└── deploy/
```

---

## Level 3: Cellular Skills (Domain-Specific)

### Definition
Cellular skills specialize molecular skills for specific domains, technologies, or projects. They inherit from molecular skills and add domain knowledge.

### Characteristics
- **Specialized**: Domain-specific knowledge
- **Inheriting**: Extend molecular skills
- **Project-aware**: Understand project context
- **Pattern-rich**: Encode domain patterns

### Examples

| Skill | Extends | Domain |
|-------|---------|--------|
| `/python-patterns` | check-pattern | Python/FastAPI conventions |
| `/spring-patterns` | check-pattern | Java/Spring Boot conventions |
| `/dotnet-patterns` | check-pattern | C#/.NET conventions |
| `/react-patterns` | check-pattern | React/TypeScript patterns |

### Extension Pattern

```yaml
# Cellular skill extending molecular
---
name: python-patterns
extends: global:check-pattern
domain: python
---

# Inherited: check-pattern functionality
# Added: Python-specific patterns

## Python Patterns
- Type hints required (PEP 484)
- Pydantic for validation
- async/await for I/O

## Anti-Patterns
- No bare except clauses
- No mutable default arguments
```

### Location
```
PROJECT/.claude/skills/     # Project-specific
├── python-patterns/        # Python patterns
├── spring-patterns/        # Java/Spring patterns
├── pre-commit/             # Extended pre-commit
├── code-review/            # Extended code-review
└── fitness/                # Extended fitness
```

---

## Level 4: Organism Skills (Complete Workflows)

### Definition
Organism skills orchestrate multiple molecular and cellular skills to accomplish complex, multi-step processes. They represent complete workflows.

### Characteristics
- **Orchestrating**: Coordinate multiple skills
- **Stateful**: Maintain workflow state
- **Goal-oriented**: Achieve business outcomes
- **Autonomous**: Minimal human intervention

### Examples

| Skill | Orchestrates | Goal |
|-------|--------------|------|
| `/implement-feature` | code-review + pre-commit + commit + deploy | Full feature lifecycle |
| `/migrate-legacy` | extract + transform + validate + deploy | Legacy modernization |
| `/onboard-repo` | analyze + configure + document | Repository setup |

### Orchestration Pattern

```yaml
# Organism skill orchestrating workflow
name: implement-feature
orchestrates:
  - code-review    # Review changes
  - pre-commit     # Quality checks
  - commit         # Version control
  - fitness        # Evaluate fitness
  - deploy         # Release

workflow:
  phases:
    1-develop:
      - Write code
      - /code-review
    2-validate:
      - /pre-commit
      - /fitness --gate=commit
    3-integrate:
      - /commit
      - /fitness --gate=merge
    4-release:
      - /deploy --strategy=canary
      - Monitor survival
```

---

## Inheritance and Extension

### Global → Project Flow

```
GLOBAL (~/.claude/skills/)
    │
    │ provides base
    ▼
PROJECT (.claude/skills/)
    │
    │ extends with domain knowledge
    ▼
SPECIALIZED SKILL
```

### Extension Syntax

```yaml
---
name: pre-commit
extends: global:pre-commit    # Inherit from global
---

# Additional project-specific checks
## Python Standards
Run ruff and mypy for all .py files

## Database Patterns
Check SQLAlchemy query patterns
```

---

## Skill Resolution Order

When invoking a skill, the system resolves in order:

1. **Project skill** (`.claude/skills/skill-name/`)
2. **Global skill** (`~/.claude/skills/skill-name/`)
3. **Built-in** (agent default behavior)

This allows projects to override or extend global skills while maintaining defaults.

---

## Benefits of Hierarchy

### Reusability
Atomic skills are written once, used everywhere.

### Specialization
Cellular skills encode domain expertise without duplicating base functionality.

### Composability
Complex workflows emerge from simple, well-tested components.

### Maintainability
Changes to atomic skills propagate to all dependent skills.

### Testability
Each level can be tested independently.

---

## Anti-Patterns

### ❌ Monolithic Skills
Don't create single skills that do everything.

### ❌ Skipping Levels
Don't jump from atomic to organism without molecular layer.

### ❌ Circular Dependencies
Skills should only depend on lower levels.

### ❌ Duplicating Logic
Extract common patterns to lower-level skills.

---

## References

- Search-Based Software Engineering (Harman & Jones, 2001)
- Building Evolutionary Architectures (Ford, Parsons, Kua)
- Biological Systems Theory
