# Enterprise Architecture Examples

White-labeled, language-agnostic architecture patterns for building enterprise applications with cognitive-core skills.

## Core Philosophy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ENTERPRISE ARCHITECTURE PATTERN                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         UI LAYER                                     │   │
│  │     (Angular, React, Vue, Svelte - Framework Agnostic)               │   │
│  │                                                                       │   │
│  │     Communicates via REST API only                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                              REST API                                       │
│                                    │                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      BACKEND LAYER                                   │   │
│  │     (Perl, Java, Python, C#, Node.js - Language Agnostic)           │   │
│  │                                                                       │   │
│  │     Domain-Driven Design Architecture                                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                              Database                                       │
│                                    │                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      DATA LAYER                                      │   │
│  │     (Oracle, PostgreSQL, SQL Server - DB Agnostic)                  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Key Principles

1. **UI Independence** - Any modern frontend framework connects via REST API
2. **Backend Flexibility** - Same architecture patterns work across languages
3. **Database Abstraction** - ORM layer isolates database specifics
4. **Domain-Driven Design** - Business logic in domain layer, not scattered

## Available Examples

| Language | Framework | Example |
|----------|-----------|---------|
| **Perl** | Moose/Dancer2 | [perl-ddd/](./perl-ddd/) |
| **Java** | Spring Boot | [java-spring/](./java-spring/) |
| **Python** | FastAPI | [python-fastapi/](./python-fastapi/) |
| **C#** | .NET Core | [csharp-dotnet/](./csharp-dotnet/) |
| **Node.js** | NestJS | [nodejs-nestjs/](./nodejs-nestjs/) |
| **Frontend** | Angular | [angular-ui/](./angular-ui/) |

## Common Architecture

All examples follow the same DDD layer structure:

```
src/
├── Domain/              # Business entities, value objects
│   ├── Entity/          # Domain models
│   ├── ValueObject/     # Immutable value types
│   └── Event/           # Domain events
├── Repository/          # Data access abstraction
│   ├── Interface/       # Repository contracts
│   └── Implementation/  # ORM implementations
├── Service/             # Business logic orchestration
├── Mapper/              # DTO ↔ Domain transformations
├── Controller/          # REST API endpoints
│   ├── Api/             # JSON API controllers
│   └── Gui/             # Server-rendered (optional)
└── Infrastructure/      # Cross-cutting concerns
    ├── Database/        # Connection management
    ├── Logging/         # Structured logging
    └── Config/          # Configuration management
```

## Layer Dependencies

```
                 Domain  Repo  Mapper  Service  Controller
Domain             -      ✗      ✗        ✗         ✗
Repository         ✓      -      ✗        ✗         ✗
Mapper             ✓      ✗      -        ✗         ✗
Service            ✓      ✓      ✓        -         ✗
Controller         ✓      ✗      ✓        ✓         -

✓ = Can depend on    ✗ = Must NOT depend on
```

## cognitive-core Integration

Each example includes:
- Cellular skills for language-specific patterns
- Pre-commit hooks with fitness functions
- Code review standards
- Test structure mirrors

## Getting Started

1. Choose your backend language example
2. Copy the structure to your project
3. Install cognitive-core skills for that language
4. Configure fitness thresholds
