---
paths: ["**/*.ts", "**/*.js", "**/*.tsx", "**/*.jsx"]
---

# Node.js / TypeScript Conventions

## Language

- Use `const` by default, `let` when reassignment is needed, never `var`
- Async/await over raw promises — no `.then()` chains in new code
- Named exports over default exports — improves refactoring and auto-import
- Destructure function parameters for clarity: `({ userId, limit }: FetchOptions)`
- Strict equality (`===` / `!==`) everywhere — never `==` / `!=`

## TypeScript

- Enable `strict: true` in `tsconfig.json` — all public APIs must have explicit types
- No `any` without a `// SAFETY:` comment justifying why `unknown` is insufficient
- Use `unknown` for values of uncertain type — narrow with type guards
- Use discriminated unions over type assertions for control flow
- Barrel files (`index.ts`) for public API boundaries only — do NOT barrel internal modules

## Modules

- Use ES modules (`import` / `export`) — no `require()` in TypeScript
- Organise imports: Node builtins -> external packages -> internal modules (enforce via ESLint)
- Avoid circular imports — if two modules import each other, extract the shared type to a third module
- Use path aliases (`@app/`, `@modules/`) configured in `tsconfig.json` paths — no deep relative imports (`../../../`)

## NestJS Specifics

- File naming: `<name>.<type>.ts` — e.g., `user.controller.ts`, `user.service.ts`, `user.module.ts`
- One class per file — do NOT combine controllers, services, or DTOs in a single file
- DTOs: use `class-validator` decorators for validation, `class-transformer` for serialisation
- Use `readonly` on DTO properties — DTOs are immutable data carriers
- Enums: use string enums for API contracts — they serialise readably and survive refactoring

## Code Quality

- No `console.log` in production code — use a structured logger (NestJS Logger, Pino)
- No magic numbers or strings — extract to named constants or config
- Functions should do one thing — if a function has `and` in its name, split it
- Maximum function length: 30 lines — extract helpers when a function exceeds this
- Prefer early returns over deeply nested conditionals
