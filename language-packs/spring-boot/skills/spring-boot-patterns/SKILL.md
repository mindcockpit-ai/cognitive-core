---
name: spring-boot-patterns
description: "Version-aware Spring Boot patterns (v2-v4), anti-patterns, and legacy detection. Constructor injection, SecurityFilterChain, RestClient, virtual threads, Micrometer, Spring Modulith, and GraalVM native image support."
user-invocable: false
allowed-tools: Read, Grep, Glob
catalog_description: "Spring Boot patterns — injection, security, REST, testing slices, virtual threads, legacy detection."
---

# Spring Boot Patterns & Anti-Patterns (v2-v4)

## Legacy Anti-Pattern Detection

When analyzing a Spring Boot codebase, scan for these anti-patterns and quantify each category.

### Critical Anti-Patterns (Must Fix)

| Anti-Pattern | Detection | Modern Alternative | Since |
|-------------|-----------|-------------------|-------|
| Field `@Autowired` injection | `@Autowired` on fields | Constructor injection with final fields | always |
| `javax.*` imports (v3+) | `import javax.persistence` etc. | `import jakarta.persistence` (Jakarta EE 10) | v3.0 |
| `WebSecurityConfigurerAdapter` | `extends WebSecurityConfigurerAdapter` | `@Bean SecurityFilterChain` method | v3.0 (Security 6) |
| `antMatchers()` in security config | `.antMatchers("/api/**")` | `.requestMatchers("/api/**")` | v3.0 (Security 6) |
| `RestTemplate` for new code (v3.2+) | `new RestTemplate()` / `@Bean RestTemplate` | `RestClient.create()` or `RestClient.builder()` | v3.2 (deprecated v4) |
| `@MockBean` / `@SpyBean` (v3.4+) | Spring Boot test annotations | `@MockitoBean` / `@MockitoSpyBean` (Mockito native) | v3.4 (removed v4) |
| Jackson 2 `ObjectMapper` (v4+) | `com.fasterxml.jackson` package | Jackson 3 `tools.jackson` with `JsonMapper` | v4.0 |
| No resilience annotations (v4+) | External Spring Retry / Resilience4j for basic retry | Built-in `@Retryable` / `@ConcurrencyLimit` | v4.0 |
| `@Value` for structured config | Many `@Value("${...}")` annotations | `@ConfigurationProperties` with type-safe binding | always |
| `System.out.println` in prod | `System.out.print` / `System.err.print` | SLF4J `log.info()`, `log.error()` etc. | always |
| Catching generic `Exception` | `catch (Exception e)` | Catch specific exceptions, use `@ExceptionHandler` | always |
| `@Transactional` on controller | Controller-level transaction | Move to service layer | always |
| Hardcoded credentials | `password = "secret"` in properties/code | Environment variables, Vault, Spring Cloud Config | always |
| `spring.jpa.open-in-view=true` | Default OSIV enabled | Set `spring.jpa.open-in-view=false`, explicit DTOs | always |
| Missing `@RestControllerAdvice` | No global exception handler | Centralized error handling with RFC 7807 Problem Detail | always |

### Performance Anti-Patterns

| Anti-Pattern | Detection | Modern Alternative |
|-------------|-----------|-------------------|
| N+1 query problem | Lazy fetch without `@EntityGraph` | `@EntityGraph`, `JOIN FETCH`, or DTO projections |
| `@SpringBootTest` for unit tests | Full context load for simple tests | `@WebMvcTest`, `@DataJpaTest`, test slices |
| No connection pool tuning | Default HikariCP settings | Configure `spring.datasource.hikari.*` properties |
| Blocking calls in WebFlux | `Thread.sleep`, `RestTemplate` in reactive | `WebClient`, `Mono.delay()`, reactive drivers |
| Missing caching | No `@Cacheable` on repeated queries | Spring Cache with `@EnableCaching` |
| Eager fetching everywhere | `FetchType.EAGER` on all relations | `FetchType.LAZY` with `@EntityGraph` where needed |
| String concatenation in logs | `log.info("User " + name)` | `log.info("User {}", name)` parameterized |

### Security Anti-Patterns

