---
name: spring-boot-migration
description: "Spring Boot version upgrade paths from v2.x through v4.0. javax to jakarta migration, Spring Security 5 to 7, RestTemplate to RestClient, virtual threads, OpenRewrite recipes, and progressive migration strategies."
user-invocable: false
allowed-tools: Read, Grep, Glob
catalog_description: "Spring Boot migration — v2->v3->v3.2->v4, javax/jakarta, Security 6/7, OpenRewrite."
---

# Spring Boot Migration Guide: v2.x to v4.0

## Migration Assessment Framework

Before migrating, run a full project scan to quantify technical debt.

### Phase 0: Assessment

Run these scans to understand the project state:

```bash
# Spring Boot version
grep -E 'spring-boot|org.springframework.boot' pom.xml build.gradle build.gradle.kts 2>/dev/null | head -5

# Java version
grep -E 'java.version|sourceCompatibility|JavaVersion' pom.xml build.gradle build.gradle.kts 2>/dev/null | head -3

# javax vs jakarta imports
echo "javax imports:"; grep -rn 'import javax\.' src/main/java --include="*.java" 2>/dev/null | grep -v 'javax.crypto\|javax.net\|javax.sql' | wc -l
echo "jakarta imports:"; grep -rn 'import jakarta\.' src/main/java --include="*.java" 2>/dev/null | wc -l

# Spring Security pattern
echo "WebSecurityConfigurerAdapter:"; grep -rn 'WebSecurityConfigurerAdapter' src --include="*.java" 2>/dev/null | wc -l
echo "SecurityFilterChain:"; grep -rn 'SecurityFilterChain' src --include="*.java" 2>/dev/null | wc -l
echo "antMatchers:"; grep -rn 'antMatchers' src --include="*.java" 2>/dev/null | wc -l
echo "requestMatchers:"; grep -rn 'requestMatchers' src --include="*.java" 2>/dev/null | wc -l

# HTTP client usage
echo "RestTemplate:"; grep -rn 'RestTemplate' src/main/java --include="*.java" 2>/dev/null | wc -l
echo "RestClient:"; grep -rn 'RestClient' src/main/java --include="*.java" 2>/dev/null | wc -l
echo "WebClient:"; grep -rn 'WebClient' src/main/java --include="*.java" 2>/dev/null | wc -l

# Injection pattern
echo "Field @Autowired:"; grep -rn '@Autowired' src/main/java --include="*.java" 2>/dev/null | wc -l
echo "Constructor injection (Lombok):"; grep -rn '@RequiredArgsConstructor' src/main/java --include="*.java" 2>/dev/null | wc -l

# Deprecated APIs
echo "@Value usages:"; grep -rn '@Value(' src/main/java --include="*.java" 2>/dev/null | wc -l
echo "System.out:"; grep -rn 'System\.out\|System\.err' src/main/java --include="*.java" 2>/dev/null | wc -l

# Testing infrastructure
echo "@SpringBootTest:"; grep -rn '@SpringBootTest' src/test --include="*.java" 2>/dev/null | wc -l
echo "Test slices:"; grep -rn '@WebMvcTest\|@DataJpaTest\|@WebFluxTest\|@JsonTest' src/test --include="*.java" 2>/dev/null | wc -l
echo "Testcontainers:"; grep -rn '@Testcontainers\|@Container' src/test --include="*.java" 2>/dev/null | wc -l
echo "JUnit 4:"; grep -rn 'import org.junit.Test\|import org.junit.Before' src/test --include="*.java" 2>/dev/null | wc -l
echo "JUnit 5:"; grep -rn 'import org.junit.jupiter' src/test --include="*.java" 2>/dev/null | wc -l

# Dependencies count
echo "Total dependencies:"; grep -c '<dependency>' pom.xml 2>/dev/null || grep -c "implementation\|testImplementation" build.gradle 2>/dev/null || echo "unknown"
```

### Output: Migration Readiness Matrix

