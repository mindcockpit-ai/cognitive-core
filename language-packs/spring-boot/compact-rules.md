## Spring Boot Critical Rules (Post-Compaction)

1. **Constructor Injection Only**: Use constructor injection for all dependencies. No `@Autowired` on fields. Final fields with `@RequiredArgsConstructor` (Lombok) or explicit constructors.
2. **@ConfigurationProperties Over @Value**: Use `@ConfigurationProperties` with `@EnableConfigurationProperties` for structured config. Reserve `@Value` only for single simple properties.
3. **Test Slices Over @SpringBootTest**: Use `@WebMvcTest`, `@DataJpaTest`, `@WebFluxTest`, `@JsonTest` for focused tests. Only use `@SpringBootTest` for full integration tests.
4. **Jakarta EE Namespace (v3+)**: All imports must use `jakarta.*` packages, not `javax.*`. Applies to Servlet, Persistence, Validation, Mail, and all Jakarta EE APIs.
5. **SecurityFilterChain Over WebSecurityConfigurerAdapter**: Use `@Bean SecurityFilterChain` with `HttpSecurity` parameter. No class-level `extends WebSecurityConfigurerAdapter` (removed in Spring Security 6).
6. **RestClient Over RestTemplate (v3.2+)**: Use `RestClient` for synchronous HTTP calls. `RestTemplate` is in maintenance mode. Use `WebClient` only for reactive/non-blocking.
7. **No Hardcoded Credentials**: No passwords, API keys, or secrets in source code or application.properties. Use environment variables, Spring Cloud Config, or Vault.
8. **@Transactional on Service Layer**: Place `@Transactional` on service methods, never on controllers or repositories. Use `readOnly = true` for read operations.
9. **Testcontainers with @ServiceConnection (v3.1+)**: Use `@ServiceConnection` annotation for automatic connection configuration. No manual property overrides.
10. **Proper Exception Handling**: Use `@RestControllerAdvice` with `@ExceptionHandler` methods. Never expose stack traces in API responses. Return RFC 7807 Problem Detail.
11. **Actuator Security**: Never expose all actuator endpoints publicly. Whitelist `/health` and `/info` only. Protect `/env`, `/beans`, `/configprops` behind authentication.
12. **Structured Logging**: Use SLF4J with parameterized messages (`log.info("User {} created", id)`). No string concatenation in log statements. No `System.out.println` in production code.
