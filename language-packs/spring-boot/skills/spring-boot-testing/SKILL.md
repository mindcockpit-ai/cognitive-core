---
name: spring-boot-testing
description: "Spring Boot testing patterns with JUnit 5, test slices (@WebMvcTest, @DataJpaTest, @WebFluxTest), MockMvc, WebTestClient, Testcontainers with @ServiceConnection, Spring Security test support, and contract testing."
user-invocable: false
allowed-tools: Read, Grep, Glob
catalog_description: "Spring Boot testing — JUnit 5, test slices, MockMvc, Testcontainers, security testing."
---

# Spring Boot Testing Patterns (v2-v4)

## Testing Stack

| Layer | Tool | Purpose |
|-------|------|---------|
| Unit | JUnit 5 + Mockito | Fast, isolated service/utility testing |
| Integration (Slice) | @WebMvcTest, @DataJpaTest, etc. | Framework-aware slice testing |
| Integration (Full) | @SpringBootTest | Full application context testing |
| Database | Testcontainers | Real database in Docker |
| HTTP Mocking | WireMock | External service mocking |
| API Contract | Spring Cloud Contract | Consumer-driven contracts |
| Security | @WithMockUser, SecurityMockMvc | Security configuration testing |
| Coverage | JaCoCo | Code coverage reporting |

## Test Slice Reference

| Annotation | What It Loads | Use For |
|-----------|---------------|---------|
| `@WebMvcTest` | Controllers, filters, converters, advice | REST controller tests |
| `@DataJpaTest` | JPA repositories, EntityManager, Flyway | Repository/query tests |
| `@WebFluxTest` | WebFlux controllers, WebFilter | Reactive controller tests |
| `@JsonTest` | Jackson ObjectMapper, JsonComponent | JSON serialization tests |
| `@RestClientTest` | RestTemplate/RestClient auto-config | HTTP client tests |
| `@JdbcTest` | JdbcTemplate, DataSource | Plain JDBC tests |
| `@DataMongoTest` | MongoDB repositories, MongoTemplate | MongoDB tests |
| `@DataRedisTest` | Redis repositories, RedisTemplate | Redis tests |

## Controller Testing with @WebMvcTest

### Basic REST Controller Test

```java
@WebMvcTest(UserController.class)
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private UserService userService;

    @Test
    void shouldReturnUserById() throws Exception {
        var user = new User(1L, "alice@example.com", "Alice", UserStatus.ACTIVE);
        when(userService.getUser(1L)).thenReturn(user);

        mockMvc.perform(get("/api/v1/users/{id}", 1L)
                .accept(MediaType.APPLICATION_JSON))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("Alice"))
            .andExpect(jsonPath("$.email").value("alice@example.com"))
            .andExpect(jsonPath("$.status").value("ACTIVE"));
    }

    @Test
    void shouldReturn404WhenUserNotFound() throws Exception {
        when(userService.getUser(999L))
            .thenThrow(new EntityNotFoundException("User not found: 999"));

        mockMvc.perform(get("/api/v1/users/{id}", 999L))
            .andExpect(status().isNotFound())
            .andExpect(jsonPath("$.detail").value("User not found: 999"));
    }

    @Test
    void shouldCreateUserWithValidRequest() throws Exception {
        var request = new CreateUserRequest("alice@example.com", "Alice", "password123");
        var created = new User(1L, "alice@example.com", "Alice", UserStatus.ACTIVE);
        when(userService.createUser(any(CreateUserRequest.class))).thenReturn(created);

        mockMvc.perform(post("/api/v1/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {
                        "email": "alice@example.com",
                        "name": "Alice",
                        "password": "password123"
                    }
                    """))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").value(1))
            .andExpect(jsonPath("$.name").value("Alice"));
    }

    @Test
    void shouldRejectInvalidRequest() throws Exception {
        mockMvc.perform(post("/api/v1/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {
                        "email": "not-an-email",
                        "name": "",
                        "password": "short"
                    }
                    """))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.violations").isArray());
    }

    @Test
    void shouldReturnPaginatedUsers() throws Exception {
        var users = List.of(
            new User(1L, "alice@example.com", "Alice", UserStatus.ACTIVE),
            new User(2L, "bob@example.com", "Bob", UserStatus.ACTIVE)
        );
        var page = new PageImpl<>(users, PageRequest.of(0, 20), 2);
        when(userService.findAll(any(Pageable.class))).thenReturn(page);

        mockMvc.perform(get("/api/v1/users")
                .param("page", "0")
                .param("size", "20"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.content").isArray())
            .andExpect(jsonPath("$.content.length()").value(2))
            .andExpect(jsonPath("$.totalElements").value(2));
    }
}
```

