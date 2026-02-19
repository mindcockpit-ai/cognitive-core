---
name: python-patterns
description: Modern Python 3.12+ patterns, idioms, and anti-patterns. Covers Pydantic v2, async, type hints, dataclasses, and community best practices.
user-invocable: false
allowed-tools: Read, Grep, Glob
catalog_description: Modern Python 3.12+ patterns — Pydantic v2, async, type hints, dataclasses.
---

# Python Patterns — Modern Python 3.12+

Background knowledge for Python projects. Auto-loaded for pattern guidance.

## Type Hints (PEP 695 / 3.12+)

### Modern Syntax

```python
# 3.12+ type alias syntax (PEP 695)
type Vector = list[float]
type UserDict = dict[str, "User"]
type Result[T] = T | None

# 3.12+ generic classes (no more TypeVar boilerplate)
class Stack[T]:
    def __init__(self) -> None:
        self._items: list[T] = []

    def push(self, item: T) -> None:
        self._items.append(item)

    def pop(self) -> T:
        return self._items.pop()

# 3.12+ generic functions
def first[T](items: Sequence[T]) -> T | None:
    return items[0] if items else None
```

### Common Patterns

| Context | Pattern |
|---------|---------|
| Function | `def process(items: list[str]) -> dict[str, int]:` |
| Nullable | `def find(id: int) -> User \| None:` |
| Generic | `def first[T](items: Sequence[T]) -> T:` |
| Callable | `handler: Callable[[Request], Response]` |
| Collection | `items: list[int]` not `List[int]` |
| Mapping | `data: dict[str, Any]` not `Dict[str, Any]` |
| Union | `value: str \| int` not `Union[str, int]` |
| Self | `def copy(self) -> Self:` (from `typing import Self`) |
| Override | `@override` decorator for method overrides (PEP 698) |

### Avoid Legacy Typing

```python
# WRONG: Legacy typing imports (pre-3.9)
from typing import List, Dict, Optional, Union, Tuple

# CORRECT: Built-in generics + union operator
items: list[int]
data: dict[str, Any]
result: str | None
pair: tuple[int, str]
```

## Pydantic v2 Models

### ConfigDict (Not Inner Class)

```python
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from typing import Self

class UserResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,       # ORM mode (replaces orm_mode)
        str_strip_whitespace=True,
        frozen=True,                # Immutable after creation
    )

    id: int
    email: str
    display_name: str = Field(min_length=1, max_length=100)

    @field_validator("email")
    @classmethod
    def normalize_email(cls, v: str) -> str:
        return v.lower().strip()

    @model_validator(mode="after")
    def check_consistency(self) -> Self:
        if not self.display_name and not self.email:
            raise ValueError("Either display_name or email required")
        return self
```

### Discriminated Unions

```python
from pydantic import BaseModel
from typing import Literal

class AgentComponent(BaseModel):
    type: Literal["agent"] = "agent"
    name: str
    model: str

class SkillComponent(BaseModel):
    type: Literal["skill"] = "skill"
    name: str
    invocable: bool

type Component = AgentComponent | SkillComponent  # PEP 695
```

## Dataclasses — Value Objects

```python
from dataclasses import dataclass, field

@dataclass(frozen=True, slots=True)
class Email:
    """Value object — immutable, equality by value."""
    value: str

    def __post_init__(self) -> None:
        if "@" not in self.value:
            raise ValueError(f"Invalid email: {self.value}")

@dataclass(slots=True)
class Entity:
    id: int
    name: str
    tags: list[str] = field(default_factory=list)
```

Key rules:
- `frozen=True` for value objects (immutable)
- `slots=True` for memory efficiency (Python 3.10+)
- `field(default_factory=list)` never `= []`
- Use `__post_init__` for validation

## Async Patterns

### Async Context Managers

```python
from contextlib import asynccontextmanager
from collections.abc import AsyncGenerator

@asynccontextmanager
async def get_session() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_maker() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise

# Usage
async with get_session() as session:
    await session.execute(stmt)
```

### Async Iteration

```python
async def stream_results(query: str) -> AsyncGenerator[Row, None]:
    async with get_session() as session:
        result = await session.stream(select(Model).where(...))
        async for row in result:
            yield row
```

### TaskGroup (3.11+)

