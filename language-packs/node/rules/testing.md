---
paths: ["**/*.test.ts", "**/*.spec.ts", "**/*.test.js", "**/*.spec.js", "test/**/*", "tests/**/*"]
---

# Testing Conventions (Jest / NestJS)

## Structure

- Follow Arrange-Act-Assert (AAA) pattern — separate setup, execution, and verification
- One assertion per test when possible — each test verifies one behaviour
- Descriptive test names: `should return 404 when user does not exist` — not `test1` or `works`
- Group related tests with `describe` blocks matching the class or function under test

## Jest

- Use `jest.fn()` for function mocks, `jest.spyOn()` to intercept existing methods
- Prefer `toEqual()` for object/array comparison, `toBe()` for primitives and references
- Use `toThrow()` / `rejects.toThrow()` for error assertions — do NOT wrap in try/catch
- Clean up mocks in `afterEach`: `jest.restoreAllMocks()` — prevent leakage between tests
- Avoid `jest.mock()` at module level when `jest.spyOn()` in the test body suffices — module mocks are harder to reason about

## NestJS Testing

- Use `Test.createTestingModule()` for unit and integration tests
- Override providers with `.overrideProvider(TOKEN).useValue(mockImpl)` — do NOT mock the entire module
- Use `.compile()` and `module.get<ServiceType>(ServiceType)` to retrieve the subject under test
- For e2e tests: use `supertest` with `app.getHttpServer()` — test full HTTP request/response cycle
- Use `INestApplication` lifecycle: call `app.init()` in `beforeAll`, `app.close()` in `afterAll`

## Mocking Strategy

- Mock external dependencies (database, HTTP, file system) — not internal domain logic
- Use in-memory implementations for repositories in unit tests — not ORM mocks
- For database integration tests: use Testcontainers with a real database instance
- Never mock what you own — if you need to mock a service you wrote, the dependency graph is too tight
- Prefer dependency injection over `jest.mock()` — inject test doubles via the module builder

## Test Organisation

- Co-locate unit tests: `user.service.spec.ts` next to `user.service.ts`
- Place e2e tests in `test/` at project root: `test/user.e2e-spec.ts`
- Shared test fixtures in `test/fixtures/` — reusable factory functions, not raw JSON
- Shared test utilities in `test/helpers/` — custom matchers, test database setup

## Coverage

- Aim for meaningful coverage, not a number — 80% with tested edge cases beats 95% of trivial assertions
- Always test: error paths, boundary conditions, authorisation checks
- Do NOT test: framework internals (NestJS DI, TypeORM queries), third-party library behaviour
- Use `--collectCoverageFrom` to scope coverage to source files — exclude config, migrations, generated code

## Performance

- Keep unit tests fast (<5ms each) — mock all I/O
- Parallelise test suites with Jest workers (default behaviour) — do NOT use `--runInBand` unless tests share state
- Use `beforeAll` for expensive setup (database seeding, app bootstrap) — not `beforeEach`
- Tag slow integration tests and run them separately in CI
