# Examples

Reference implementations demonstrating how to apply cognitive-core skill architecture to real-world projects.

## Architecture Examples

White-labeled, language-agnostic DDD patterns. All examples follow the same architecture, demonstrating that **the same patterns work across any technology stack**.

### Core Philosophy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         UI (Framework Agnostic)                             │
│                    Angular, React, Vue, Svelte                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                              REST API
                                    │
┌─────────────────────────────────────────────────────────────────────────────┐
│                      BACKEND (Language Agnostic)                            │
│              Perl, Java, Python, C#, Node.js                                │
│                    Domain-Driven Design                                     │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                               Database
                                    │
┌─────────────────────────────────────────────────────────────────────────────┐
│                      DATA (Database Agnostic)                               │
│                  Oracle, PostgreSQL, SQL Server                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Backend Examples

| Language | Framework | Example | Status |
|----------|-----------|---------|--------|
| **Perl** | Moose/Dancer2 | [architecture/perl-ddd/](./architecture/perl-ddd/) | ✅ Ready |
| **Java** | Spring Boot | [architecture/java-spring/](./architecture/java-spring/) | ✅ Ready |
| **Python** | FastAPI | [architecture/python-fastapi/](./architecture/python-fastapi/) | ✅ Ready |
| **C#** | .NET Core | [architecture/csharp-dotnet/](./architecture/csharp-dotnet/) | ✅ Ready |
| **Node.js** | NestJS | [architecture/nodejs-nestjs/](./architecture/nodejs-nestjs/) | ✅ Ready |

### Frontend Examples

| Framework | Example | Status |
|-----------|---------|--------|
| **Angular** | [architecture/angular-ui/](./architecture/angular-ui/) | ✅ Ready |
| **React** | Planned | 🚧 |
| **Vue** | Planned | 🚧 |

## Common DDD Layer Structure

All examples follow the same layer architecture:

```
src/
├── Domain/          # Business entities, value objects (pure logic)
├── Repository/      # Data access abstraction
├── Service/         # Business logic orchestration
├── Mapper/          # DTO ↔ Domain transformations
├── Controller/      # REST API endpoints
└── Infrastructure/  # Cross-cutting concerns
```

### Layer Dependencies

```
                 Domain  Repo  Mapper  Service  Controller
Domain             -      ✗      ✗        ✗         ✗
Repository         ✓      -      ✗        ✗         ✗
Mapper             ✓      ✗      -        ✗         ✗
Service            ✓      ✓      ✓        -         ✗
Controller         ✓      ✗      ✓        ✓         -
```

## Key Principles

1. **UI Independence** - Frontend connects via REST API only
2. **Backend Flexibility** - Same patterns work in any language
3. **Database Abstraction** - ORM isolates database specifics
4. **Domain Purity** - Business logic has no infrastructure dependencies
5. **DTO Boundary** - Never expose domain entities directly

## Contributing Examples

Want to contribute? See [CONTRIBUTING.md](../CONTRIBUTING.md).

Requirements:
1. **Generic** - No proprietary or confidential code
2. **White-labeled** - No client-specific references
3. **Complete** - Include all DDD layers
4. **Documented** - Explain patterns and anti-patterns