### Testing with WebTestClient (WebFlux or Servlet)

```java
@WebMvcTest(UserController.class)
@AutoConfigureWebTestClient
class UserControllerWebTestClientTest {

    @Autowired
    private WebTestClient webTestClient;

    @MockitoBean
    private UserService userService;

    @Test
    void shouldReturnUserById() {
        var user = new User(1L, "alice@example.com", "Alice", UserStatus.ACTIVE);
        when(userService.getUser(1L)).thenReturn(user);

        webTestClient.get()
            .uri("/api/v1/users/{id}", 1L)
            .accept(MediaType.APPLICATION_JSON)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.name").isEqualTo("Alice")
            .jsonPath("$.email").isEqualTo("alice@example.com");
    }
}
```

## Repository Testing with @DataJpaTest

```java
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
class UserRepositoryTest {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private TestEntityManager entityManager;

    @Test
    void shouldFindUserByEmail() {
        var user = new User();
        user.setEmail("alice@example.com");
        user.setName("Alice");
        user.setStatus(UserStatus.ACTIVE);
        entityManager.persistAndFlush(user);

        var found = userRepository.findByEmail("alice@example.com");

        assertThat(found).isPresent();
        assertThat(found.get().getName()).isEqualTo("Alice");
    }

    @Test
    void shouldReturnEmptyWhenEmailNotFound() {
        var found = userRepository.findByEmail("nonexistent@example.com");

        assertThat(found).isEmpty();
    }

    @Test
    void shouldFindUsersByStatusPaginated() {
        for (int i = 0; i < 15; i++) {
            var user = new User();
            user.setEmail("user" + i + "@example.com");
            user.setName("User " + i);
            user.setStatus(i < 10 ? UserStatus.ACTIVE : UserStatus.INACTIVE);
            entityManager.persist(user);
        }
        entityManager.flush();

        var page = userRepository.findByStatus(UserStatus.ACTIVE, PageRequest.of(0, 5));

        assertThat(page.getContent()).hasSize(5);
        assertThat(page.getTotalElements()).isEqualTo(10);
        assertThat(page.getTotalPages()).isEqualTo(2);
    }

    @Test
    void shouldUpdateUserStatus() {
        var user = new User();
        user.setEmail("alice@example.com");
        user.setName("Alice");
        user.setStatus(UserStatus.ACTIVE);
        entityManager.persistAndFlush(user);

        int updated = userRepository.updateStatus(user.getId(), UserStatus.INACTIVE);

        assertThat(updated).isEqualTo(1);
        entityManager.clear();
        var refreshed = userRepository.findById(user.getId()).orElseThrow();
        assertThat(refreshed.getStatus()).isEqualTo(UserStatus.INACTIVE);
    }
}
```

## Service Testing (Unit)

```java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @InjectMocks
    private UserService userService;

    @Test
    void shouldCreateUserWithEncodedPassword() {
        var request = new CreateUserRequest("alice@example.com", "Alice", "plaintext");
        when(passwordEncoder.encode("plaintext")).thenReturn("encoded-hash");
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> {
            User saved = invocation.getArgument(0);
            saved.setId(1L);
            return saved;
        });

        var result = userService.createUser(request);

        assertThat(result.getId()).isEqualTo(1L);
        assertThat(result.getEmail()).isEqualTo("alice@example.com");
        verify(passwordEncoder).encode("plaintext");
        verify(userRepository).save(argThat(user ->
            user.getPassword().equals("encoded-hash")
        ));
    }

    @Test
    void shouldThrowWhenUserNotFound() {
        when(userRepository.findById(999L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> userService.getUser(999L))
            .isInstanceOf(EntityNotFoundException.class)
            .hasMessageContaining("999");
    }
}
```

## MockBean / SpyBean Proper Usage

