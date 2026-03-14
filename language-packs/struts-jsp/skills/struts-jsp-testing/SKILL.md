---
name: struts-jsp-testing
description: Testing patterns for legacy Struts/JSP applications. Characterization tests, Action testing, JSP testing, migration test safety nets.
user-invocable: false
allowed-tools: Read, Grep, Glob
catalog_description: Struts/JSP testing — characterization tests, Action testing, migration safety nets.
---

# Struts/JSP Testing Patterns

## Testing Legacy Code — The Archeology Approach

Legacy codebases rarely have adequate tests. The goal is NOT 100% coverage — it's creating a safety net for migration.

### Priority Order

1. **Characterization tests** — Capture current behavior (even if "wrong")
2. **Integration tests** — Test the full request/response cycle
3. **DAO/Repository tests** — Verify data access (often the riskiest layer)
4. **Action/Controller tests** — Test business logic in isolation
5. **JSP tests** — Lowest priority (views are being replaced anyway)

## Characterization Testing

Characterization tests document what the system currently does, not what it should do. They are the migration safety net.

### Pattern: HTTP Endpoint Characterization

```java
// Captures the CURRENT behavior of a Struts action
// Run this BEFORE migrating to Spring Boot
// Then run the SAME tests against the Spring Boot endpoint

@Test
public void characterize_listUsers_returns_200_with_user_table() {
    // Given: the /listUsers.do endpoint exists
    HttpResponse response = httpClient.get(baseUrl + "/listUsers.do");

    // Then: capture current behavior
    assertEquals(200, response.getStatusCode());
    assertTrue(response.getBody().contains("<table"));
    assertTrue(response.getBody().contains("User Name"));
    // Store response for comparison after migration
    Files.write(Path.of("test-snapshots/listUsers.html"), response.getBody());
}
```

### Pattern: Database State Characterization

```java
// Captures what a Struts action does to the database
@Test
public void characterize_saveUser_inserts_record() {
    // Given: empty users table
    int beforeCount = jdbc.queryForInt("SELECT COUNT(*) FROM users");

    // When: submit the form
    httpClient.post(baseUrl + "/saveUser.do",
        Map.of("firstName", "Test", "lastName", "User", "email", "test@example.com"));

    // Then: one new record
    int afterCount = jdbc.queryForInt("SELECT COUNT(*) FROM users");
    assertEquals(beforeCount + 1, afterCount);
}
```

## Struts 1.x Action Testing

### Using StrutsTestCase (Mock)

```java
import org.apache.struts.mock.MockHttpServletRequest;
import org.apache.struts.mock.MockHttpServletResponse;

public class UserActionTest extends MockStrutsTestCase {

    public void testListUsers() {
        setRequestPathInfo("/listUsers");
        actionPerform();
        verifyForward("success");
        verifyNoActionErrors();

        // Check request attributes
        List users = (List) getRequest().getAttribute("userList");
        assertNotNull(users);
    }

    public void testSaveUserValidation() {
        setRequestPathInfo("/saveUser");
        addRequestParameter("firstName", "");  // Required field empty
        actionPerform();
        verifyForward("input");
        verifyActionErrors(new String[]{"error.firstName.required"});
    }
}
```

### Testing Action in Isolation (No StrutsTestCase)

```java
// When StrutsTestCase is not available or too heavy
@Test
public void testUserActionExecute() {
    UserAction action = new UserAction();
    UserForm form = new UserForm();
    form.setFirstName("John");
    form.setLastName("Doe");

    // Mock dependencies
    MockHttpServletRequest request = new MockHttpServletRequest();
    MockHttpServletResponse response = new MockHttpServletResponse();
    ActionMapping mapping = new ActionMapping();
    mapping.addForwardConfig(new ActionForward("success", "/user/list.jsp", false));

    ActionForward forward = action.execute(mapping, form, request, response);

    assertEquals("success", forward.getName());
}
```

## Struts 2.x Action Testing

### Using JUnit + Spring Test

```java
// Struts 2 actions are POJOs — much easier to test
public class UserActionTest {

    private UserAction action;
    private UserService mockService;

    @Before
    public void setUp() {
        action = new UserAction();
        mockService = mock(UserService.class);
        action.setUserService(mockService);
    }

    @Test
    public void testListUsers() {
        when(mockService.findAll()).thenReturn(Arrays.asList(new User("John")));

        String result = action.execute();

        assertEquals("success", result);
        assertEquals(1, action.getUsers().size());
    }
}
```

