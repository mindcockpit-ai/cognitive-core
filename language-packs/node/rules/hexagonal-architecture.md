---
paths: ["**/*.ts", "**/*.module.ts", "**/*.port.ts", "**/*.adapter.ts"]
---

# Hexagonal Architecture (Ports & Adapters)

## Layer Structure

- Three layers: **Domain** (core), **Application** (use cases), **Infrastructure** (adapters)
- Domain layer has zero dependencies on frameworks, ORMs, or HTTP — pure TypeScript only
- Application layer depends on Domain; defines ports (interfaces) for external interactions
- Infrastructure layer implements ports — ORM repositories, HTTP clients, message producers
- No layer may import from a layer above it: Infrastructure -> Application -> Domain (dependency flows inward)

## Folder Organisation

```
src/
  <feature>/
    domain/          # Entities, value objects, domain services, domain events
    application/     # Use cases, ports (interfaces), DTOs, application services
    infrastructure/  # Adapters (repositories, HTTP, messaging), module registration
```

- One folder per bounded context / feature — do NOT flatten all entities into a single `domain/` folder
- Keep `domain/` free of decorators from NestJS, TypeORM, Prisma, or any framework

## Ports (Interfaces)

- Define ports as TypeScript interfaces in the `application/` layer
- Name ports by capability: `UserRepository`, `EmailSender`, `PaymentGateway` — not by implementation
- Ports describe WHAT, not HOW — no ORM types, HTTP details, or framework specifics in port signatures
- Use `InjectionToken` to bind ports to concrete adapters in the NestJS module

## Adapters (Implementations)

- One adapter per external system — database, HTTP API, message broker, file system
- Adapters live in `infrastructure/` and implement a port interface
- Adapters may depend on framework libraries (TypeORM, Prisma, Axios) — the domain must not
- Adapters translate between domain types and external formats (DB rows, API responses, messages)

## Dependency Rule

- Domain imports: nothing external (only other domain types)
- Application imports: domain types + port interfaces it defines
- Infrastructure imports: application ports + framework libraries to implement them
- Controllers / entry points live in infrastructure — they call application use cases, not domain directly
- Never pass ORM entities across layer boundaries — map to DTOs or domain objects at the adapter

## Use Cases

- One class per use case: `CreateUserUseCase`, `ProcessPaymentUseCase`
- Use cases orchestrate domain logic and call ports — they do NOT contain business rules themselves
- Use cases receive and return DTOs — never domain entities (prevents leaking internal structure)
- Use cases are the only entry point for application logic — controllers and message handlers call use cases

## Testing Implications

- Domain layer: unit tests with zero mocks (pure logic)
- Application layer: unit tests with mocked ports (verify orchestration)
- Infrastructure layer: integration tests against real external systems (Testcontainers, test SMTP)
- Never mock the domain — if you need to mock domain logic, the boundaries are wrong