| Anti-Pattern | Detection | Fix |
|-------------|-----------|-----|
| CSRF disabled without reason | `csrf().disable()` / `csrf(c -> c.disable())` | Enable CSRF for browser clients, disable only for stateless APIs |
| All actuator endpoints exposed | `management.endpoints.web.exposure.include=*` | Whitelist: `health,info,prometheus` |
| No CORS configuration | Missing `@CrossOrigin` or global CORS config | `CorsConfigurationSource` bean with explicit origins |
| SQL injection via concatenation | String concatenation in queries | Parameterized queries, Spring Data `@Query` with `:param` |
| Secrets in application.properties | Plaintext passwords/keys | `${ENV_VAR}`, Jasypt, Spring Cloud Vault |
| Missing input validation | No `@Valid` / `@Validated` on request bodies | Bean validation with `@Valid`, custom validators |
| Stack traces in error responses | Default Spring error handling | `@RestControllerAdvice` returning `ProblemDetail` |

## Version-Specific Patterns

### Spring Boot 2.x Patterns (Java 8-17)

Standard patterns for v2.x (latest: 2.7.x):

```java
// Security configuration with WebSecurityConfigurerAdapter (v2.x only)
@Configuration
@EnableWebSecurity
public class SecurityConfig extends WebSecurityConfigurerAdapter {

    @Override
    protected void configure(HttpSecurity http) throws Exception {
        http
            .authorizeRequests()
                .antMatchers("/api/public/**").permitAll()
                .antMatchers("/api/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            .and()
            .oauth2ResourceServer()
                .jwt();
    }
}
```

```java
// Service pattern with constructor injection (javax namespace)
import javax.persistence.EntityNotFoundException;
import javax.validation.Valid;

@Service
@Transactional(readOnly = true)
public class UserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public UserService(UserRepository userRepository, PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Transactional
    public User createUser(@Valid CreateUserRequest request) {
        var user = new User();
        user.setEmail(request.getEmail());
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        return userRepository.save(user);
    }
}
```

```java
// RestTemplate for HTTP calls (v2.x standard)
@Service
public class ExternalApiService {

    private final RestTemplate restTemplate;

    public ExternalApiService(RestTemplateBuilder builder) {
        this.restTemplate = builder
            .rootUri("https://api.example.com")
            .setConnectTimeout(Duration.ofSeconds(5))
            .setReadTimeout(Duration.ofSeconds(10))
            .build();
    }

    public UserDto fetchUser(String id) {
        return restTemplate.getForObject("/users/{id}", UserDto.class, id);
    }
}
```

### Spring Boot 3.0 Patterns (Java 17+, Jakarta EE 10)

Key changes: javax to jakarta, Spring Security 6, native image support.

```java
// Security with SecurityFilterChain (v3.0+ required)
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        return http
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/public/**").permitAll()
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()))
            .csrf(csrf -> csrf.ignoringRequestMatchers("/api/**"))
            .build();
    }
}
```

```java
// Service pattern (jakarta namespace)
import jakarta.persistence.EntityNotFoundException;
import jakarta.validation.Valid;

@Service
@Transactional(readOnly = true)
public class UserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public UserService(UserRepository userRepository, PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Transactional
    public User createUser(@Valid CreateUserRequest request) {
        var user = new User();
        user.setEmail(request.getEmail());
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        return userRepository.save(user);
    }

    public User getUser(Long id) {
        return userRepository.findById(id)
            .orElseThrow(() -> new EntityNotFoundException("User not found: " + id));
    }
}
```

```java
// HTTP interfaces (v3.0+ declarative HTTP client)
public interface UserClient {

    @GetExchange("/users/{id}")
    UserDto getUser(@PathVariable String id);

    @PostExchange("/users")
    UserDto createUser(@RequestBody CreateUserRequest request);
}

// Configuration
@Configuration
public class HttpClientConfig {

    @Bean
    public UserClient userClient(RestClient.Builder builder) {
        RestClient restClient = builder.baseUrl("https://api.example.com").build();
        HttpServiceProxyFactory factory = HttpServiceProxyFactory
            .builderFor(RestClientAdapter.create(restClient))
            .build();
        return factory.createClient(UserClient.class);
    }
}
```

