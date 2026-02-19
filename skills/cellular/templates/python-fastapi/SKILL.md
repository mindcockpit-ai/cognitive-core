---
name: python-patterns
extends: global:check-pattern
description: FastAPI + SQLAlchemy 2.0 async + Pydantic v2 patterns. Production-ready templates for modern Python APIs.
argument-hint: [pattern-type] [file]
allowed-tools: Read, Grep, Glob, Edit
---

# FastAPI Patterns (Template)

Cellular skill template for FastAPI + SQLAlchemy 2.0 + Pydantic v2 projects. Copy and customize.

## How to Use This Template

1. Copy to your project: `cp -r . .claude/skills/python-patterns/`
2. Customize patterns for your codebase
3. Add project-specific anti-patterns

## Pydantic v2 Schemas

### Request/Response Models

```python
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from typing import Self
from datetime import datetime

# Request schema — validation at API boundary
class CreateComponentRequest(BaseModel):
    name: str = Field(min_length=1, max_length=100, pattern=r"^[a-z][a-z0-9-]*$")
    type: ComponentType
    description: str = Field(max_length=500)
    version: str = Field(pattern=r"^\d+\.\d+\.\d+$")

    @field_validator("name")
    @classmethod
    def normalize_name(cls, v: str) -> str:
        return v.lower().strip()

# Response schema — serialization from ORM
class ComponentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    type: ComponentType
    description: str
    version: str
    rating_average: float
    download_count: int
    created_at: datetime

# Paginated response
class PaginatedResponse[T](BaseModel):
    items: list[T]
    total: int
    page: int
    page_size: int
    has_next: bool
```

### Settings with pydantic-settings

```python
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="APP_",
        case_sensitive=False,
    )

    database_url: str
    redis_url: str = "redis://localhost:6379"
    secret_key: str
    debug: bool = False
    cors_origins: list[str] = ["http://localhost:3000"]

settings = Settings()
```

## SQLAlchemy 2.0 Async

### Engine & Session Factory

```python
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from sqlalchemy import String, Text, DateTime, func
from datetime import datetime
from uuid import UUID, uuid4

class Base(DeclarativeBase):
    pass

# Annotated types for reuse
from typing import Annotated

intpk = Annotated[int, mapped_column(primary_key=True)]
uuid_pk = Annotated[UUID, mapped_column(primary_key=True, default=uuid4)]
str_255 = Annotated[str, mapped_column(String(255))]
created_at = Annotated[datetime, mapped_column(DateTime, server_default=func.now())]
updated_at = Annotated[datetime, mapped_column(DateTime, server_default=func.now(), onupdate=func.now())]

# Engine with connection pooling
engine = create_async_engine(
    settings.database_url,
    echo=settings.debug,
    pool_size=20,
    max_overflow=10,
    pool_pre_ping=True,
)

async_session = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)
```

### Table Models (Mapped Columns)

```python
from sqlalchemy import ForeignKey, JSON
from sqlalchemy.orm import relationship

class ComponentModel(Base):
    __tablename__ = "components"

    id: Mapped[uuid_pk]
    name: Mapped[str_255]
    type: Mapped[str] = mapped_column(String(50))
    description: Mapped[str] = mapped_column(Text)
    version: Mapped[str] = mapped_column(String(20))
    frontmatter: Mapped[dict] = mapped_column(JSON, default=dict)
    status: Mapped[str] = mapped_column(String(20), default="draft")
    download_count: Mapped[int] = mapped_column(default=0)
    rating_average: Mapped[float] = mapped_column(default=0.0)
    author_id: Mapped[UUID] = mapped_column(ForeignKey("authors.id"))
    created_at: Mapped[created_at]
    updated_at: Mapped[updated_at]

    author: Mapped["AuthorModel"] = relationship(back_populates="components")
    ratings: Mapped[list["RatingModel"]] = relationship(back_populates="component")
```

### Async Session Dependency

```python
from collections.abc import AsyncGenerator

async def get_session() -> AsyncGenerator[AsyncSession, None]:
    async with async_session() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
```

### Repository Pattern

```python
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload

class ComponentRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def find_by_id(self, id: UUID) -> ComponentModel | None:
        stmt = (
            select(ComponentModel)
            .where(ComponentModel.id == id)
            .options(selectinload(ComponentModel.ratings))
        )
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def search(
        self,
        query: str | None = None,
        type_filter: str | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> tuple[list[ComponentModel], int]:
        stmt = select(ComponentModel)

        if query:
            stmt = stmt.where(ComponentModel.name.ilike(f"%{query}%"))
        if type_filter:
            stmt = stmt.where(ComponentModel.type == type_filter)

        # Count total
        count_stmt = select(func.count()).select_from(stmt.subquery())
        total = (await self._session.execute(count_stmt)).scalar() or 0

        # Paginate
        stmt = stmt.offset((page - 1) * page_size).limit(page_size)
        result = await self._session.execute(stmt)
        return list(result.scalars().all()), total

    async def save(self, component: ComponentModel) -> ComponentModel:
        self._session.add(component)
        await self._session.flush()
        return component
```

## FastAPI Dependency Injection

### Layered Dependencies

