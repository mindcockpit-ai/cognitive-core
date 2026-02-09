---
name: spring-patterns
extends: global:check-pattern
description: Java/Spring Boot patterns and standards template. Copy and customize for your Java project.
argument-hint: [pattern-type] [file]
allowed-tools: Read, Grep, Glob, Edit
---

# Spring Patterns (Template)

Cellular skill template for Java/Spring Boot projects. Extend and customize for your specific project.

## How to Use This Template

1. Copy to your project: `cp -r . .claude/skills/spring-patterns/`
2. Customize patterns for your codebase
3. Add project-specific anti-patterns
4. Configure fitness thresholds

## Constructor Injection

### Required: Constructor-Based DI

```java
// CORRECT: Constructor injection with Lombok
@Service
@RequiredArgsConstructor
public class UserService {
    private final UserRepository userRepository;
    private final UserMapper userMapper;

    public UserResponse findById(Long id) {
        // ...
    }
}

// CORRECT: Explicit constructor
@Service
public class UserService {
    private final UserRepository userRepository;
    private final UserMapper userMapper;

    public UserService(UserRepository userRepository, UserMapper userMapper) {
        this.userRepository = userRepository;
        this.userMapper = userMapper;
    }
}

// WRONG: Field injection
@Service
public class UserService {
    @Autowired
    private UserRepository userRepository;  // Hard to test!

    @Autowired
    private UserMapper userMapper;
}
```

## DTO Pattern

### Required: Separate DTOs from Entities

```java
// CORRECT: Request DTO with validation
public record CreateUserRequest(
    @NotNull @Email String email,
    @NotBlank @Size(max = 100) String firstName,
    @NotBlank @Size(max = 100) String lastName
) {}

// CORRECT: Response DTO
@Builder
public record UserResponse(
    Long id,
    String email,
    String firstName,
    String lastName,
    LocalDateTime createdAt
) {}

// CORRECT: API wrapper
@Builder
public record ApiResponse<T>(
    boolean success,
    T data,
    String error
) {
    public static <T> ApiResponse<T> success(T data) {
        return ApiResponse.<T>builder().success(true).data(data).build();
    }

    public static <T> ApiResponse<T> error(String message) {
        return ApiResponse.<T>builder().success(false).error(message).build();
    }
}

// WRONG: Entity in controller response
@GetMapping("/{id}")
public User getUser(@PathVariable Long id) {
    return userRepository.findById(id).orElseThrow();  // Exposes entity!
}
```

## Transaction Management

### Required: Proper @Transactional Usage

```java
// CORRECT: Read-only for queries
@Service
@RequiredArgsConstructor
public class UserService {

    @Transactional(readOnly = true)
    public UserResponse findById(Long id) {
        User user = userRepository.findById(id)
            .orElseThrow(() -> new EntityNotFoundException("User not found: " + id));
        return userMapper.toResponse(user);
    }

    @Transactional
    public UserResponse create(CreateUserRequest request) {
        User user = userMapper.toEntity(request);
        User saved = userRepository.save(user);
        return userMapper.toResponse(saved);
    }
}

// WRONG: Missing transaction annotation
public UserResponse create(CreateUserRequest request) {
    User user = userMapper.toEntity(request);
    User saved = userRepository.save(user);  // May not commit!
    return userMapper.toResponse(saved);
}

// WRONG: Transaction on private method (doesn't work)
@Transactional
private void doSomething() {  // Proxy can't intercept!
    // ...
}
```

## Exception Handling

### Required: Specific Exceptions with @ControllerAdvice

```java
// CORRECT: Custom exception
public class EntityNotFoundException extends RuntimeException {
    public EntityNotFoundException(String message) {
        super(message);
    }
}

// CORRECT: Global exception handler
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(EntityNotFoundException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public ApiResponse<Void> handleNotFound(EntityNotFoundException ex) {
        log.warn("Entity not found: {}", ex.getMessage());
        return ApiResponse.error(ex.getMessage());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ApiResponse<Void> handleValidation(MethodArgumentNotValidException ex) {
        String message = ex.getBindingResult().getFieldErrors().stream()
            .map(e -> e.getField() + ": " + e.getDefaultMessage())
            .collect(Collectors.joining(", "));
        return ApiResponse.error(message);
    }

    @ExceptionHandler(Exception.class)
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    public ApiResponse<Void> handleGeneral(Exception ex) {
        log.error("Unexpected error", ex);
        return ApiResponse.error("Internal server error");
    }
}

// WRONG: Catching generic Exception in service
try {
    return userRepository.save(user);
} catch (Exception e) {  // Too broad!
    throw new RuntimeException(e);
}
```

## Logging

### Required: SLF4J with Lombok