```python
async def fetch_all(urls: list[str]) -> list[Response]:
    async with asyncio.TaskGroup() as tg:
        tasks = [tg.create_task(fetch(url)) for url in urls]
    return [t.result() for t in tasks]
```

## Structural Pattern Matching

```python
match command:
    case {"action": "create", "name": str(name)}:
        return create_component(name)
    case {"action": "delete", "id": int(id_)}:
        return delete_component(id_)
    case {"action": str(action)}:
        raise ValueError(f"Unknown action: {action}")
    case _:
        raise TypeError("Invalid command format")
```

## Error Handling

```python
# Specific exceptions with context, chain with 'from'
try:
    result = await repository.save(entity)
except IntegrityError as exc:
    raise DuplicateError(f"Entity {entity.id} already exists") from exc
except DatabaseError as exc:
    logger.error("Save failed for %s: %s", entity.id, exc)
    raise ServiceError(f"Could not save entity") from exc
```

### Custom Exception Hierarchy

```python
class DomainError(Exception):
    """Base for all domain errors."""

class NotFoundError(DomainError):
    def __init__(self, entity: str, id: str | int) -> None:
        super().__init__(f"{entity} not found: {id}")
        self.entity = entity
        self.id = id

class ValidationError(DomainError):
    def __init__(self, field: str, message: str) -> None:
        super().__init__(f"Validation error on {field}: {message}")
```

## Logging

```python
import logging
from typing import Any

logger = logging.getLogger(__name__)

# Lazy formatting (not f-strings) — avoids formatting if level is disabled
logger.info("Processing %d items for user %s", count, user_id)

# Structured context via extra
logger.info("Component published", extra={
    "component_id": str(component.id),
    "type": component.type.value,
    "author": component.author_handle,
})

# Exception logging with traceback
except Exception:
    logger.exception("Unexpected error in %s", operation_name)
    raise
```

## File & Path Operations

```python
from pathlib import Path

# Reading / writing
config = Path("config") / "settings.toml"
content = config.read_text(encoding="utf-8")
config.write_text(new_content, encoding="utf-8")

# Directory operations
Path("output").mkdir(parents=True, exist_ok=True)
py_files = list(Path("src").rglob("*.py"))

# Never use
# os.path.join(), os.path.exists(), os.makedirs()
```

## Testing Patterns

```python
import pytest
from unittest.mock import AsyncMock, patch

@pytest.fixture
def mock_repo() -> AsyncMock:
    repo = AsyncMock()
    repo.find_by_id.return_value = make_user(id=1)
    return repo

@pytest.mark.asyncio
async def test_get_user(mock_repo: AsyncMock) -> None:
    service = UserService(repo=mock_repo)
    result = await service.get_user(user_id=1)

    assert result.id == 1
    mock_repo.find_by_id.assert_awaited_once_with(1)

# Parametrize for multiple cases
@pytest.mark.parametrize("email,valid", [
    ("user@example.com", True),
    ("invalid", False),
    ("", False),
])
def test_email_validation(email: str, valid: bool) -> None:
    if valid:
        Email(value=email)
    else:
        with pytest.raises(ValueError):
            Email(value=email)
```

## Anti-Patterns

| Anti-Pattern | Why | Alternative |
|--------------|-----|-------------|
| `except:` (bare) | Catches SystemExit, KeyboardInterrupt | `except Exception:` |
| `def f(items=[])` | Shared mutable state across calls | `items: list \| None = None` |
| `import *` | Namespace pollution, breaks tooling | Explicit imports |
| `Optional[X]` | Legacy typing syntax | `X \| None` |
| `List[int]`, `Dict[str, T]` | Legacy typing | `list[int]`, `dict[str, T]` |
| `os.path.join()` | Verbose, platform issues | `Path() / "sub"` |
| `requests.get()` in async | Blocks event loop | `httpx.AsyncClient` |
| `time.sleep()` in async | Blocks event loop | `asyncio.sleep()` |
| `class Config:` in Pydantic | v1 syntax | `model_config = ConfigDict(...)` |
| Global mutable state | Thread safety, testability | Dependency injection |
| `type()` for checks | Doesn't handle subclasses | `isinstance()` |
| String concat in loops | O(n^2) allocation | `"".join(parts)` |
