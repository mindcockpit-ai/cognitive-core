# Testing Pattern

Comprehensive testing strategy for reliable, maintainable software.

## Problem

- Bugs reach production without detection
- Refactoring breaks existing functionality
- Tests are slow, flaky, or hard to maintain
- Coverage gaps in critical paths
- Different test types serve different purposes

## Solution: Test Pyramid

```
                    ┌───────────────┐
                    │     E2E       │  Few, slow, high confidence
                    │    Tests      │
                ┌───┴───────────────┴───┐
                │    Integration Tests   │  Some, medium speed
            ┌───┴───────────────────────┴───┐
            │         Unit Tests             │  Many, fast, focused
            └───────────────────────────────┘
```

## Abstract Interface

```python
# Test case protocol
class TestCase(Protocol):
    def setup(self) -> None: ...
    def teardown(self) -> None: ...
    def run(self) -> TestResult: ...

# Assertion interface
class Assertions(Protocol):
    def assert_equal(self, actual: Any, expected: Any) -> None: ...
    def assert_true(self, condition: bool) -> None: ...
    def assert_raises(self, exception: type, callable: Callable) -> None: ...
    def assert_called_with(self, mock: Mock, *args, **kwargs) -> None: ...

# Test fixture protocol
class Fixture(Protocol):
    def create(self) -> T: ...
    def cleanup(self) -> None: ...
```

## Test Types

### 1. Unit Tests

Test individual components in isolation.

```python
# CORRECT: Unit test with mocked dependencies
class TestUserService:
    def setup_method(self):
        self.repository = Mock(spec=UserRepository)
        self.mapper = Mock(spec=UserMapper)
        self.service = UserService(self.repository, self.mapper)

    def test_find_by_id_returns_user(self):
        # Arrange
        user = User(id=1, email="test@example.com", name="Test")
        self.repository.find_by_id.return_value = user
        self.mapper.to_response.return_value = UserResponse(
            id=1, email="test@example.com", name="Test"
        )

        # Act
        result = self.service.find_by_id(1)

        # Assert
        assert result.id == 1
        self.repository.find_by_id.assert_called_once_with(1)
```

### 2. Integration Tests

Test component interactions.

```python
# CORRECT: Integration test with real database
class TestUserRepository:
    @pytest.fixture(autouse=True)
    def setup(self, test_database):
        self.db = test_database
        self.repository = UserRepository(self.db)

    def test_create_and_find_user(self):
        # Arrange
        request = CreateUserRequest(
            email="test@example.com",
            first_name="Test",
            last_name="User"
        )

        # Act
        created = self.repository.create(request)
        found = self.repository.find_by_id(created.id)

        # Assert
        assert found is not None
        assert found.email == "test@example.com"
```

### 3. End-to-End Tests

Test complete user flows.

```python
# CORRECT: E2E test with API client
class TestUserWorkflow:
    def test_complete_user_lifecycle(self, api_client):
        # Create user
        response = api_client.post("/users", json={
            "email": "e2e@example.com",
            "firstName": "E2E",
            "lastName": "Test"
        })
        assert response.status_code == 201
        user_id = response.json()["data"]["id"]

        # Read user
        response = api_client.get(f"/users/{user_id}")
        assert response.status_code == 200
        assert response.json()["data"]["email"] == "e2e@example.com"

        # Update user
        response = api_client.put(f"/users/{user_id}", json={
            "firstName": "Updated"
        })
        assert response.status_code == 200

        # Delete user
        response = api_client.delete(f"/users/{user_id}")
        assert response.status_code == 204
```

## Patterns

### 1. Arrange-Act-Assert (AAA)

```python
def test_calculate_total():
    # Arrange - Setup test data
    items = [Item(price=10), Item(price=20), Item(price=30)]
    calculator = PriceCalculator()

    # Act - Execute the behavior
    total = calculator.calculate(items)

    # Assert - Verify the outcome
    assert total == 60
```

### 2. Test Fixtures

```python
# Shared fixtures
@pytest.fixture
def user_factory():
    def create_user(**kwargs):
        defaults = {
            "email": f"user-{uuid4()}@example.com",
            "first_name": "Test",
            "last_name": "User"
        }
        return User(**{**defaults, **kwargs})
    return create_user

@pytest.fixture
def authenticated_client(api_client, user_factory):
    user = user_factory()
    token = auth_service.create_token(user)
    api_client.headers["Authorization"] = f"Bearer {token}"
    return api_client
```

