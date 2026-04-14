---
paths: ["**/*.ts", "**/*.entity.ts", "**/*.schema.ts", "**/*.repository.ts", "**/migrations/**"]
---

# ORM & Database Patterns

## Query Safety

- Always use parameterised queries — never interpolate user input into SQL or query builders
- Use ORM query builders or prepared statements — no raw string concatenation
- Validate and sanitise all user-provided identifiers (column names, sort fields) against an allowlist
- Limit `SELECT` to needed columns — no `SELECT *` in production queries

## Migrations

- Every schema change goes through a migration — no manual DDL or `synchronize: true` in production
- Migrations are append-only — never edit a migration that has been applied to shared environments
- Name migrations descriptively: `1713000000000-AddUserEmailIndex`
- Test migrations against a real database before merging — not just TypeScript compilation
- Include both `up()` and `down()` — reversibility is required for safe rollbacks
- Run migrations in CI against a disposable database (Testcontainers or Docker)

## TypeORM

- Use `Repository` pattern via `@InjectRepository()` — do NOT use `EntityManager` directly for CRUD
- Define entities with decorators; use `@Column({ type: '...' })` with explicit DB types
- Default all relations to lazy (`{ lazy: true }`) or load explicitly with `relations` option — prevent N+1
- Use `QueryBuilder` for complex queries; use `Repository` methods for simple CRUD
- Transaction: `dataSource.transaction(async (manager) => { ... })` — do NOT nest transactions

## Prisma

- Use `schema.prisma` as the single source of truth — do NOT define models elsewhere
- Generate client after every schema change: `npx prisma generate`
- Use `prisma.$transaction()` for multi-step writes — not manual rollback logic
- Access relations via Prisma's fluent API — do NOT write raw JOINs unless performance-critical
- Use `@map` / `@@map` for snake_case DB columns with camelCase TS fields

## Drizzle

- Schema-first: define tables in TypeScript with `pgTable()` / `mysqlTable()` / `sqliteTable()`
- Use Drizzle Kit for migration generation: `npx drizzle-kit generate`
- Prefer the relational query API (`db.query.users.findMany()`) over raw SQL builders for readability
- Use `$inferSelect` / `$inferInsert` to derive types from schema — do NOT duplicate type definitions

## Connection Management

- Use connection pooling — do NOT create a new connection per request
- Set pool size based on expected concurrency (default: 10 for most Node apps)
- Handle connection errors with retry logic at startup — fail fast if database is unreachable
- Close connections gracefully on application shutdown (`onModuleDestroy` in NestJS)

## Performance

- Add indexes for columns used in `WHERE`, `ORDER BY`, and `JOIN` clauses
- Use pagination (`LIMIT` / `OFFSET` or cursor-based) for list endpoints — never return unbounded result sets
- Profile slow queries in development with query logging enabled
- Use database-level constraints (UNIQUE, NOT NULL, FK) — do NOT rely only on application-level validation
