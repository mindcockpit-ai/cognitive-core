---
name: spring-boot-e2e-testing
description: "Spring Boot E2E testing with Testcontainers for databases, WireMock for external services, REST Assured for API testing, @SpringBootTest with random port, Docker Compose integration, Spring Cloud Contract, and performance testing patterns."
user-invocable: false
allowed-tools: Read, Grep, Glob
catalog_description: "Spring Boot E2E testing — Testcontainers, WireMock, REST Assured, contract testing."
---

# Spring Boot E2E Testing Patterns

End-to-end testing patterns for Spring Boot applications covering database integration
with Testcontainers, external service mocking with WireMock, API testing with REST
Assured and WebTestClient, and contract-driven development.

## Architecture

```
E2E Test Suite
  ├── Database Layer
  │   ├── Testcontainers (PostgreSQL, MySQL, MongoDB, Oracle)
  │   └── @ServiceConnection (auto-config, v3.1+)
  ├── External Services
  │   ├── WireMock (HTTP API mocking)
  │   └── Spring Cloud Contract (consumer-driven contracts)
  ├── Message Brokers
  │   ├── Testcontainers Kafka
  │   └── Testcontainers RabbitMQ
  └── Test Clients
      ├── WebTestClient (Spring-native, reactive-compatible)
      ├── REST Assured (fluent DSL, BDD-style)
      └── MockMvc (servlet-layer, no real HTTP)
```

---

## 1. Testcontainers for Databases

### PostgreSQL

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class UserApiE2ETest {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
        .withDatabaseName("e2e_test")
        .withInitScript("db/init-test-data.sql");

    @Autowired
    private WebTestClient webTestClient;

    @Test
    void shouldCreateAndRetrieveUser() {
        // Create
        var response = webTestClient.post()
            .uri("/api/v1/users")
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue("""
                {
                    "email": "alice@example.com",
                    "name": "Alice",
                    "password": "secure123"
                }
                """)
            .exchange()
            .expectStatus().isCreated()
            .expectBody(UserResponse.class)
            .returnResult()
            .getResponseBody();

        assertThat(response).isNotNull();
        assertThat(response.id()).isNotNull();

        // Retrieve
        webTestClient.get()
            .uri("/api/v1/users/{id}", response.id())
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.name").isEqualTo("Alice")
            .jsonPath("$.email").isEqualTo("alice@example.com");
    }

    @Test
    void shouldReturnPaginatedResults() {
        webTestClient.get()
            .uri(uriBuilder -> uriBuilder
                .path("/api/v1/users")
                .queryParam("page", 0)
                .queryParam("size", 5)
                .build())
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.content").isArray()
            .jsonPath("$.totalElements").isNumber();
    }
}
```

### MySQL

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class MySqlIntegrationTest {

    @Container
    @ServiceConnection
    static MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.0")
        .withDatabaseName("testdb")
        .withUsername("test")
        .withPassword("test")
        .withCommand("--character-set-server=utf8mb4", "--collation-server=utf8mb4_unicode_ci");
}
```

### MongoDB

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class MongoIntegrationTest {

    @Container
    @ServiceConnection
    static MongoDBContainer mongo = new MongoDBContainer("mongo:7.0");

    @Autowired
    private MongoTemplate mongoTemplate;

    @BeforeEach
    void setUp() {
        mongoTemplate.dropCollection("users");
    }

    @Test
    void shouldStoreAndQueryDocuments() {
        var user = new UserDocument("alice@example.com", "Alice");
        mongoTemplate.save(user);

        var found = mongoTemplate.findById(user.getId(), UserDocument.class);
        assertThat(found).isNotNull();
        assertThat(found.getName()).isEqualTo("Alice");
    }
}
```

### Oracle (with Testcontainers Oracle-Free)

```java
@SpringBootTest
@Testcontainers
class OracleIntegrationTest {

    @Container
    @ServiceConnection
    static OracleContainer oracle = new OracleContainer("gvenzl/oracle-free:23-slim-faststart")
        .withDatabaseName("testdb")
        .withUsername("testuser")
        .withPassword("testpass");
}
```

---

## 2. WireMock for External Service Mocking

### Basic WireMock Setup

```java
@SpringBootTest(
    webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
    properties = "external.api.url=http://localhost:${wiremock.server.port}"
)
@WireMockTest(httpPort = 0)
class ExternalServiceE2ETest {

    @Autowired
    private WebTestClient webTestClient;

