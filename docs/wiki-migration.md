# Wiki Reorganization Guide

This document describes how to reorganize the mindcockpit-ai wiki to integrate with cognitive-core.

## Current Wiki Structure

```
mindcockpit-ai/mindcockpit-ai (Wiki)
├── Home          # Org overview
├── About         # Company info
├── AI Agents     # n8n, FoodieScan, architecture (MIXED)
├── CLAUDE        # Claude Code guidelines (MOVE)
├── Infrastructure # K3s, VPS
└── MVPs          # FoodieScan, Reconciliation
```

## Proposed Wiki Structure

```
mindcockpit-ai/mindcockpit-ai (Wiki)
├── Home          # Updated with cognitive-core reference
├── About         # Unchanged
├── AI Agents     # Simplified (mindcockpit-specific only)
├── Infrastructure # Unchanged
├── MVPs          # Unchanged
└── Projects      # NEW: Links to all repos
```

## Migration Steps

### 1. Update Home Page

Add cognitive-core section:

```markdown
## Open Source Projects

### cognitive-core

A vendor-agnostic, biomimetic skill framework for AI agents.

**Repository**: [github.com/mindcockpit-ai/cognitive-core](https://github.com/mindcockpit-ai/cognitive-core)

Key features:
- 🧬 Biomimetic skill hierarchy (atomic → organism)
- 📊 Fitness-first development with quality gates
- 🔒 Immune system security (defense-in-depth)
- 🌐 Vendor-agnostic (Claude, OpenAI, Ollama)

[View Documentation →](https://github.com/mindcockpit-ai/cognitive-core/tree/main/docs)
```

### 2. Simplify AI Agents Page

**Remove** (moved to cognitive-core):
- General agent architecture concepts
- Modular design patterns
- Agent composition theory

**Keep** (mindcockpit-specific):
- n8n AI Agents workflows
- FoodieScan agent details
- AI Guide Dog concept
- Reconciliation Agent

### 3. Delete/Redirect CLAUDE Page

Content moved to:
- `cognitive-core/docs/adapters/claude-best-practices.md`

Replace wiki page with redirect notice:

```markdown
# CLAUDE

This content has been moved to cognitive-core.

**New location**: [Claude Best Practices](https://github.com/mindcockpit-ai/cognitive-core/blob/main/docs/adapters/claude-best-practices.md)
```

### 4. Create Projects Page

New wiki page:

```markdown
# Projects

## Open Source

| Project | Description | Status |
|---------|-------------|--------|
| [cognitive-core](https://github.com/mindcockpit-ai/cognitive-core) | Biomimetic AI skill framework | Active |
| [mindcockpit-ai](https://github.com/mindcockpit-ai/mindcockpit-ai) | Organization introduction | Active |

## Private Projects

| Project | Description | Status |
|---------|-------------|--------|
| mindcockpit-infra | K3s/GitOps infrastructure | Active |
| PharmaSynth-AI | ML pharmaceutical formulation | Development |
| pharmasynth-platform | AI pharma platform | Development |

## Architecture

All projects follow the cognitive-core architecture patterns:

- **DDD Layer Structure**: Domain → Repository → Service → Controller
- **REST API First**: UI connects via API only
- **Fitness Functions**: Quality gates at every stage

See: [Architecture Examples](https://github.com/mindcockpit-ai/cognitive-core/tree/main/examples/architecture)
```

### 5. Update MVPs Page

Add PharmaSynth reference:

```markdown
## PharmaSynth

AI-driven pharmaceutical formulation platform using:
- Machine learning for drug development
- Graph neural networks for molecular interaction
- Computational chemistry optimization

Status: In Development
```

## Content Mapping

| Original Location | New Location |
|-------------------|--------------|
| Wiki: CLAUDE → Guidelines | cognitive-core/docs/adapters/claude-best-practices.md |
| Wiki: CLAUDE → Cleanup | cognitive-core/docs/adapters/claude-best-practices.md |
| Wiki: AI Agents → Architecture | cognitive-core/docs/architecture/ |
| Wiki: AI Agents → Patterns | cognitive-core/docs/architecture/biomimetic-hierarchy.md |

## Implementation

### Option A: Manual Wiki Edit

1. Log into GitHub
2. Navigate to wiki pages
3. Edit each page according to this guide
4. Commit changes

### Option B: Clone Wiki Repository

```bash
# Clone wiki
git clone https://github.com/mindcockpit-ai/mindcockpit-ai.wiki.git
cd mindcockpit-ai.wiki

# Edit files
# Home.md, AI-Agents.md, CLAUDE.md, Projects.md (new)

# Commit and push
git add .
git commit -m "docs: reorganize wiki for cognitive-core integration"
git push
```

## Verification

After migration, verify:

- [ ] Home page links to cognitive-core
- [ ] AI Agents page is simplified
- [ ] CLAUDE page redirects to cognitive-core
- [ ] Projects page lists all repos
- [ ] All links work correctly
