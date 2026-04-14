---
paths: ["**/*.ts", "**/*.module.ts", "**/*.controller.ts", "**/*.service.ts"]
---

# NestJS Conventions

## Modules

- One module per bounded context — do NOT create a single `SharedModule` dumping ground
- Import only what the module needs — no wildcard re-exports
- Use `forRoot()` / `forRootAsync()` for singleton configuration modules (database, config, auth)
- Use `forFeature()` for feature-scoped registrations (TypeORM entities, Mongoose schemas)
- Global modules (`@Global()`) only for cross-cutting concerns (config, logging) — never for business logic

## Dependency Injection

- Constructor injection only — do NOT use property injection (`@Inject()` on fields)
- Declare all injected dependencies `private readonly`
- Use custom `InjectionToken` for swappable implementations — do NOT inject concrete classes for ports
- Use `@Optional()` only for genuinely optional dependencies, not to hide missing providers
- Scope: default singleton; use `REQUEST` scope only when request-specific state is unavoidable (it disables singleton optimisation)

## Controllers

- One controller per resource/aggregate — do NOT combine unrelated endpoints
- Use `@Controller('resource')` with plural, kebab-case route prefix
- Return DTOs — never expose domain entities or ORM models directly
- Use `@HttpCode()` for non-200 success responses (e.g., 201 for create, 204 for delete)
- Validate all input with `class-validator` decorators + `ValidationPipe` globally
- No business logic in controllers — delegate to services immediately

## Services

- One service per domain operation or aggregate — keep single-responsibility
- Throw domain-specific exceptions — do NOT throw raw `HttpException` from services
- Services must not depend on HTTP concepts (Request, Response, headers)
- Use `@Injectable()` on all services — even if currently only used in one module

## Exception Handling

- Register a global `@Catch()` exception filter for consistent error responses
- Map domain exceptions to HTTP status codes in the exception filter — not in services
- Return consistent error shape: `{ statusCode, message, error, timestamp }`
- Log all 5xx errors with full stack trace; log 4xx at debug level
- Never expose internal error details (stack traces, SQL errors) in production responses

## Pipes, Guards, Interceptors

- Use `ValidationPipe` globally (`app.useGlobalPipes()`) — do NOT apply per-route unless overriding
- Guards for authorisation (`@UseGuards()`) — do NOT check permissions in controllers manually
- Interceptors for cross-cutting: logging, caching, response transformation
- Execution order: Middleware -> Guards -> Interceptors -> Pipes -> Handler -> Interceptors -> Filters

## Configuration

- Use `@nestjs/config` with `ConfigService` — do NOT read `process.env` directly in services
- Validate config at startup with Joi or `class-validator` schema — fail fast on missing values
- Use `.env` files for local development only — never commit them
- Type config access: `configService.get<number>('PORT')` with explicit type parameter