### 3. Test Doubles

| Type | Purpose | Example |
|------|---------|---------|
| **Stub** | Return canned responses | `repository.find.return_value = user` |
| **Mock** | Verify interactions | `mock.assert_called_once()` |
| **Spy** | Record calls, call real | `spy.call_count` |
| **Fake** | Working implementation | In-memory database |

### 4. Parameterized Tests

```python
@pytest.mark.parametrize("email,valid", [
    ("valid@example.com", True),
    ("invalid", False),
    ("", False),
    ("no-domain@", False),
    ("@no-local.com", False),
])
def test_email_validation(email, valid):
    result = validate_email(email)
    assert result.is_valid == valid
```

## Trade-offs

| Aspect | Benefit | Cost |
|--------|---------|------|
| More tests | Higher confidence | Maintenance burden |
| Fast tests | Quick feedback | May miss integration issues |
| Real dependencies | Accurate results | Slow, flaky |
| High coverage | Find more bugs | Diminishing returns |

## Implementation Examples

| Language | Framework | Guide |
|----------|-----------|-------|
| **Python** | pytest | [pytest/](./implementations/pytest/) |
| **Java** | JUnit 5 | [junit/](./implementations/junit/) |
| **TypeScript** | Jest | [jest/](./implementations/jest/) |
| **TypeScript** | Vitest | [vitest/](./implementations/vitest/) |

## Language-Specific Examples

### Python (pytest)

```python
import pytest
from unittest.mock import Mock, patch

class TestUserService:
    @pytest.fixture(autouse=True)
    def setup(self):
        self.repository = Mock(spec=UserRepository)
        self.service = UserService(self.repository)

    def test_find_existing_user(self):
        self.repository.find_by_id.return_value = User(id=1, name="Test")
        result = self.service.find_by_id(1)
        assert result.name == "Test"

    def test_find_nonexistent_user_raises(self):
        self.repository.find_by_id.return_value = None
        with pytest.raises(UserNotFoundError):
            self.service.find_by_id(999)
```

### Java (JUnit 5)

```java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {
    @Mock
    private UserRepository repository;

    @InjectMocks
    private UserService service;

    @Test
    void findById_existingUser_returnsUser() {
        when(repository.findById(1L))
            .thenReturn(Optional.of(new User(1L, "Test")));

        var result = service.findById(1L);

        assertThat(result.getName()).isEqualTo("Test");
        verify(repository).findById(1L);
    }

    @Test
    void findById_nonexistentUser_throwsException() {
        when(repository.findById(999L))
            .thenReturn(Optional.empty());

        assertThrows(UserNotFoundException.class,
            () -> service.findById(999L));
    }
}
```

### TypeScript (Vitest)

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';

describe('UserService', () => {
  let repository: MockedObject<UserRepository>;
  let service: UserService;

  beforeEach(() => {
    repository = {
      findById: vi.fn(),
      create: vi.fn(),
    };
    service = new UserService(repository);
  });

  it('finds existing user', async () => {
    repository.findById.mockResolvedValue({ id: 1, name: 'Test' });

    const result = await service.findById(1);

    expect(result.name).toBe('Test');
    expect(repository.findById).toHaveBeenCalledWith(1);
  });

  it('throws for nonexistent user', async () => {
    repository.findById.mockResolvedValue(null);

    await expect(service.findById(999))
      .rejects.toThrow(UserNotFoundError);
  });
});
```

## Fitness Criteria

| Criteria | Threshold | Description |
|----------|-----------|-------------|
| `code_coverage` | 70% | Line coverage minimum |
| `branch_coverage` | 60% | Branch coverage minimum |
| `critical_paths` | 100% | All critical paths tested |
| `unit_test_ratio` | 70% | Unit tests vs total |
| `test_isolation` | 100% | Tests don't affect each other |
| `test_speed` | 10s | Unit suite under 10 seconds |

## See Also

- [CI/CD](../ci-cd/) - Running tests in pipelines
- [Security](../security/) - Security testing
- [API Integration](../api-integration/) - Testing API clients
