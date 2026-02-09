# Architectural Patterns

This directory contains technology-agnostic architectural patterns with specific implementation examples.

## Pattern Structure

Each pattern follows this hierarchy:

```
pattern/
├── README.md              # Abstract pattern definition
├── implementations/       # Technology-specific implementations
│   ├── python/
│   ├── java/
│   └── ...
└── examples/              # Working examples
```

## Available Patterns

### Integration Patterns

| Pattern | Description | Implementations |
|---------|-------------|-----------------|
| [Messaging](./messaging/) | Async message processing | Kafka, RabbitMQ, AWS SQS |
| [API Integration](./api-integration/) | External API consumption | OpenAI, REST clients, GraphQL |

### Quality Patterns

| Pattern | Description | Implementations |
|---------|-------------|-----------------|
| [Testing](./testing/) | Test strategy & standards | pytest, JUnit, Jest, Vitest |
| [Security](./security/) | Security architecture | OAuth2, JWT, RBAC |
| [CI/CD](./ci-cd/) | Pipeline architecture | GitHub Actions, GitLab CI, Jenkins |

## Pattern Philosophy

### Abstraction First

Each pattern defines:
1. **Problem** - What challenge does this solve?
2. **Solution** - Technology-agnostic approach
3. **Trade-offs** - When to use/avoid
4. **Interfaces** - Contracts implementations must satisfy

### Implementation Examples

Implementations show:
1. **Setup** - How to configure
2. **Code** - Working examples
3. **Testing** - How to test
4. **Best Practices** - Technology-specific tips

## Creating New Patterns

```bash
# Copy template
cp -r templates/pattern-template patterns/my-pattern/

# Customize
1. Update README.md with abstract pattern
2. Add implementations for target languages
3. Include working examples
4. Add to main README table
```

## See Also

- [Biomimetic Hierarchy](../biomimetic-hierarchy.md) - Skill organization
- [Examples](../../../examples/) - Working code examples
- [Cellular Skills](../../../skills/cellular/) - Domain-specific skills