```
SPRING BOOT MIGRATION READINESS REPORT
========================================
Project: [Name]
Current Version: v[X.Y.Z]
Target Version:  v[X.Y.Z]
Java Version:    [X]

PATTERN INVENTORY:
  javax imports:              [X] files  (target: 0 for v3+)
  jakarta imports:            [X] files
  WebSecurityConfigurerAdapter: [X] files (target: 0 for v3+)
  SecurityFilterChain:        [X] files
  antMatchers:                [X] usages (target: 0 for v3+)
  RestTemplate:               [X] usages (suggest RestClient for v3.2+)
  Field @Autowired:           [X] usages (target: 0)
  JUnit 4 tests:              [X] files  (target: 0)
  @SpringBootTest overuse:    [X] / [Y] total test configs

BLOCKERS:
  Java version < 17:          [yes|no]   → Must upgrade Java first for v3+
  Java version < 21:          [yes|no]   → Must upgrade Java for v4+
  JUnit 4 tests:              [yes|no]   → Should migrate before Boot upgrade
  javax.* imports:            [X] files  → Must change to jakarta.* for v3+
  Deprecated Spring Security: [yes|no]   → Must migrate to SecurityFilterChain

EFFORT ESTIMATION:
  Phase 1 (Java upgrade):     [X] hours
  Phase 2 (OpenRewrite):      [X] hours (automated namespace migration)
  Phase 3 (Security config):  [X] hours ([Y] files)
  Phase 4 (API modernization):[X] hours (RestClient, test slices)
  Phase 5 (Virtual threads):  [X] hours
  Total:                      [X] hours / [Y] developer-days
```

## v2.x to v3.0 Upgrade

This is the largest migration step due to the javax-to-jakarta namespace change.

### Prerequisites

- **Java 17 minimum** (Java 8/11 no longer supported)
- **Spring Framework 6.0** (auto-included with Boot 3.0)
- **Jakarta EE 10** namespace

### Automated Steps (OpenRewrite)

```xml
<!-- Add to pom.xml for automated migration -->
<plugin>
    <groupId>org.openrewrite.maven</groupId>
    <artifactId>rewrite-maven-plugin</artifactId>
    <version>5.42.2</version>
    <configuration>
        <activeRecipes>
            <recipe>org.openrewrite.java.spring.boot3.UpgradeSpringBoot_3_0</recipe>
        </activeRecipes>
    </configuration>
    <dependencies>
        <dependency>
            <groupId>org.openrewrite.recipe</groupId>
            <artifactId>rewrite-spring</artifactId>
            <version>5.22.0</version>
        </dependency>
    </dependencies>
</plugin>
```

```bash
# Run OpenRewrite migration
./mvnw rewrite:run

# For Gradle:
# plugins { id("org.openrewrite.rewrite") version "6.25.3" }
# dependencies { rewrite("org.openrewrite.recipe:rewrite-spring:5.22.0") }
# ./gradlew rewriteRun
```

### What OpenRewrite Handles Automatically

| Change | Before | After |
|--------|--------|-------|
| javax namespace | `import javax.persistence.*` | `import jakarta.persistence.*` |
| javax.validation | `import javax.validation.*` | `import jakarta.validation.*` |
| javax.servlet | `import javax.servlet.*` | `import jakarta.servlet.*` |
| javax.annotation | `import javax.annotation.*` | `import jakarta.annotation.*` |
| Spring Security | `WebSecurityConfigurerAdapter` | `SecurityFilterChain` bean |
| antMatchers | `.antMatchers()` | `.requestMatchers()` |
| authorizeRequests | `.authorizeRequests()` | `.authorizeHttpRequests()` |
| Property changes | `spring.redis.*` | `spring.data.redis.*` |

### Breaking Changes v2.x to v3.0

| Change | Impact | Action |
|--------|--------|--------|
| javax to jakarta namespace | High | OpenRewrite handles most; manual review for 3rd-party libs |
| Java 17 minimum | High | Upgrade JDK, update CI/CD pipelines |
| Spring Security 5 to 6 | High | `SecurityFilterChain` replaces `WebSecurityConfigurerAdapter` |
| `antMatchers` removed | Medium | Replace with `requestMatchers` |
| `authorizeRequests` removed | Medium | Replace with `authorizeHttpRequests` |
| `spring.redis.*` to `spring.data.redis.*` | Low | Update properties |
| `spring.datasource.initialization-mode` | Low | Use `spring.sql.init.mode` |
| Spring Cloud compatibility | High | Upgrade Spring Cloud to 2022.x+ |
| Hibernate 6 | Medium | HQL changes, id generator changes |
| Micrometer auto-configuration | Low | Observation API replaces Sleuth |