    @Test
    void shouldCallExternalServiceAndReturnResult(WireMockRuntimeInfo wmInfo) {
        // Stub external API
        stubFor(get(urlPathEqualTo("/external/users/123"))
            .willReturn(aResponse()
                .withStatus(200)
                .withHeader("Content-Type", "application/json")
                .withBody("""
                    {
                        "id": "123",
                        "name": "External User",
                        "verified": true
                    }
                    """)));

        // Call our API which internally calls the external service
        webTestClient.get()
            .uri("/api/v1/enriched-users/123")
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.name").isEqualTo("External User")
            .jsonPath("$.verified").isEqualTo(true);

        // Verify the external call was made
        verify(getRequestedFor(urlPathEqualTo("/external/users/123")));
    }

    @Test
    void shouldHandleExternalServiceTimeout(WireMockRuntimeInfo wmInfo) {
        stubFor(get(urlPathEqualTo("/external/users/123"))
            .willReturn(aResponse()
                .withFixedDelay(5000)  // 5 second delay
                .withStatus(200)));

        webTestClient.get()
            .uri("/api/v1/enriched-users/123")
            .exchange()
            .expectStatus().is5xxServerError();
    }

    @Test
    void shouldHandleExternalService500(WireMockRuntimeInfo wmInfo) {
        stubFor(get(urlPathEqualTo("/external/users/123"))
            .willReturn(aResponse()
                .withStatus(500)
                .withBody("Internal Server Error")));

        webTestClient.get()
            .uri("/api/v1/enriched-users/123")
            .exchange()
            .expectStatus().is5xxServerError()
            .expectBody()
            .jsonPath("$.detail").exists();
    }
}
```

### WireMock with State (Scenario)

```java
@Test
void shouldHandleOAuthTokenRefresh(WireMockRuntimeInfo wmInfo) {
    // First call returns 401 (token expired)
    stubFor(get(urlPathEqualTo("/external/data"))
        .inScenario("auth-flow")
        .whenScenarioStateIs(Scenario.STARTED)
        .willReturn(aResponse().withStatus(401))
        .willSetStateTo("token-refreshed"));

    // After refresh, call succeeds
    stubFor(get(urlPathEqualTo("/external/data"))
        .inScenario("auth-flow")
        .whenScenarioStateIs("token-refreshed")
        .willReturn(aResponse()
            .withStatus(200)
            .withBody("{\"data\": \"success\"}")));

    // Stub token endpoint
    stubFor(post(urlPathEqualTo("/oauth/token"))
        .willReturn(aResponse()
            .withStatus(200)
            .withBody("{\"access_token\": \"new-token\", \"expires_in\": 3600}")));

    webTestClient.get()
        .uri("/api/v1/data")
        .exchange()
        .expectStatus().isOk();
}
```

---

## 3. REST Assured Patterns

### Setup with Spring Boot

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class UserApiRestAssuredTest {

    @LocalServerPort
    private int port;

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @BeforeEach
    void setUp() {
        RestAssured.port = port;
        RestAssured.basePath = "/api/v1";
    }

    @Test
    void shouldCreateUser() {
        given()
            .contentType(ContentType.JSON)
            .body("""
                {
                    "email": "alice@example.com",
                    "name": "Alice",
                    "password": "secure123"
                }
                """)
        .when()
            .post("/users")
        .then()
            .statusCode(201)
            .body("id", notNullValue())
            .body("name", equalTo("Alice"))
            .body("email", equalTo("alice@example.com"));
    }

    @Test
    void shouldListUsersWithPagination() {
        given()
            .queryParam("page", 0)
            .queryParam("size", 10)
        .when()
            .get("/users")
        .then()
            .statusCode(200)
            .body("content", hasSize(lessThanOrEqualTo(10)))
            .body("totalElements", greaterThanOrEqualTo(0));
    }

    @Test
    void shouldValidateRequestBody() {
        given()
            .contentType(ContentType.JSON)
            .body("""
                {
                    "email": "not-an-email",
                    "name": "",
                    "password": "x"
                }
                """)
        .when()
            .post("/users")
        .then()
            .statusCode(400)
            .body("violations", hasSize(greaterThan(0)));
    }
}
```

---

## 4. @SpringBootTest with Random Port + WebTestClient

