# Contributing to cognitive-core

Thank you for your interest in contributing to cognitive-core! This document provides guidelines for contributions.

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help maintain a welcoming environment

## How to Contribute

### Reporting Issues

1. Check existing issues first
2. Use the issue template
3. Include reproduction steps
4. Specify your environment

### Suggesting Features

1. Open a discussion first
2. Explain the use case
3. Consider vendor-agnosticism
4. Think about the biomimetic model fit

### Submitting Pull Requests

1. Fork the repository
2. Create a feature branch
3. Follow the coding standards
4. Write tests if applicable
5. Update documentation
6. Submit PR with clear description

## Areas of Contribution

### Priority Areas

1. **Adapters** - New AI provider adapters (Gemini, Mistral, Cohere)
2. **Skills** - Domain-specific cellular skills
3. **Documentation** - Examples, tutorials, translations
4. **Testing** - Skill validation, adapter testing

### Skill Contributions

When contributing new skills:

```
skills/
├── atomic/          # Universal primitives (rare additions)
├── molecular/       # Composed operations
└── cellular/        # Domain-specific (most contributions)
    └── templates/   # Project templates
```

#### Skill Requirements

- [ ] Universal YAML format (`skill.yaml`)
- [ ] At least one adapter implementation
- [ ] Documentation with examples
- [ ] Fitness criteria defined
- [ ] Tests (where applicable)

### Adapter Contributions

When contributing new adapters:

```
adapters/
├── claude/     # Reference implementation
├── openai/     # OpenAI Assistants/Functions
├── ollama/     # Local LLM support
└── <new>/      # Your contribution
```

#### Adapter Requirements

- [ ] README with mapping documentation
- [ ] Conversion script/tool
- [ ] Example outputs
- [ ] Testing instructions

## Coding Standards

### Universal Skill Format

Follow `skills/skill-format.yaml` specification:

```yaml
name: my-skill
version: 1.0.0
description: Clear, actionable description
category: atomic|molecular|cellular|organism
capabilities:
  - required_capability
inputs:
  - name: param
    type: string
    required: true
fitness:
  categories:
    quality: 0.5
    security: 0.5
```

### Documentation

- Use clear, concise language
- Include practical examples
- Document all options
- Explain the "why" not just "what"

### Commit Messages

Follow conventional commits:

```
type(scope): description

Types: feat, fix, docs, style, refactor, test, chore
Scope: skill name, adapter name, or general area

Examples:
feat(skills): add terraform-patterns cellular skill
fix(claude): correct capability mapping for WebSearch
docs(architecture): expand fitness function examples
```

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/cognitive-core.git
cd cognitive-core

# Create feature branch
git checkout -b feature/my-contribution

# Make changes...

# Test locally (adapter-specific)
# For Claude:
cp skills/atomic/my-skill/* ~/.claude/skills/my-skill/

# Commit and push
git add .
git commit -m "feat(skills): add my-skill atomic skill"
git push origin feature/my-contribution
```

## Review Process

1. **Automated checks** - Format, lint (if applicable)
2. **Maintainer review** - Architecture fit, quality
3. **Community feedback** - Open for comments
4. **Merge** - After approval

## Questions?

- Visit [multivac42.ai](https://multivac42.ai) for an overview
- Open a [GitHub Discussion](https://github.com/mindcockpit-ai/cognitive-core/discussions)
- Tag maintainers for guidance

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for helping make cognitive-core better!