```java
// CORRECT: Lombok @Slf4j annotation
@Service
@RequiredArgsConstructor
@Slf4j
public class UserService {

    public UserResponse findById(Long id) {
        log.debug("Finding user by ID: {}", id);

        User user = userRepository.findById(id)
            .orElseThrow(() -> {
                log.warn("User not found: {}", id);
                return new EntityNotFoundException("User not found: " + id);
            });

        return userMapper.toResponse(user);
    }

    public UserResponse create(CreateUserRequest request) {
        log.info("Creating user: {}", request.email());

        try {
            User user = userMapper.toEntity(request);
            User saved = userRepository.save(user);
            log.info("User created successfully: id={}", saved.getId());
            return userMapper.toResponse(saved);
        } catch (Exception e) {
            log.error("Failed to create user: {}", request.email(), e);
            throw e;
        }
    }
}

// WRONG: System.out.println
System.out.println("Creating user: " + request.email());  // Not logged!

// WRONG: String concatenation in log
log.info("Creating user: " + request.email());  // Evaluated even if level disabled
```

## Repository Pattern

### Required: Spring Data JPA Repositories

```java
// CORRECT: Repository interface
@Repository
public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByEmail(String email);

    @Query("SELECT u FROM User u WHERE u.lastName LIKE %:name%")
    List<User> findByLastNameContaining(@Param("name") String name);

    // Bulk operations - Spring handles efficiently
    List<User> findByIdIn(List<Long> ids);
}

// CORRECT: Custom repository implementation (if needed)
public interface UserRepositoryCustom {
    List<User> findWithComplexCriteria(UserSearchCriteria criteria);
}

@Repository
@RequiredArgsConstructor
public class UserRepositoryCustomImpl implements UserRepositoryCustom {
    private final EntityManager em;

    @Override
    public List<User> findWithComplexCriteria(UserSearchCriteria criteria) {
        // CriteriaBuilder implementation
    }
}

// WRONG: Direct EntityManager in service
@Service
public class UserService {
    @PersistenceContext
    private EntityManager em;  // Use Repository instead!
}
```

## Controller Pattern

### Required: Proper REST Controller Structure

```java
// CORRECT: RESTful controller
@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
@Validated
public class UserController {
    private final UserService userService;

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<UserResponse>> getUser(
            @PathVariable Long id) {
        UserResponse user = userService.findById(id);
        return ResponseEntity.ok(ApiResponse.success(user));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<List<UserResponse>>> getAllUsers() {
        List<UserResponse> users = userService.findAll();
        return ResponseEntity.ok(ApiResponse.success(users));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<UserResponse>> createUser(
            @Valid @RequestBody CreateUserRequest request) {
        UserResponse user = userService.create(request);
        return ResponseEntity
            .status(HttpStatus.CREATED)
            .body(ApiResponse.success(user));
    }
}

// WRONG: Business logic in controller
@PostMapping
public ResponseEntity<UserResponse> createUser(@RequestBody CreateUserRequest request) {
    // Validation should be in service!
    if (userRepository.findByEmail(request.email()).isPresent()) {
        throw new ConflictException("Email exists");
    }
    User user = new User();
    user.setEmail(request.email());
    // ... more logic that belongs in service
}
```

## Anti-Patterns

### Never Use

| Anti-Pattern | Why | Alternative |
|--------------|-----|-------------|
| Field injection | Hard to test | Constructor injection |
| Entity in response | Exposes internals | Use DTO |
| `@Transactional` on private | Proxy doesn't intercept | Public methods only |
| Catching `Exception` | Too broad | Specific exceptions |
| String concat in log | Performance | Parameterized logging |

## Fitness Criteria

| Function | Threshold | Description |
|----------|-----------|-------------|
| `constructor_injection` | 100% | No @Autowired on fields |
| `dto_usage` | 100% | DTOs for API boundaries |
| `transactional` | 100% | Proper @Transactional usage |
| `repository_pattern` | 100% | Spring Data repositories |
| `slf4j_logging` | 100% | @Slf4j with parameterized logs |
| `validation_annotations` | 90% | @Valid on request bodies |
| `test_coverage` | 70% | JUnit/Mockito coverage |

## Build Tools

```xml
<!-- pom.xml recommended plugins -->
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-checkstyle-plugin</artifactId>
</plugin>
<plugin>
    <groupId>com.github.spotbugs</groupId>
    <artifactId>spotbugs-maven-plugin</artifactId>
</plugin>
<plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
</plugin>
```

## Usage

```bash
# Check specific pattern
/spring-patterns injection src/main/java/com/example/service/UserService.java

# Check all patterns
/spring-patterns all src/main/java/

# List available patterns
/spring-patterns --list
```

## See Also

- `/python-patterns` - Python/FastAPI equivalent
- `/pre-commit` - Pre-commit checks
- `/code-review` - Full code review
