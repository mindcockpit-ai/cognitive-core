## Python Critical Rules (Post-Compaction)

1. **Type Hints Required**: All function signatures must have parameter and return type hints. Use `X | None` (not `Optional[X]`). Use PEP 695 type aliases (`type Vector = list[float]`) in Python 3.12+.
2. **No Bare Except**: Never `except:` or `except Exception:` without specific handling. Catch specific exceptions. Log before re-raising with `from exc`.
3. **F-strings Over Format**: Use f-strings for interpolation. No `.format()` or `%` for new code. Exception: logging lazy formatting `log.info("msg %s", var)`.
4. **Pathlib Over os.path**: Use `pathlib.Path` for all file operations. No `os.path.join()`, `os.path.exists()` in new code.
5. **Pydantic v2 for DTOs**: Use `BaseModel` with `ConfigDict` (not inner `class Config`). Use `field_validator`/`model_validator` decorators. Frozen dataclasses for value objects.
6. **Async by Default**: Use `async def` for I/O-bound operations. Use `async with` for sessions/connections. Never block the event loop with sync I/O.
7. **Repository Pattern**: Abstract interfaces in domain layer, implementations in infrastructure. One repository per aggregate root.
