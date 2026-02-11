---
name: python-patterns
description: Python coding patterns, idioms, and anti-patterns for modern Python projects.
user-invocable: false
allowed-tools: Read, Grep, Glob
---

# Python Patterns -- Quick Reference

Background knowledge for Python projects. Auto-loaded for pattern guidance.

## Dataclass Template

```python
from __future__ import annotations
from dataclasses import dataclass, field

@dataclass
class Entity:
    id: int
    name: str
    tags: list[str] = field(default_factory=list)
    def validate(self) -> bool:
        if not self.name.strip(): raise ValueError("Empty name")
        return True
```

## Error Handling -- Catch specific exceptions, never bare `except:`

```python
try:
    result = repository.save(entity)
except DatabaseError as exc:
    logger.error("Save failed: %s", exc)
    raise ServiceError(f"Could not save: {exc}") from exc
```

## Type Hints

| Context | Pattern |
|---------|---------|
| Function | `def process(items: list[str]) -> dict[str, int]:` |
| Optional | `def find(id: int) -> Entity \| None:` |
| Generic | `def first(items: Sequence[T]) -> T:` |
| Callable | `handler: Callable[[Request], Response]` |

## Pathlib Over os.path

```python
# Wrong
import os
path = os.path.join(base, "data", "file.csv")
if os.path.exists(path): ...

# Correct
from pathlib import Path
path = Path(base) / "data" / "file.csv"
if path.exists(): ...
```

## String Formatting

```python
# Preferred: f-strings
msg = f"Processing {count} items for {user.name}"

# Logging: lazy formatting (no f-strings)
logger.info("Processing %d items for %s", count, user.name)
```

## Common Anti-Patterns

- Bare `except:` swallows all errors silently
- Mutable default arguments (`def f(items=[])`) share state
- `os.path` when `pathlib.Path` is cleaner
- Plain dicts for domain objects -- use dataclasses/Pydantic
- `type()` for type checks -- use `isinstance()`
- String concatenation in loops -- use `"".join()`