### Full CRUD Workflow Test

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class OrderWorkflowE2ETest {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @Autowired
    private WebTestClient webTestClient;

    private static String orderId;

    @Test
    @Order(1)
    void shouldCreateOrder() {
        var response = webTestClient.post()
            .uri("/api/v1/orders")
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue("""
                {
                    "customerId": "customer-001",
                    "items": [
                        {"productId": "prod-1", "quantity": 2, "price": 29.99},
                        {"productId": "prod-2", "quantity": 1, "price": 49.99}
                    ]
                }
                """)
            .exchange()
            .expectStatus().isCreated()
            .expectBody(OrderResponse.class)
            .returnResult()
            .getResponseBody();

        assertThat(response).isNotNull();
        assertThat(response.status()).isEqualTo("PENDING");
        assertThat(response.totalAmount()).isEqualByComparingTo(new BigDecimal("109.97"));
        orderId = response.id();
    }

    @Test
    @Order(2)
    void shouldRetrieveCreatedOrder() {
        webTestClient.get()
            .uri("/api/v1/orders/{id}", orderId)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.id").isEqualTo(orderId)
            .jsonPath("$.status").isEqualTo("PENDING")
            .jsonPath("$.items.length()").isEqualTo(2);
    }

    @Test
    @Order(3)
    void shouldConfirmOrder() {
        webTestClient.post()
            .uri("/api/v1/orders/{id}/confirm", orderId)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.status").isEqualTo("CONFIRMED");
    }

    @Test
    @Order(4)
    void shouldCancelOrder() {
        webTestClient.post()
            .uri("/api/v1/orders/{id}/cancel", orderId)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.status").isEqualTo("CANCELLED");
    }
}
```

---

## 5. Docker Compose Integration

### @ServiceConnection with Docker Compose (v3.1+)

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ServiceConnection(
    name = "compose",
    type = DockerComposeServiceConnection.class
)
class DockerComposeE2ETest {

    // Uses src/test/resources/compose-test.yml automatically
    // Spring Boot auto-detects services and configures connections

    @Autowired
    private WebTestClient webTestClient;

    @Test
    void shouldWorkWithFullStack() {
        webTestClient.get()
            .uri("/api/v1/health")
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.database").isEqualTo("UP")
            .jsonPath("$.redis").isEqualTo("UP");
    }
}
```

```yaml
# src/test/resources/compose-test.yml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: testdb
      POSTGRES_USER: test
      POSTGRES_PASSWORD: test
    ports:
      - "5432"

  redis:
    image: redis:7-alpine
    ports:
      - "6379"

  kafka:
    image: confluentinc/cp-kafka:7.6.0
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
    ports:
      - "9092"
```

---

## 6. Contract Testing with Spring Cloud Contract

### Producer (API Provider)

```groovy
// src/test/resources/contracts/user/get_user_by_id.groovy
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
            name: $(producer("Alice"), consumer(regex("[A-Za-z]+")))  ,
            email: $(producer("alice@example.com"), consumer(regex("[\\w.]+@[\\w.]+")))  ,
            status: "ACTIVE"
        )
    }
}
```

```java
// Base class for generated contract tests
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
@AutoConfigureMockMvc
public abstract class ContractTestBase {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private UserService userService;

    @BeforeEach
    void setUp() {
        RestAssuredMockMvc.mockMvc(mockMvc);

        when(userService.getUser(1L)).thenReturn(
            new User(1L, "alice@example.com", "Alice", UserStatus.ACTIVE)
        );
    }
}
```

### Consumer (API Client)

```java
@SpringBootTest
@AutoConfigureStubRunner(
    stubsMode = StubRunnerProperties.StubsMode.LOCAL,
    ids = "com.example:user-service:+:stubs:8081"
)
class OrderServiceContractTest {

    @Autowired
    private UserClient userClient;

    @Test
    void shouldFetchUserFromStub() {
        var user = userClient.getUser("1");

        assertThat(user.getName()).isNotEmpty();
        assertThat(user.getEmail()).contains("@");
        assertThat(user.getStatus()).isEqualTo("ACTIVE");
    }
}
```

---

## 7. Security E2E Testing

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class SecurityE2ETest {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @Autowired
    private WebTestClient webTestClient;

    @Test
    void shouldRejectUnauthenticatedRequest() {
        webTestClient.get()
            .uri("/api/v1/users")
            .exchange()
            .expectStatus().isUnauthorized();
    }

    @Test
    @WithMockUser(roles = "USER")
    void shouldAllowAuthenticatedAccess() {
        webTestClient
            .mutateWith(mockUser().roles("USER"))
            .get()
            .uri("/api/v1/users")
            .exchange()
            .expectStatus().isOk();
    }

    @Test
    void shouldAllowAccessWithValidJwt() {
        webTestClient
            .mutateWith(mockJwt()
                .authorities(new SimpleGrantedAuthority("ROLE_ADMIN")))
            .get()
            .uri("/api/v1/admin/users")
            .exchange()
            .expectStatus().isOk();
    }

    @Test
    void shouldRejectExpiredToken() {
        webTestClient
            .mutateWith(mockJwt()
                .jwt(jwt -> jwt.expiresAt(Instant.now().minusSeconds(3600))))
            .get()
            .uri("/api/v1/users")
            .exchange()
            .expectStatus().isUnauthorized();
    }
}
```

---

## 8. Performance Testing Integration

### Gatling with Spring Boot

```java
// Gatling simulation (Scala DSL)
class UserApiSimulation extends Simulation {