```java
// GOOD: @MockitoBean in test slices (replaces bean in context)
@WebMvcTest(OrderController.class)
class OrderControllerTest {

    @MockitoBean
    private OrderService orderService;  // Mock replaces real bean

    @MockitoBean
    private InventoryService inventoryService;  // Mock dependency
}

// GOOD: @SpyBean when you need real behavior with selective overrides
@SpringBootTest
class NotificationServiceIntegrationTest {

    @SpyBean
    private EmailService emailService;  // Real bean, but can verify/stub

    @Test
    void shouldSendNotification() {
        doNothing().when(emailService).send(any());  // Stub external call

        notificationService.notify(new OrderPlacedEvent(1L));

        verify(emailService).send(argThat(email ->
            email.getSubject().contains("Order Confirmation")
        ));
    }
}

// BAD: Too many @MockitoBean = test is testing nothing
// If you mock everything, you are testing mock behavior, not real behavior
```

## Spring Security Test Support

### Testing Secured Endpoints

```java
@WebMvcTest(AdminController.class)
@Import(SecurityConfig.class)
class AdminControllerSecurityTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private AdminService adminService;

    @Test
    void shouldRejectUnauthenticatedAccess() throws Exception {
        mockMvc.perform(get("/api/v1/admin/users"))
            .andExpect(status().isUnauthorized());
    }

    @Test
    @WithMockUser(roles = "USER")
    void shouldRejectNonAdminAccess() throws Exception {
        mockMvc.perform(get("/api/v1/admin/users"))
            .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    void shouldAllowAdminAccess() throws Exception {
        when(adminService.getAllUsers()).thenReturn(List.of());

        mockMvc.perform(get("/api/v1/admin/users"))
            .andExpect(status().isOk());
    }

    @Test
    void shouldAuthenticateWithJwtToken() throws Exception {
        mockMvc.perform(get("/api/v1/admin/users")
                .with(jwt().authorities(new SimpleGrantedAuthority("ROLE_ADMIN"))))
            .andExpect(status().isOk());
    }
}
```

### Custom Security Test Annotations

```java
@Retention(RetentionPolicy.RUNTIME)
@WithMockUser(username = "admin@example.com", roles = {"ADMIN", "USER"})
public @interface WithMockAdmin {
}

@Retention(RetentionPolicy.RUNTIME)
@WithMockUser(username = "viewer@example.com", roles = "VIEWER")
public @interface WithMockViewer {
}

// Usage:
@Test
@WithMockAdmin
void shouldAccessAdminEndpoint() throws Exception {
    mockMvc.perform(get("/api/v1/admin/dashboard"))
        .andExpect(status().isOk());
}
```

## Testcontainers with @ServiceConnection (v3.1+)

### PostgreSQL

```java
@SpringBootTest
@Testcontainers
class ApplicationIntegrationTest {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
        .withDatabaseName("testdb")
        .withUsername("test")
        .withPassword("test");

    // No @DynamicPropertySource needed — @ServiceConnection handles it automatically

    @Autowired
    private UserRepository userRepository;

    @Test
    void shouldPersistAndRetrieveUser() {
        var user = new User("alice@example.com", "Alice");
        userRepository.save(user);

        var found = userRepository.findByEmail("alice@example.com");
        assertThat(found).isPresent();
    }
}
```

### Multiple Containers

```java
@SpringBootTest
@Testcontainers
class FullStackIntegrationTest {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @Container
    @ServiceConnection
    static GenericContainer<?> redis = new GenericContainer<>("redis:7-alpine")
        .withExposedPorts(6379);

    @Container
    @ServiceConnection
    static KafkaContainer kafka = new KafkaContainer(
        DockerImageName.parse("confluentinc/cp-kafka:7.6.0"));

    @Test
    void shouldProcessOrderEndToEnd() {
        // Full integration test with real Postgres, Redis, and Kafka
    }
}
```

### Shared Container Pattern (faster test suites)

```java
// Abstract base class — container shared across all test classes
@Testcontainers
public abstract class AbstractIntegrationTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
        .withReuse(true);  // Reuse between test runs (requires testcontainers.reuse.enable=true)

    @Container
    @ServiceConnection
    static final GenericContainer<?> redis = new GenericContainer<>("redis:7-alpine")
        .withExposedPorts(6379)
        .withReuse(true);
}

// Individual test classes extend the base
@SpringBootTest
class UserServiceIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    private UserService userService;

    @Test
    void shouldCreateAndCacheUser() {
        // Uses shared Postgres and Redis containers
    }
}
```