### Manual Migration Steps

```java
// 1. Security configuration migration
// BEFORE (v2.x — Spring Security 5):
@Configuration
@EnableWebSecurity
public class SecurityConfig extends WebSecurityConfigurerAdapter {

    @Override
    protected void configure(HttpSecurity http) throws Exception {
        http
            .csrf().disable()
            .authorizeRequests()
                .antMatchers("/api/public/**").permitAll()
                .antMatchers("/api/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            .and()
            .httpBasic();
    }
}

// AFTER (v3.0 — Spring Security 6):
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        return http
            .csrf(csrf -> csrf.disable())
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/public/**").permitAll()
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            )
            .httpBasic(Customizer.withDefaults())
            .build();
    }
}
```

```java
// 2. Hibernate 6 changes
// BEFORE: Auto ID generation
@Id
@GeneratedValue(strategy = GenerationType.AUTO)
private Long id;

// AFTER: Specify strategy explicitly (Hibernate 6 changed AUTO behavior)
@Id
@GeneratedValue(strategy = GenerationType.IDENTITY)
private Long id;
```

```java
// 3. Property changes
// BEFORE (application.properties):
spring.redis.host=localhost
spring.redis.port=6379
server.max-http-header-size=8KB

// AFTER:
spring.data.redis.host=localhost
spring.data.redis.port=6379
server.max-http-request-header-size=8KB
```

## v3.0 to v3.2 Upgrade

### Automated Steps

```bash
# Update Spring Boot version in pom.xml/build.gradle
# Maven: change <version>3.2.x</version> in parent
# Gradle: change id 'org.springframework.boot' version '3.2.x'

./mvnw spring-boot:run  # Test that it starts
./mvnw test             # Run all tests
```

### Key Changes in v3.2

| Change | Impact | Action |
|--------|--------|--------|
| RestClient (new) | Medium | Adopt for new HTTP client code, migrate RestTemplate gradually |
| Virtual threads support | Medium | Enable with `spring.threads.virtual.enabled=true` (Java 21 required) |
| `@ServiceConnection` Testcontainers | Low | Replace `@DynamicPropertySource` with `@ServiceConnection` |
| SSL bundles | Low | Configure TLS/SSL via `spring.ssl.bundle.*` |
| Micrometer improvements | Low | Auto-configured observations for more components |
| JdbcClient (new) | Low | Simpler alternative to JdbcTemplate |

### New APIs to Adopt

```java
// RestClient — modern synchronous HTTP client
@Service
public class UserClient {

    private final RestClient restClient;

    public UserClient(RestClient.Builder builder) {
        this.restClient = builder
            .baseUrl("https://api.example.com")
            .build();
    }

    public UserDto getUser(String id) {
        return restClient.get()
            .uri("/users/{id}", id)
            .retrieve()
            .body(UserDto.class);
    }
}
```

```java
// @ServiceConnection replaces @DynamicPropertySource
// BEFORE (v3.0):
@Container
static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16");

@DynamicPropertySource
static void configureProperties(DynamicPropertyRegistry registry) {
    registry.add("spring.datasource.url", postgres::getJdbcUrl);
    registry.add("spring.datasource.username", postgres::getUsername);
    registry.add("spring.datasource.password", postgres::getPassword);
}

// AFTER (v3.1+):
@Container
@ServiceConnection
static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16");
// No @DynamicPropertySource needed
```

```yaml
# Virtual threads (Java 21+)
spring:
  threads:
    virtual:
      enabled: true
```

## v3.2 to v4.0 Upgrade

### Prerequisites

- **Java 21 minimum** (Java 17 no longer supported)
- **Virtual threads enabled by default**

### Key Changes in v4.0

| Change | Impact | Action |
|--------|--------|--------|
| Java 21 baseline | High | Upgrade JDK, update CI/CD |
| Virtual threads default | Medium | Remove explicit config, audit for ThreadLocal usage |
| Spring Security 7 | High | Review authorization changes, method-level security |
| Structured concurrency | Medium | Adopt for parallel service calls |
| Spring Modulith default | Medium | Organize code by module boundaries |
| Deprecated APIs removed | Medium | Fix all deprecation warnings from v3.2 |