```java
// Micrometer observation API (auto-configured in v3.0+)
@Service
public class OrderService {

    private final ObservationRegistry observationRegistry;
    private final OrderRepository orderRepository;

    public OrderService(ObservationRegistry observationRegistry, OrderRepository orderRepository) {
        this.observationRegistry = observationRegistry;
        this.orderRepository = orderRepository;
    }

    public Order createOrder(CreateOrderRequest request) {
        return Observation.createNotStarted("order.create", observationRegistry)
            .observe(() -> {
                var order = new Order(request);
                return orderRepository.save(order);
            });
    }
}
```

### Spring Boot 3.2+ Patterns (Java 17+, Virtual Threads, RestClient)

Key changes: RestClient, virtual threads support, @ServiceConnection Testcontainers, SSL bundles.

```java
// RestClient (v3.2+ replacement for RestTemplate)
@Service
public class ExternalApiService {

    private final RestClient restClient;

    public ExternalApiService(RestClient.Builder builder) {
        this.restClient = builder
            .baseUrl("https://api.example.com")
            .defaultHeader(HttpHeaders.ACCEPT, MediaType.APPLICATION_JSON_VALUE)
            .build();
    }

    public UserDto fetchUser(String id) {
        return restClient.get()
            .uri("/users/{id}", id)
            .retrieve()
            .body(UserDto.class);
    }

    public List<UserDto> searchUsers(String query) {
        return restClient.get()
            .uri(uriBuilder -> uriBuilder
                .path("/users")
                .queryParam("q", query)
                .build())
            .retrieve()
            .body(new ParameterizedTypeReference<>() {});
    }

    public UserDto createUser(CreateUserRequest request) {
        return restClient.post()
            .uri("/users")
            .contentType(MediaType.APPLICATION_JSON)
            .body(request)
            .retrieve()
            .body(UserDto.class);
    }
}
```

```yaml
# Virtual threads (application.yml, v3.2+)
spring:
  threads:
    virtual:
      enabled: true
```

```java
// SSL bundles (v3.2+)
@Configuration
public class HttpClientConfig {

    @Bean
    public RestClient restClient(RestClient.Builder builder, SslBundles sslBundles) {
        return builder
            .baseUrl("https://secure-api.example.com")
            .apply(sslBundles.getBundle("my-cert").stores()::applyTo)
            .build();
    }
}
```

### Spring Boot 4.0 Patterns (Nov 2025 — Spring Framework 7, Jakarta EE 11)

Key changes: Java 21 baseline, virtual threads default, structured concurrency, Spring Security 7, Spring Modulith default, built-in resilience (`@Retryable`/`@ConcurrencyLimit`), Jackson 3, API versioning, JSpecify null safety, RestTemplate deprecated.

```java
// Virtual threads enabled by default (no configuration needed in v4)
// Platform threads only needed for thread-local-dependent code

// Structured concurrency (Java 21, v4.0)
@Service
public class OrderAggregationService {

    private final UserClient userClient;
    private final InventoryClient inventoryClient;
    private final PricingClient pricingClient;

    public OrderSummary getOrderSummary(String orderId) throws Exception {
        try (var scope = new StructuredTaskScope.ShutdownOnFailure()) {
            var userTask = scope.fork(() -> userClient.getUser(orderId));
            var inventoryTask = scope.fork(() -> inventoryClient.getStock(orderId));
            var pricingTask = scope.fork(() -> pricingClient.getPrice(orderId));

            scope.join().throwIfFailed();

            return new OrderSummary(
                userTask.get(),
                inventoryTask.get(),
                pricingTask.get()
            );
        }
    }
}
```

```java
// Spring Security 7 (v4.0) — method-level authorization
@Service
@PreAuthorize("hasRole('USER')")
public class DocumentService {

    private final DocumentRepository documentRepository;

    public DocumentService(DocumentRepository documentRepository) {
        this.documentRepository = documentRepository;
    }

    @PostAuthorize("returnObject.owner == authentication.name")
    public Document getDocument(Long id) {
        return documentRepository.findById(id)
            .orElseThrow(() -> new EntityNotFoundException("Document not found"));
    }

    @PreAuthorize("hasRole('ADMIN') or #request.owner == authentication.name")
    public Document createDocument(CreateDocumentRequest request) {
        return documentRepository.save(new Document(request));
    }
}
```

