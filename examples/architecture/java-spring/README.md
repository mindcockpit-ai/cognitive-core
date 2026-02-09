# Java Spring Boot DDD Architecture Example

Enterprise Java application using Spring Boot and Domain-Driven Design patterns.

## Stack

- **Language**: Java 17+
- **Framework**: Spring Boot 3.x
- **ORM**: Spring Data JPA / Hibernate
- **Database**: Oracle/PostgreSQL (abstracted)
- **Build**: Maven/Gradle

## Project Structure

```
src/main/java/com/example/myapp/
├── domain/                        # Pure business logic
│   ├── entity/
│   │   ├── User.java
│   │   ├── Order.java
│   │   └── Product.java
│   ├── valueobject/
│   │   ├── Email.java
│   │   ├── Money.java
│   │   └── DateRange.java
│   └── event/
│       └── OrderCreatedEvent.java
│
├── repository/                    # Data access layer
│   ├── UserRepository.java
│   ├── OrderRepository.java
│   └── ProductRepository.java
│
├── service/                       # Business orchestration
│   ├── UserService.java
│   ├── OrderService.java
│   └── ImportService.java
│
├── mapper/                        # DTO transformations
│   ├── UserMapper.java
│   ├── OrderMapper.java
│   └── DataTableMapper.java
│
├── controller/                    # HTTP layer
│   ├── api/
│   │   ├── UserController.java
│   │   └── OrderController.java
│   └── gui/
│       └── DashboardController.java
│
├── dto/                           # Data Transfer Objects
│   ├── request/
│   │   └── CreateUserRequest.java
│   └── response/
│       ├── UserResponse.java
│       └── ApiResponse.java
│
├── infrastructure/                # Cross-cutting
│   ├── config/
│   │   ├── DatabaseConfig.java
│   │   └── SecurityConfig.java
│   └── exception/
│       └── GlobalExceptionHandler.java
│
└── util/                          # Utilities
    └── DateTimeUtil.java

src/test/java/com/example/myapp/  # Tests mirror source
├── unit/
│   ├── domain/
│   ├── service/
│   └── mapper/
└── integration/
    ├── repository/
    └── controller/
```

## Code Standards

### Entity (Domain Layer)

```java
package com.example.myapp.domain.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;

@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(name = "first_name", nullable = false)
    private String firstName;

    @Column(name = "last_name", nullable = false)
    private String lastName;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }
}
```

### Repository (Data Access Layer)

```java
package com.example.myapp.repository;

import com.example.myapp.domain.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByEmail(String email);

    @Query("SELECT u FROM User u WHERE u.lastName LIKE %:name%")
    List<User> findByLastNameContaining(String name);

    // Bulk operations - Spring Data handles chunking internally
    List<User> findByIdIn(List<Long> ids);
}
```

### Service (Business Logic Layer)

```java
package com.example.myapp.service;

import com.example.myapp.domain.entity.User;
import com.example.myapp.dto.response.UserResponse;
import com.example.myapp.mapper.UserMapper;
import com.example.myapp.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class UserService {

    private final UserRepository userRepository;
    private final UserMapper userMapper;

    @Transactional(readOnly = true)
    public UserResponse findById(Long id) {
        log.debug("Finding user by ID: {}", id);

        User user = userRepository.findById(id)
            .orElseThrow(() -> new EntityNotFoundException("User not found: " + id));

        return userMapper.toResponse(user);
    }

    @Transactional(readOnly = true)
    public List<UserResponse> findAll() {
        log.debug("Finding all users");

        return userRepository.findAll().stream()
            .map(userMapper::toResponse)
            .toList();
    }

    @Transactional
    public UserResponse create(CreateUserRequest request) {
        log.info("Creating user: {}", request.getEmail());

        User user = userMapper.toEntity(request);
        User saved = userRepository.save(user);

        return userMapper.toResponse(saved);
    }
}
```

### Mapper (Transformation Layer)

```java
package com.example.myapp.mapper;

import com.example.myapp.domain.entity.User;
import com.example.myapp.dto.request.CreateUserRequest;
import com.example.myapp.dto.response.UserResponse;
import org.springframework.stereotype.Component;

@Component
public class UserMapper {

    public UserResponse toResponse(User user) {
        if (user == null) return null;

        return UserResponse.builder()
            .id(user.getId())
            .email(user.getEmail())
            .firstName(user.getFirstName())
            .lastName(user.getLastName())
            .createdAt(user.getCreatedAt())
            .build();
    }

    public User toEntity(CreateUserRequest request) {
        User user = new User();
        user.setEmail(request.getEmail());
        user.setFirstName(request.getFirstName());
        user.setLastName(request.getLastName());
        return user;
    }
}
```

### Controller (HTTP Layer)

```java
package com.example.myapp.controller.api;

import com.example.myapp.dto.request.CreateUserRequest;
import com.example.myapp.dto.response.ApiResponse;
import com.example.myapp.dto.response.UserResponse;
import com.example.myapp.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<UserResponse>> getUser(@PathVariable Long id) {
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
        return ResponseEntity.ok(ApiResponse.success(user));
    }
}
```

### DTO Pattern

```java
package com.example.myapp.dto.response;

import lombok.Builder;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@Builder
public class UserResponse {
    private Long id;
    private String email;
    private String firstName;
    private String lastName;
    private LocalDateTime createdAt;
}

@Data
@Builder
public class ApiResponse<T> {
    private boolean success;
    private T data;
    private String error;

    public static <T> ApiResponse<T> success(T data) {
        return ApiResponse.<T>builder()
            .success(true)
            .data(data)
            .build();
    }

    public static <T> ApiResponse<T> error(String message) {
        return ApiResponse.<T>builder()
            .success(false)
            .error(message)
            .build();
    }
}
```

## Anti-Patterns to Avoid

| Anti-Pattern | Why Bad | Correct Pattern |
|--------------|---------|-----------------|
| Entity in controller response | Exposes internals, lazy loading issues | Use DTO/Response |
| Repository in controller | Violates DDD layers | Use Service |
| Business logic in controller | Hard to test, scattered logic | Use Service |
| Catching generic Exception | Hides errors | Catch specific exceptions |
| Field injection (@Autowired) | Hard to test | Constructor injection |

## cognitive-core Skills

Install the Java cellular skills:

```bash
cp -r cognitive-core/skills/cellular/templates/java-spring/* .claude/skills/
```

### Fitness Criteria

| Function | Threshold |
|----------|-----------|
| `constructor_injection` | 100% |
| `dto_usage` | 100% |
| `repository_pattern` | 100% |
| `transactional_annotation` | 100% |
| `slf4j_logging` | 100% |
| `validation_annotations` | 90% |
| `test_coverage` | 70% |

## Testing

```bash
# Run all tests
./mvnw test

# Run with coverage
./mvnw test jacoco:report

# Run specific test
./mvnw test -Dtest=UserServiceTest
```

## See Also

- [perl-ddd/](../perl-ddd/) - Same patterns in Perl
- [python-fastapi/](../python-fastapi/) - Same patterns in Python
