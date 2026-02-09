---
name: python-patterns
extends: global:check-pattern
description: Python/FastAPI patterns and standards template. Copy and customize for your Python project.
argument-hint: [pattern-type] [file]
allowed-tools: Read, Grep, Glob, Edit
---

# Python Patterns (Template)

Cellular skill template for Python/FastAPI projects. Extend and customize for your specific project.

## How to Use This Template

1. Copy to your project: `cp -r . .claude/skills/python-patterns/`
2. Customize patterns for your codebase
3. Add project-specific anti-patterns
4. Configure fitness thresholds

## Type Hints (PEP 484)

### Required: All Functions Typed

```python
# CORRECT: Full type hints
def find_user_by_id(self, user_id: int) -> Optional[User]:
    """Find user by ID."""
    return self.repository.find_by_id(user_id)

def create_user(self, request: CreateUserRequest) -> UserResponse:
    """Create a new user."""
    user = self.mapper.to_entity(request)
    saved = self.repository.save(user)
    return self.mapper.to_response(saved)

# WRONG: Missing type hints
def find_user_by_id(self, user_id):
    return self.repository.find_by_id(user_id)
```

## Pydantic Models

### Required: Use Pydantic for DTOs

```python
from pydantic import BaseModel, EmailStr, Field
from datetime import datetime

# CORRECT: Pydantic model with validation
class CreateUserRequest(BaseModel):
    email: EmailStr
    first_name: str = Field(..., min_length=1, max_length=100)
    last_name: str = Field(..., min_length=1, max_length=100)

class UserResponse(BaseModel):
    id: int
    email: EmailStr
    first_name: str
    last_name: str
    created_at: datetime

    class Config:
        from_attributes = True  # SQLAlchemy compatibility

# WRONG: Plain dict or unvalidated class
class CreateUserRequest:
    def __init__(self, email, first_name, last_name):
        self.email = email  # No validation!
```

## Async/Await Patterns

### Required: Async for I/O Operations

```python
# CORRECT: Async database operations
async def find_by_id(self, user_id: int) -> Optional[User]:
    result = await self.db.execute(
        select(User).where(User.id == user_id)
    )
    return result.scalar_one_or_none()

# CORRECT: Async HTTP calls
async def fetch_external_data(self, url: str) -> dict:
    async with httpx.AsyncClient() as client:
        response = await client.get(url)
        return response.json()

# WRONG: Blocking I/O in async context
async def find_by_id(self, user_id: int) -> Optional[User]:
    # This blocks the event loop!
    return self.db.query(User).filter(User.id == user_id).first()
```

## Dependency Injection

### Required: FastAPI Depends

```python
from fastapi import Depends
from sqlalchemy.orm import Session

# CORRECT: Dependency injection
def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_user_service(db: Session = Depends(get_db)) -> UserService:
    repository = UserRepository(db)
    mapper = UserMapper()
    return UserService(repository, mapper)

@router.get("/{user_id}")
async def get_user(
    user_id: int,
    service: UserService = Depends(get_user_service)
) -> ApiResponse[UserResponse]:
    user = await service.find_by_id(user_id)
    return ApiResponse.success(user)

# WRONG: Global instances
db = SessionLocal()  # Global mutable state!
service = UserService(db)  # Not injectable
```

## Error Handling

### Required: Specific Exception Handling

```python
from fastapi import HTTPException, status

# CORRECT: Specific exceptions
async def find_by_id(self, user_id: int) -> UserResponse:
    user = await self.repository.find_by_id(user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User not found: {user_id}"
        )
    return self.mapper.to_response(user)

# CORRECT: Custom exceptions
class UserNotFoundError(Exception):
    def __init__(self, user_id: int):
        self.user_id = user_id
        super().__init__(f"User not found: {user_id}")

# WRONG: Bare except
try:
    user = await self.repository.find_by_id(user_id)
except:  # Catches everything including KeyboardInterrupt!
    pass
```

## Logging

### Required: Structured Logging

```python
import logging
from typing import Any

logger = logging.getLogger(__name__)

# CORRECT: Structured logging with context
async def create_user(self, request: CreateUserRequest) -> UserResponse:
    logger.info(
        "Creating user",
        extra={"email": request.email, "action": "user_create"}
    )
    try:
        user = await self._do_create(request)
        logger.info(
            "User created successfully",
            extra={"user_id": user.id, "email": request.email}
        )
        return user
    except Exception as e:
        logger.error(
            "Failed to create user",
            extra={"email": request.email, "error": str(e)},
            exc_info=True
        )
        raise

# WRONG: Print statements or unstructured logging
print(f"Creating user {request.email}")  # Not logged!
logger.info(f"Creating user {request.email}")  # No structure
```

## Anti-Patterns

### Never Use

| Anti-Pattern | Why | Alternative |
|--------------|-----|-------------|
| `except:` (bare) | Catches system exits | `except Exception:` |
| Mutable defaults | Shared state bugs | `= None` + initialize |
| `import *` | Namespace pollution | Explicit imports |
| Global mutable state | Thread safety issues | Dependency injection |
| Sync I/O in async | Blocks event loop | Use async libraries |

### Mutable Default Arguments

```python
# WRONG: Mutable default
def process_items(items: list = []):  # Same list reused!
    items.append("new")
    return items

# CORRECT: None default with initialization
def process_items(items: Optional[list] = None) -> list:
    if items is None:
        items = []
    items.append("new")
    return items
```

## Fitness Criteria

| Function | Threshold | Description |
|----------|-----------|-------------|
| `type_hints` | 95% | Functions have type annotations |
| `pydantic_models` | 100% | DTOs use Pydantic |
| `async_patterns` | 100% | Async for I/O operations |
| `dependency_injection` | 100% | FastAPI Depends pattern |
| `no_bare_except` | 100% | No bare except clauses |
| `structured_logging` | 90% | Logger with context |
| `test_coverage` | 70% | pytest coverage |

## Linting Tools

```bash
# Recommended: ruff (fast, comprehensive)
ruff check src/
ruff format src/

# Type checking: mypy
mypy src/ --strict

# Security: bandit
bandit -r src/
```

## Usage

```bash
# Check specific pattern
/python-patterns type-hints src/services/user_service.py

# Check all patterns
/python-patterns all src/

# List available patterns
/python-patterns --list
```

## See Also

- `/spring-patterns` - Java/Spring equivalent
- `/pre-commit` - Pre-commit checks
- `/code-review` - Full code review