  val httpProtocol = http
    .baseUrl("http://localhost:8080")
    .acceptHeader("application/json")
    .contentTypeHeader("application/json")

  val createUser = scenario("Create Users")
    .exec(
      http("Create User")
        .post("/api/v1/users")
        .body(StringBody("""{"email":"user${randomInt}@example.com","name":"User","password":"pass123"}"""))
        .check(status.is(201))
        .check(jsonPath("$.id").saveAs("userId"))
    )
    .exec(
      http("Get User")
        .get("/api/v1/users/${userId}")
        .check(status.is(200))
    )

  setUp(
    createUser.inject(
      rampUsersPerSec(1).to(50).during(60),
      constantUsersPerSec(50).during(120)
    )
  ).protocols(httpProtocol)
   .assertions(
     global.responseTime.mean.lt(500),
     global.successfulRequests.percent.gt(99)
   )
}
```

### JMeter Integration via Maven

```xml
<!-- pom.xml -->
<plugin>
    <groupId>com.lazerycode.jmeter</groupId>
    <artifactId>jmeter-maven-plugin</artifactId>
    <version>3.8.0</version>
    <executions>
        <execution>
            <id>performance-tests</id>
            <goals>
                <goal>jmeter</goal>
            </goals>
        </execution>
    </executions>
    <configuration>
        <testFilesDirectory>${project.basedir}/src/test/jmeter</testFilesDirectory>
        <resultsDirectory>${project.build.directory}/jmeter/results</resultsDirectory>
    </configuration>
</plugin>
```

---

## 9. Test Organization Best Practices

### Directory Structure

```
src/test/
  ├── java/com/example/app/
  │   ├── unit/           — @ExtendWith(MockitoExtension.class)
  │   │   ├── service/
  │   │   └── util/
  │   ├── integration/    — @DataJpaTest, @WebMvcTest (test slices)
  │   │   ├── repository/
  │   │   └── controller/
  │   ├── e2e/            — @SpringBootTest(RANDOM_PORT) + Testcontainers
  │   │   ├── api/
  │   │   └── workflow/
  │   └── contract/       — Spring Cloud Contract
  │       ├── base/
  │       └── consumer/
  ├── resources/
  │   ├── application-test.yml
  │   ├── compose-test.yml
  │   ├── db/
  │   │   └── init-test-data.sql
  │   └── contracts/
  │       └── user/
  └── jmeter/             — Performance test plans
```

### Maven Profile for E2E Tests

```xml
<profile>
    <id>e2e</id>
    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-failsafe-plugin</artifactId>
                <configuration>
                    <includes>
                        <include>**/*E2E.java</include>
                        <include>**/*IT.java</include>
                    </includes>
                </configuration>
            </plugin>
        </plugins>
    </build>
</profile>
```

---

## 10. Debugging Playbook

| Symptom | Likely Cause | Debug Action |
|---------|-------------|--------------|
| Container startup timeout | Docker not running or slow pull | Check `docker info`, increase startup timeout |
| Connection refused | Port not mapped or wrong host | Log container mapped port, use `@ServiceConnection` |
| Flyway migration fails | Schema already exists / wrong order | Use `spring.flyway.clean-disabled=false` in test |
| Test data pollution | Missing `@Transactional` or cleanup | Add `@Transactional` or `@DirtiesContext` |
| WireMock not intercepting | Wrong URL or stub registered late | Register stubs in `@BeforeEach`, log unmatched requests |
| Flaky async tests | Race conditions | Use `Awaitility.await()` instead of `Thread.sleep` |
| OutOfMemoryError in tests | Too many full context loads | Use test slices, shared containers, `@DirtiesContext` sparingly |
| Spring context caching fails | Conflicting `@MockitoBean` | Align mock configurations across test classes |
| Contract test generation error | Base class not found | Check `contractsMode` and base class configuration |
| Slow test suite | Many `@SpringBootTest` | Replace with test slices, use shared Testcontainers |