## Contract Testing with Spring Cloud Contract

### Producer Side

```groovy
// src/test/resources/contracts/user/shouldReturnUserById.groovy
Contract.make {
    description "should return user by ID"
    request {
        method GET()
        urlPath '/api/v1/users/1'
        headers {
            accept applicationJson()
        }
    }
    response {
        status OK()
        headers {
            contentType applicationJson()
        }
        body(
            id: 1,
            name: "Alice",
            email: "alice@example.com",
            status: "ACTIVE"
        )
    }
}
```

### Consumer Side (Stub Runner)

```java
@SpringBootTest
@AutoConfigureStubRunner(
    stubsMode = StubRunnerProperties.StubsMode.LOCAL,
    ids = "com.example:user-service:+:stubs:8081"
)
class OrderServiceContractTest {

    @Autowired
    private OrderService orderService;

    @Test
    void shouldFetchUserFromUserService() {
        var user = orderService.getUserForOrder(1L);

        assertThat(user.getName()).isEqualTo("Alice");
        assertThat(user.getEmail()).isEqualTo("alice@example.com");
    }
}
```

## Test Configuration Best Practices

### Test Profiles

```yaml
# src/test/resources/application-test.yml
spring:
  jpa:
    open-in-view: false
    hibernate:
      ddl-auto: create-drop
    show-sql: false
  flyway:
    enabled: true
  cache:
    type: none

logging:
  level:
    org.springframework.test: WARN
    org.hibernate.SQL: WARN
```

### Test Properties

```java
@SpringBootTest(properties = {
    "spring.cache.type=none",
    "spring.jpa.show-sql=false",
    "external.api.url=http://localhost:${wiremock.server.port}"
})
class ApplicationTest {
}
```

## Legacy Test Migration Guide

| Legacy Pattern | Modern Replacement |
|---------------|-------------------|
| JUnit 4 `@Test` (org.junit) | JUnit 5 `@Test` (org.junit.jupiter) |
| `@RunWith(SpringRunner.class)` | `@ExtendWith(SpringExtension.class)` (implicit) |
| `@RunWith(MockitoJUnitRunner.class)` | `@ExtendWith(MockitoExtension.class)` |
| `@Rule ExpectedException` | `assertThrows()` or AssertJ `assertThatThrownBy()` |
| `@Rule TemporaryFolder` | `@TempDir` (JUnit 5) |
| `@MockBean` (Spring Boot 3.3-) | `@MockitoBean` (Spring Boot 3.4+) |
| `@Before` / `@After` | `@BeforeEach` / `@AfterEach` |
| `@BeforeClass` / `@AfterClass` | `@BeforeAll` / `@AfterAll` |
| `@Ignore` | `@Disabled` |
| `@Category` | `@Tag` |
| H2 in-memory database | Testcontainers with real database |
| `@DynamicPropertySource` (v3.0) | `@ServiceConnection` (v3.1+) |
| `MockRestServiceServer` | WireMock or `@RestClientTest` |
| RestAssured with random port | `WebTestClient` with `@SpringBootTest(webEnvironment = RANDOM_PORT)` |
| XML test configuration | `@TestConfiguration` Java classes |
| Manual container lifecycle | `@Testcontainers` + `@Container` annotations |

## Anti-Patterns in Tests

1. **@SpringBootTest for everything**: Loads full context unnecessarily. Use test slices for focused, fast tests.
2. **Testing framework behavior**: Asserting that Spring validation works. Test YOUR validation rules.
3. **No error path testing**: Only testing happy paths. Test 4xx, 5xx, validation errors, null inputs.
4. **H2 database differences**: H2 behavior differs from Postgres/MySQL. Use Testcontainers for accuracy.
5. **Over-mocking in integration tests**: If everything is mocked, you are not testing integration.
6. **Missing `@Transactional` in data tests**: Tests that create data without cleanup pollute other tests.
7. **Thread.sleep in async tests**: Use `Awaitility.await().atMost(5, SECONDS).until(...)` instead.
8. **Ignoring test order dependencies**: Tests must be independent. Use `@DirtiesContext` only as last resort.