```python
from fastapi import Depends

# Layer 1: Session
async def get_session() -> AsyncGenerator[AsyncSession, None]: ...

# Layer 2: Repositories
async def get_component_repo(
    session: AsyncSession = Depends(get_session),
) -> ComponentRepository:
    return ComponentRepository(session)

# Layer 3: Services (use cases)
async def get_component_service(
    repo: ComponentRepository = Depends(get_component_repo),
    validator: ComponentValidator = Depends(),
) -> ComponentService:
    return ComponentService(repo=repo, validator=validator)

# Layer 4: Route handler
@router.get("/{component_id}")
async def get_component(
    component_id: UUID,
    service: ComponentService = Depends(get_component_service),
) -> ComponentResponse:
    return await service.get_by_id(component_id)
```

### App Factory with Lifespan

```python
from contextlib import asynccontextmanager
from collections.abc import AsyncGenerator

@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    # Startup
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    # Shutdown
    await engine.dispose()

def create_app() -> FastAPI:
    app = FastAPI(
        title="cognitive-core marketplace",
        version="0.1.0",
        lifespan=lifespan,
    )
    app.include_router(component_router, prefix="/api/v1")
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    return app
```

## Exception Handling

### Domain → HTTP Mapping

```python
from fastapi import Request
from fastapi.responses import JSONResponse

# Domain exceptions (no HTTP knowledge)
class NotFoundError(DomainError): ...
class ConflictError(DomainError): ...
class ForbiddenError(DomainError): ...

# Global exception handler
@app.exception_handler(DomainError)
async def domain_error_handler(request: Request, exc: DomainError) -> JSONResponse:
    status_map = {
        NotFoundError: 404,
        ConflictError: 409,
        ForbiddenError: 403,
        ValidationError: 422,
    }
    status = status_map.get(type(exc), 500)
    return JSONResponse(status_code=status, content={"detail": str(exc)})
```

## Alembic Migrations

### Setup

```python
# alembic/env.py — async configuration
from alembic import context
from sqlalchemy.ext.asyncio import async_engine_from_config

target_metadata = Base.metadata

async def run_migrations_online() -> None:
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
    )
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()

def do_run_migrations(connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()
```

### Naming Conventions

```python
from sqlalchemy import MetaData

convention = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}
metadata = MetaData(naming_convention=convention)

class Base(DeclarativeBase):
    metadata = metadata
```

## Async Testing

### pytest-asyncio + httpx

```python
import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker

@pytest.fixture
async def engine():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    await engine.dispose()

@pytest.fixture
async def session(engine) -> AsyncGenerator[AsyncSession, None]:
    session_maker = async_sessionmaker(engine, class_=AsyncSession)
    async with session_maker() as session:
        yield session

@pytest.fixture
async def client(session) -> AsyncGenerator[AsyncClient, None]:
    app = create_app()
    app.dependency_overrides[get_session] = lambda: session
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client

@pytest.mark.asyncio
async def test_create_component(client: AsyncClient) -> None:
    response = await client.post("/api/v1/components", json={
        "name": "my-agent",
        "type": "agent",
        "description": "A test agent",
        "version": "1.0.0",
    })
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "my-agent"
```

### conftest.py Pattern

```python
# tests/conftest.py
import pytest

pytest_plugins = [
    "tests.fixtures.database",
    "tests.fixtures.factories",
    "tests.fixtures.client",
]

@pytest.fixture(scope="session")
def anyio_backend():
    return "asyncio"
```

## Docker Compose

```yaml
services:
  api:
    build: .
    ports:
      - "8000:8000"
    environment:
      APP_DATABASE_URL: postgresql+asyncpg://app:secret@postgres:5432/marketplace
      APP_SECRET_KEY: dev-secret-key
    depends_on:
      postgres:
        condition: service_healthy

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: marketplace
      POSTGRES_USER: app
      POSTGRES_PASSWORD: secret
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d marketplace"]
      interval: 5s
      retries: 5

volumes:
  pgdata:
```

## Anti-Patterns

| Anti-Pattern | Why | Alternative |
|--------------|-----|-------------|
| `Session` (sync) in FastAPI | Blocks event loop | `AsyncSession` |
| `db.query(Model)` | SQLAlchemy 1.x legacy | `select(Model)` |
| `class Config:` in Pydantic | v1 syntax | `model_config = ConfigDict(...)` |
| Global `SessionLocal()` | Not injectable, not testable | `Depends(get_session)` |
| `requests.get()` in async | Blocks event loop | `httpx.AsyncClient` |
| `@app.on_event("startup")` | Deprecated | `lifespan` context manager |
| `Optional[X]` | Legacy syntax | `X \| None` |
| Eager loading everything | N+1 or over-fetching | `selectinload` / `joinedload` per query |
| Raw SQL strings | Injection risk | `text()` with bind params |
| Missing `expire_on_commit=False` | Lazy load errors after commit | Set on session factory |

## Fitness Criteria

| Check | Threshold | Description |
|-------|-----------|-------------|
| `type_hints` | 95% | Functions have return type annotations |
| `pydantic_v2` | 100% | ConfigDict, not class Config |
| `async_io` | 100% | Async for all I/O operations |
| `dependency_injection` | 100% | FastAPI Depends pattern |
| `sqlalchemy_2` | 100% | mapped_column, select(), async |
| `no_bare_except` | 100% | Specific exception handling |
| `structured_logging` | 90% | Logger with context, no f-strings |
| `test_coverage` | 80% | pytest-asyncio + httpx |

## Linting Tools

```bash
# All-in-one (recommended)
ruff check src/ && ruff format --check src/

# Type checking
mypy src/ --strict

# Security scan
bandit -r src/ -c pyproject.toml
```
