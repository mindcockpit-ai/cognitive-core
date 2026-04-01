---
paths: ["**/*.java", "**/*.kt"]
---

# Spring Boot Conventions (v3.x / v4.x)

## Architecture

- Constructor injection only — do NOT use `@Autowired` on fields or setter methods
- Declare all injected fields `private final`; use `@RequiredArgsConstructor` (Lombok) or explicit constructor
- Use `@ConfigurationProperties` for structured config — do NOT scatter `@Value` across classes
- Layer responsibilities: Controller → Service → Repository; no business logic in controllers
- Use records for DTOs and value objects — no mutable data carriers
- No Lombok `@Data` / `@Builder` on JPA entities — use explicit accessors to avoid Hibernate proxying issues

## Web

- Use `@RestController` for REST endpoints; use `@Controller` only for Thymeleaf / MVC views
- Return `ResponseEntity<T>` only when HTTP status or headers must be customised; return `T` otherwise
- Handle errors globally with `@RestControllerAdvice` — do NOT catch-and-return in individual controllers
- Return `ProblemDetail` (RFC 9457) for all error responses — do NOT return custom error envelopes
- Validate all request bodies and parameters with `@Valid` + Bean Validation annotations
- Use relative paths (`/api/...`) — no hardcoded base URLs in source code

## Configuration

- Use `application.yml` — do NOT use `application.properties`
- Never hardcode credentials, tokens, or secrets — use `${ENV_VAR}` placeholders
- Bind environment-specific values via Spring profiles (`application-prod.yml`, etc.)
- Expose only required Actuator endpoints; secure all `/actuator/**` paths behind authentication by default

## Security

- Use `@Bean SecurityFilterChain` with `HttpSecurity` parameter — do NOT extend `WebSecurityConfigurerAdapter` (removed in Spring Security 6)
- Use `requestMatchers()` — do NOT use `antMatchers()` (removed in Spring Security 6)
- Use `authorizeHttpRequests()` — do NOT use `authorizeRequests()` (deprecated)
- Use the lambda DSL exclusively — do NOT use `.and()` chaining (removed in Spring Security 7)
- No hardcoded passwords or API keys in any source file — use `${ENV_VAR}` or a secrets manager

## Data

- Place `@Transactional` on the service layer — do NOT annotate controllers or repository methods unless unavoidable
- Use `@Transactional(readOnly = true)` for queries that do not modify state
- Prefer Spring Data repository interfaces over hand-written JPQL for standard CRUD
- Use `JdbcClient` (v3.2+) for simple SQL — prefer it over raw `JdbcTemplate` for readability
- Fetch only what is needed — default associations to `LAZY`; use projections or DTOs to avoid N+1

## Testing

- Use test slices (`@WebMvcTest`, `@DataJpaTest`, `@JsonTest`) for focused tests — do NOT default to `@SpringBootTest`
- Use `@SpringBootTest` only for integration tests that require the full application context
- Use Testcontainers with `@ServiceConnection` (v3.1+) for integration tests against real databases
- Use `@MockitoBean` / `@MockitoSpyBean` (v3.5+/v4+) — do NOT use `@MockBean` / `@SpyBean` (removed in v4)
- Assert JSON responses with `MockMvcResultMatchers.jsonPath` — do NOT deserialise and inspect manually when a path check suffices

## Code Quality

- Use SLF4J with parameterised messages (`log.info("loaded {} items", count)`) — do NOT use `System.out.println`
- No Lombok — use records, explicit constructors, or IDE-generated code
- Use `java.util.Optional` return types from repositories; never return `null` from service methods
- Declare constants in dedicated `*Constants` classes or as `static final` fields — no magic strings
- Apply JSpecify null-safety annotations (`@Nullable`, `@NonNull` from `org.jspecify.annotations`) on public API boundaries (v4+)