```java
// Spring Modulith (default in v4.0)
// Enforces module boundaries within a monolith

// Module structure:
// com.example.app.order/   — OrderService, OrderRepository, OrderController
// com.example.app.user/    — UserService, UserRepository
// com.example.app.payment/ — PaymentService

// Inter-module communication via ApplicationEventPublisher
@Service
@Transactional
public class OrderService {

    private final OrderRepository orderRepository;
    private final ApplicationEventPublisher events;

    public OrderService(OrderRepository orderRepository, ApplicationEventPublisher events) {
        this.orderRepository = orderRepository;
        this.events = events;
    }

    public Order placeOrder(CreateOrderRequest request) {
        var order = orderRepository.save(new Order(request));
        events.publishEvent(new OrderPlacedEvent(order.getId(), order.getUserId()));
        return order;
    }
}

// Listener in payment module
@Component
public class PaymentEventHandler {

    @ApplicationModuleListener
    public void onOrderPlaced(OrderPlacedEvent event) {
        // Process payment for the order
    }
}
```

```java
// Built-in resilience — @Retryable and @ConcurrencyLimit (v4.0, no external dependency)
@Configuration
@EnableResilientMethods
public class ResilienceConfig {
}

@Service
public class PaymentService {

    private final PaymentGateway gateway;

    public PaymentService(PaymentGateway gateway) {
        this.gateway = gateway;
    }

    @Retryable  // Default: 3 attempts, 1s delay, exponential backoff with jitter
    @ConcurrencyLimit(10)  // Bulkhead: max 10 concurrent invocations
    public PaymentResult processPayment(PaymentRequest request) {
        return gateway.charge(request);
    }

    @Retryable(maxAttempts = 5, delay = 2000, multiplier = 2.0)
    public RefundResult processRefund(String transactionId) {
        return gateway.refund(transactionId);
    }
}
```

```java
// API versioning — built-in (v4.0, first-class support)
@RestController
@RequestMapping("/api/users")
public class UserController {

    @GetMapping(url = "/{id}", version = "1.0")
    public UserV1Response getUserV1(@PathVariable Long id) {
        return userService.getUserV1(id);
    }

    @GetMapping(url = "/{id}", version = "1.1")
    public UserV2Response getUserV2(@PathVariable Long id) {
        return userService.getUserV2(id);  // Includes additional fields
    }
}

// Configure versioning strategy in app config
@Configuration
public class ApiVersionConfig {
    @Bean
    public ApiVersionStrategy apiVersionStrategy() {
        return ApiVersionStrategy.path();  // or .header(), .queryParam(), .mediaType()
    }
}
```

```java
// Jackson 3 (v4.0 default — package changed from com.fasterxml.jackson to tools.jackson)
// Use JsonMapper instead of ObjectMapper
import tools.jackson.databind.json.JsonMapper;

@Configuration
public class JacksonConfig {

    @Bean
    public JsonMapper jsonMapper() {
        return JsonMapper.builder()
            .findAndAddModules()
            .build();
    }
}

// Jackson 3 defaults changed:
//   SORT_PROPERTIES_ALPHABETICALLY = true (was false)
//   WRITE_DATES_AS_TIMESTAMPS = false (ISO-8601 strings, was true)
// Backward compat flag: spring.jackson.use-jackson2-defaults=true
```

```java
// JSpecify null safety (v4.0 — portfolio-wide adoption)
import org.jspecify.annotations.Nullable;
import org.jspecify.annotations.NonNull;

@Service
public class UserService {

    public @Nullable User findByEmail(String email) {
        return userRepository.findByEmail(email).orElse(null);
    }

    public @NonNull User getUser(Long id) {
        return userRepository.findById(id)
            .orElseThrow(() -> new EntityNotFoundException("User not found: " + id));
    }
}
// JSpecify replaces org.springframework.lang.Nullable
// Kotlin 2 auto-translates to Kotlin nullability
// IntelliJ 2025.3+ provides full data-flow analysis
```

```java
// GraalVM native image support (matured in v3.0+, default tooling in v4.0)
// No code changes needed for most Spring Boot apps.
// Build native image:
//   Maven:  ./mvnw -Pnative native:compile
//   Gradle: ./gradlew nativeCompile

// Runtime hints for reflection (when needed)
@ImportRuntimeHints(MyRuntimeHints.class)
@Configuration
public class NativeConfig {
}

public class MyRuntimeHints implements RuntimeHintsRegistrar {
    @Override
    public void registerHints(RuntimeHints hints, ClassLoader classLoader) {
        hints.reflection().registerType(ExternalDto.class,
            MemberCategory.INVOKE_DECLARED_CONSTRUCTORS,
            MemberCategory.INVOKE_DECLARED_METHODS);
    }
}
```