### Structured Concurrency

```java
// BEFORE (v3.x — CompletableFuture):
@Service
public class AggregationService {

    @Async
    public CompletableFuture<UserDto> fetchUser(String id) {
        return CompletableFuture.completedFuture(userClient.getUser(id));
    }

    @Async
    public CompletableFuture<OrderDto> fetchOrders(String userId) {
        return CompletableFuture.completedFuture(orderClient.getOrders(userId));
    }

    public DashboardDto getDashboard(String userId) {
        var userFuture = fetchUser(userId);
        var ordersFuture = fetchOrders(userId);
        return new DashboardDto(userFuture.join(), ordersFuture.join());
    }
}

// AFTER (v4.0 — Structured concurrency):
@Service
public class AggregationService {

    private final UserClient userClient;
    private final OrderClient orderClient;

    public DashboardDto getDashboard(String userId) throws Exception {
        try (var scope = new StructuredTaskScope.ShutdownOnFailure()) {
            var userTask = scope.fork(() -> userClient.getUser(userId));
            var ordersTask = scope.fork(() -> orderClient.getOrders(userId));

            scope.join().throwIfFailed();

            return new DashboardDto(userTask.get(), ordersTask.get());
        }
    }
}
```

### Spring Security 7 Migration

```java
// BEFORE (v3.x — Spring Security 6):
@Bean
public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    return http
        .authorizeHttpRequests(auth -> auth
            .requestMatchers("/api/admin/**").hasRole("ADMIN")
            .anyRequest().authenticated()
        )
        .build();
}

// AFTER (v4.0 — Spring Security 7):
// URL-level authorization still works, but method-level is preferred
@Service
@PreAuthorize("hasRole('USER')")
public class OrderService {

    @PreAuthorize("hasRole('ADMIN') or #userId == authentication.name")
    public List<Order> getOrdersByUser(String userId) {
        return orderRepository.findByUserId(userId);
    }
}
```

### Spring Modulith Adoption

```java
// Module structure enforced by convention:
// com.example.app
//   ├── order/          — @Module: OrderService, OrderController, OrderRepository
//   │   └── internal/   — Package-private implementation details
//   ├── user/           — @Module: UserService, UserController
//   ├── payment/        — @Module: PaymentService
//   └── shared/         — Shared DTOs, events

// Verify module boundaries in tests:
@Test
void shouldHaveCleanModuleBoundaries() {
    ApplicationModules.of(Application.class).verify();
}
```

## v3.2 to v3.5 (Bridge to v4.0)

**Critical step**: v3.5 deprecates everything removed in v4.0. Upgrade here first and fix ALL deprecation warnings before attempting v4.

### Key Changes in v3.5

| Change | Impact | Action |
|--------|--------|--------|
| `@MockBean`/`@SpyBean` deprecated | Medium | Switch to `@MockitoBean`/`@MockitoSpyBean` |
| Classic starters deprecated | Low | Prepare for focused starters in v4 |
| Flyway/Liquibase explicit starters | Low | Add `spring-boot-starter-flyway`/`spring-boot-starter-liquibase` |
| WebClient global configuration | Low | Move WebClient config to properties |
| All v4-removed APIs deprecated | High | Fix every deprecation warning — they become compile errors in v4 |

## v3.5 to v4.0 Upgrade

### Prerequisites

- **Java 21 minimum** (17 no longer supported)
- **Spring Boot 3.5.x with zero deprecation warnings** (critical — all deprecated APIs are removed in v4)

### Key Changes in v4.0

| Change | Impact | Action |
|--------|--------|--------|
| Spring Framework 7, Jakarta EE 11 | High | Servlet 6.1, Persistence 3.2, Validation 3.1 |
| Jackson 3 default (`tools.jackson` package) | **Highest risk** | Add contract tests BEFORE upgrading |
| `@MockBean`/`@SpyBean` removed | Medium | Use `@MockitoBean`/`@MockitoSpyBean` |
| RestTemplate deprecated | Medium | Migrate to `RestClient` |
| Undertow removed | High (if used) | Switch to Tomcat or Jetty |
| Modularized starters | Medium | Replace monolithic starters with focused ones |
| Built-in `@Retryable`/`@ConcurrencyLimit` | Low | Evaluate replacing Spring Retry/Resilience4j |
| JSpecify null safety | Medium | Review for Kotlin compilation failures |
| API versioning built-in | Low | Evaluate for new versioned APIs |
| `spring-boot-starter-classic` available | Low | Use as transitional safety net |

