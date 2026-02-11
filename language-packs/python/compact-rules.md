## Python Critical Rules (Post-Compaction)

1. **Type Hints Required**: All function signatures must include parameter and return type hints. Use `from __future__ import annotations` for forward references.
2. **No Bare Except**: Never use `except:` or `except Exception:` without specific handling. Catch specific exceptions. Log before re-raising.
3. **F-strings Over Format**: Use f-strings for string interpolation. No `.format()` or `%` formatting for new code. Exception: logging lazy formatting `log.info("msg %s", var)`.
4. **Pathlib Over os.path**: Use `pathlib.Path` for all file path operations. No `os.path.join()`, `os.path.exists()`, etc. in new code.
5. **Dataclasses/Pydantic**: Use `@dataclass` or Pydantic `BaseModel` for data structures. No plain dicts for domain objects. No mutable default arguments.