## Controller Architecture

### Modern REST Controller Pattern

```java
@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor  // Lombok for constructor injection
@Validated
public class UserController {

    private final UserService userService;

    @GetMapping
    public Page<UserResponse> listUsers(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return userService.findAll(PageRequest.of(page, size))
            .map(UserResponse::from);
    }

    @GetMapping("/{id}")
    public UserResponse getUser(@PathVariable Long id) {
        return UserResponse.from(userService.getUser(id));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public UserResponse createUser(@Valid @RequestBody CreateUserRequest request) {
        return UserResponse.from(userService.createUser(request));
    }

    @PutMapping("/{id}")
    public UserResponse updateUser(
            @PathVariable Long id,
            @Valid @RequestBody UpdateUserRequest request) {
        return UserResponse.from(userService.updateUser(id, request));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteUser(@PathVariable Long id) {
        userService.deleteUser(id);
    }
}
```

### Repository Pattern

```java
public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByEmail(String email);

    @Query("SELECT u FROM User u WHERE u.status = :status")
    Page<User> findByStatus(@Param("status") UserStatus status, Pageable pageable);

    @EntityGraph(attributePaths = {"roles", "department"})
    Optional<User> findWithRolesById(Long id);

    boolean existsByEmail(String email);

    @Modifying
    @Query("UPDATE User u SET u.status = :status WHERE u.id = :id")
    int updateStatus(@Param("id") Long id, @Param("status") UserStatus status);
}
```

## State Management Decision Matrix

| State Type | Solution | When |
|-----------|----------|------|
| Request-scoped state | Method parameters, DTOs | Single request lifecycle |
| Session state | Spring Session (Redis) | User-specific, multi-request |
| Application cache | `@Cacheable` + Spring Cache | Frequently read, rarely changed |
| Distributed cache | Redis, Hazelcast | Multi-instance deployment |
| Configuration state | `@ConfigurationProperties` | Application settings |
| Transactional state | JPA entities in `@Transactional` | Database operations |
| Event-driven state | `ApplicationEventPublisher` | Cross-module communication |
| Async state | `@Async` + `CompletableFuture` | Background processing |
| Distributed state | Spring Cloud Config, Consul | Multi-service settings |

## Technical Debt Scoring

When analyzing a Spring Boot project, generate scores in these categories:

| Category | Weight | Measured By |
|----------|--------|------------|
| Injection Pattern | 15% | Constructor DI %, field @Autowired count |
| Security Config | 20% | SecurityFilterChain vs adapter, CSRF, actuator, credentials |
| API Design | 15% | @RestControllerAdvice, validation, error handling |
| Testing | 20% | Test ratio, slice tests vs @SpringBootTest, Testcontainers |
| Version Compliance | 15% | javax vs jakarta, RestTemplate vs RestClient, deprecated APIs |
| Code Quality | 10% | System.out, logging, exception handling |
| Tooling | 5% | Build tool version, checkstyle/spotbugs, CI presence |

Output format:
```
TECHNICAL DEBT REPORT: [Project Name]
=====================================
Overall Score: XX/100

Injection Pattern:    XX/15  (constructor: XX%, field @Autowired: XX)
Security Config:      XX/20  (filterchain: yes|no, csrf: ok|disabled, actuator: restricted|exposed)
API Design:           XX/15  (advice: yes|no, validation: XX%, error handling: rfc7807|stacktrace)
Testing:              XX/20  (ratio: XX%, slices: XX%, testcontainers: yes|no)
Version Compliance:   XX/15  (namespace: javax|jakarta, http client: template|restclient, boot: vX.X)
Code Quality:         XX/10  (sysout: XX, logging: param|concat, exceptions: specific|generic)
Tooling:              XX/5   (build: maven|gradle, lint: checkstyle|none, ci: yes|no)

Priority Migration Path:
1. [Highest impact item]
2. [Second highest]
3. ...
```