### Jackson 3 Migration (Highest Risk)

```java
// Package change: com.fasterxml.jackson → tools.jackson
// BEFORE (Jackson 2):
import com.fasterxml.jackson.databind.ObjectMapper;

ObjectMapper mapper = new ObjectMapper();

// AFTER (Jackson 3):
import tools.jackson.databind.json.JsonMapper;

JsonMapper mapper = JsonMapper.builder().findAndAddModules().build();

// DEFAULT BEHAVIOR CHANGES:
//   SORT_PROPERTIES_ALPHABETICALLY = true  (was false — API responses reordered!)
//   WRITE_DATES_AS_TIMESTAMPS = false      (was true — dates now ISO-8601 strings!)

// MITIGATION: Use compatibility flag while transitioning
// application.properties:
// spring.jackson.use-jackson2-defaults=true

// Bridge module for gradual migration:
// Add spring-boot-jackson2 dependency as temporary bridge
```

### v4.0 Test Annotation Migration

```java
// BEFORE (Spring Boot 3.3 and earlier):
@MockBean
private UserService userService;

@SpyBean
private EmailService emailService;

// AFTER (Spring Boot 3.4+ / 4.0):
@MockitoBean
private UserService userService;

@MockitoSpyBean
private EmailService emailService;
```

### Built-in Resilience (replaces Spring Retry for basic cases)

```java
@Configuration
@EnableResilientMethods
public class ResilienceConfig {
}

@Service
public class ExternalApiClient {

    @Retryable  // 3 attempts, 1s delay, exponential backoff with jitter
    @ConcurrencyLimit(5)  // Max 5 concurrent threads
    public DataResponse fetchData(String query) {
        return restClient.get().uri("/data?q={q}", query).retrieve().body(DataResponse.class);
    }
}
// No external dependency needed — built into Spring Framework 7
// For advanced patterns (circuit breaker, rate limiting), still use Resilience4j
```

### Phased v4.0 Migration Approach

**Phase A — Stabilize (prerequisite):**
1. Upgrade to latest Spring Boot 3.5.x
2. Fix EVERY deprecation warning
3. Upgrade to Boot 4 using `spring-boot-starter-classic` starters
4. Verify application startup and core flows

**Phase B — Correctness:**
1. Add contract tests for JSON payloads (Jackson 3 changes serialization!)
2. Validate Jackson behavior against production fixtures
3. Explicitly define dependency graph (focused starters)
4. Test with production-like configuration

**Phase C — Convergence:**
1. Replace `spring-boot-starter-classic` with focused alternatives
2. Remove compatibility flags (`spring.jackson.use-jackson2-defaults`)
3. Re-validate observability and actuator behavior
4. Final cleanup

## Progressive Migration Strategy

### Phase 1: Preparation (Low Risk)

1. Upgrade Java version (17 for v3, 21 for v4)
2. Migrate JUnit 4 to JUnit 5
3. Fix all deprecation warnings at current version
4. Add Testcontainers for integration tests
5. Ensure CI/CD pipeline works with new Java version

### Phase 2: Namespace Migration (Medium Risk — v3.0)

1. Run OpenRewrite `UpgradeSpringBoot_3_0` recipe
2. Fix remaining javax to jakarta manually (3rd-party libs)
3. Migrate Spring Security to `SecurityFilterChain`
4. Update property names (redis, datasource, etc.)
5. Fix Hibernate 6 compatibility issues

### Phase 3: API Modernization (Medium Risk — v3.2)

1. Replace `RestTemplate` with `RestClient` in new code
2. Replace `@DynamicPropertySource` with `@ServiceConnection`
3. Enable virtual threads (if Java 21)
4. Adopt `JdbcClient` for simple SQL
5. Add SSL bundles for TLS configuration
6. Improve test suite: more slices, fewer full boot tests

### Phase 4: v4.0 Adoption (High Risk)