## DAO/Repository Testing

### Pattern: In-Memory Database

```java
// Use H2 for testing legacy JDBC code
@Before
public void setUp() {
    dataSource = new EmbeddedDatabaseBuilder()
        .setType(EmbeddedDatabaseType.H2)
        .addScript("schema.sql")
        .addScript("test-data.sql")
        .build();
    userDao = new UserDaoImpl(dataSource);
}

@Test
public void testFindByEmail() {
    User user = userDao.findByEmail("john@example.com");
    assertNotNull(user);
    assertEquals("John", user.getFirstName());
}
```

### Pattern: Transaction Rollback

```java
// Ensure each test starts with clean state
@RunWith(SpringJUnit4ClassRunner.class)
@ContextConfiguration("classpath:test-context.xml")
@Transactional  // Rolls back after each test
public class UserDaoIntegrationTest {

    @Autowired
    private UserDao userDao;

    @Test
    public void testInsertAndFind() {
        User user = new User("Jane", "Doe", "jane@example.com");
        userDao.save(user);

        User found = userDao.findByEmail("jane@example.com");
        assertEquals("Jane", found.getFirstName());
    }
    // Transaction rolls back — no cleanup needed
}
```

## Migration Test Strategy

### Dual-Run Testing

Run the same test against both the old Struts endpoint and the new Spring Boot endpoint:

```java
@ParameterizedTest
@ValueSource(strings = {
    "http://localhost:8080/old-app",   // Struts
    "http://localhost:8081/new-app"    // Spring Boot
})
public void testListUsersEndpoint(String baseUrl) {
    HttpResponse response = httpClient.get(baseUrl + "/api/users");
    assertEquals(200, response.getStatusCode());

    List<User> users = parseJson(response.getBody(), new TypeReference<>(){});
    assertFalse(users.isEmpty());
    assertNotNull(users.get(0).getEmail());
}
```

### Contract Testing

Define the contract (URL, method, request/response shape) for each endpoint being migrated:

```java
// Contract: GET /users returns JSON array of users
// This test works against BOTH the Struts and Spring Boot implementations
@Test
public void contract_listUsers() {
    Response response = given()
        .accept(ContentType.JSON)
    .when()
        .get("/api/users")
    .then()
        .statusCode(200)
        .contentType(ContentType.JSON)
        .body("$", hasSize(greaterThan(0)))
        .body("[0].email", notNullValue())
        .extract().response();
}
```

## Test Infrastructure for Legacy Projects

### Dependencies to Add (Maven)

```xml
<dependencies>
    <!-- JUnit 4 (legacy projects) or JUnit 5 -->
    <dependency>
        <groupId>junit</groupId>
        <artifactId>junit</artifactId>
        <version>4.13.2</version>
        <scope>test</scope>
    </dependency>
    <!-- Mockito for mocking -->
    <dependency>
        <groupId>org.mockito</groupId>
        <artifactId>mockito-core</artifactId>
        <version>5.11.0</version>
        <scope>test</scope>
    </dependency>
    <!-- H2 for in-memory DB testing -->
    <dependency>
        <groupId>com.h2database</groupId>
        <artifactId>h2</artifactId>
        <version>2.2.224</version>
        <scope>test</scope>
    </dependency>
    <!-- REST Assured for HTTP endpoint testing -->
    <dependency>
        <groupId>io.rest-assured</groupId>
        <artifactId>rest-assured</artifactId>
        <version>5.4.0</version>
        <scope>test</scope>
    </dependency>
</dependencies>
```

## Common Testing Pitfalls in Legacy Projects

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| No test database | Tests hit production DB | H2 in-memory or Docker |
| Static utility classes | `DateUtils.now()` returns real time | PowerMock or extract interface |
| Thread.sleep in tests | Flaky, slow tests | Use Awaitility or CountDownLatch |
| File system dependencies | Tests fail on different OS | Temp directory rule, classpath resources |
| JNDI DataSource | `InitialContext` fails outside container | Replace with direct DataSource in tests |
| Singleton pattern | State leaks between tests | Reset singletons in `@After` or use DI |