1. Upgrade Java to 21 (if not done)
2. Audit ThreadLocal usage (virtual threads break pinning)
3. Adopt structured concurrency for parallel calls
4. Migrate to Spring Security 7 patterns
5. Organize code with Spring Modulith
6. Remove all deprecated API usage from v3.x

## OpenRewrite Recipe Reference

| Recipe | What It Does |
|--------|-------------|
| `UpgradeSpringBoot_3_0` | Full v2.x to v3.0 migration (namespace, security, properties) |
| `UpgradeSpringBoot_3_2` | v3.0/3.1 to v3.2 migration |
| `UpgradeSpringBoot_3_4` | v3.2/3.3 to v3.4 migration |
| `UpgradeSpringBoot_3_5` | v3.4 to v3.5 migration (bridge to v4) |
| `UpgradeSpringBoot_4_0` | v3.5 to v4.0 migration (community edition) |
| `SpringBoot2JUnit4to5Migration` | JUnit 4 to JUnit 5 in Spring context |
| `MigrateToJakartaEE10` | javax to jakarta namespace only |
| `UpgradeSpringFramework_6_0` | Spring Framework 5 to 6 |
| `SpringSecurity5to6` | Spring Security 5 to 6 configuration |
| `UpgradeHibernate_6_0` | Hibernate 5 to 6 changes |
| `FindJavaxImports` | Report javax imports without changing (dry run) |
| `RemoveRedundantDependencyVersions` | Clean up managed dependency versions |

## Common Migration Pitfalls

1. **Skipping Java upgrade**: Boot 3.0 requires Java 17, Boot 4.0 requires Java 21. Upgrade Java FIRST.
2. **javax in third-party libraries**: Some libs still ship javax. Check transitive dependencies.
3. **Hibernate 6 ID generation change**: `GenerationType.AUTO` now uses sequences, not identity. Be explicit.
4. **Spring Security lambda DSL**: v6 requires lambda-based configuration. No more chained `.and()`.
5. **Spring Cloud version matrix**: Boot 3.0 requires Spring Cloud 2022.x+. Check compatibility.
6. **Property renames not caught**: `spring.redis.*` to `spring.data.redis.*` breaks silently.
7. **Flyway/Liquibase compatibility**: Upgrade these tools when upgrading Boot.
8. **Test pollution from @DirtiesContext**: Slows test suite. Use `@Transactional` or Testcontainers instead.
9. **Virtual thread pinning**: `synchronized` blocks and `ReentrantLock` can pin virtual threads.
10. **ThreadLocal in virtual threads**: Thread pools are not reused. Scoped values replace ThreadLocal in v4.
11. **Jackson 3 serialization changes**: Date format, property ordering, and null handling defaults changed silently — breaks API contracts without tests.
12. **Skipping v3.5 bridge**: v3.5 deprecates everything removed in v4. Going v3.4→v4 directly means no compiler warnings for removed APIs.
13. **Using `spring-boot-starter-classic` permanently**: It is a transitional aid — plan convergence to focused starters.
14. **`@MockBean` in v4**: Removed entirely. Must migrate all tests to `@MockitoBean`/`@MockitoSpyBean` before upgrading.
15. **Undertow in v4**: Removed (incompatible with Servlet 6.1). Switch to Tomcat or Jetty 12.1 before upgrading.

## Tracking Progress

```markdown
## Spring Boot Migration Progress (v[X] to v[Y])

| Phase | Task | Files | Done | % | Status |
|-------|------|-------|------|---|--------|
| 1 | Java version upgrade | - | - | 100% | Done |
| 1 | JUnit 4 to 5 migration | 30 | 30 | 100% | Done |
| 1 | Fix deprecation warnings | 15 | 15 | 100% | Done |
| 2 | OpenRewrite javax->jakarta | 85 | 85 | 100% | Done |
| 2 | Spring Security migration | 3 | 2 | 67% | In Progress |
| 2 | Property renames | 5 | 5 | 100% | Done |
| 3 | RestTemplate -> RestClient | 12 | 4 | 33% | In Progress |
| 3 | @ServiceConnection | 8 | 0 | 0% | Planned |
| 3 | Virtual threads eval | - | - | 0% | Planned |
| 4 | Structured concurrency | - | - | 0% | Planned |
| 4 | Spring Modulith | - | - | 0% | Planned |
```
