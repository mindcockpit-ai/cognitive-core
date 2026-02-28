---
name: python-ddd
description: Domain-Driven Design patterns for Python — aggregates, value objects, repositories, domain events, CQRS, and application services. Async-first with Pydantic v2 and SQLAlchemy 2.0.
user-invocable: false
allowed-tools: Read, Grep, Glob
catalog_description: DDD patterns — aggregates, value objects, repositories, domain events, CQRS.
---

# Domain-Driven Design — Python Patterns

DDD architecture patterns for Python projects. Async-first with modern Python 3.12+.

## Layer Architecture

```
domain/           Pure business logic — ZERO framework imports
application/      Use cases — orchestrates domain, thin
infrastructure/   Adapters — DB, APIs, messaging
api/              HTTP thin adapter — routes, schemas
```

**The dependency rule:** Dependencies point inward. Domain knows nothing about infrastructure.

## Aggregate Root

The entry point for a cluster of domain objects. All mutations go through the root.

```python
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime, UTC
from uuid import UUID, uuid4

@dataclass
class Component:
    """Aggregate root — owns Ratings as child entities."""

    id: UUID
    name: str
    type: ComponentType
    description: str
    version: SemanticVersion
    author_id: UUID
    status: ComponentStatus = ComponentStatus.DRAFT
    download_count: int = 0
    _ratings: list[Rating] = field(default_factory=list, repr=False)
    _events: list[DomainEvent] = field(default_factory=list, repr=False)
    created_at: datetime = field(default_factory=lambda: datetime.now(UTC))

    # --- Factory method ---
    @staticmethod
    def create(
        name: str,
        type: ComponentType,
        description: str,
        version: str,
        author_id: UUID,
    ) -> Component:
        component = Component(
            id=uuid4(),
            name=name,
            type=type,
            description=description,
            version=SemanticVersion.parse(version),
            author_id=author_id,
        )
        component._add_event(ComponentCreated(component_id=component.id, name=name))
        return component

    # --- Business operations ---
    def publish(self) -> None:
        if self.status != ComponentStatus.DRAFT:
            raise InvalidStateError(f"Cannot publish from {self.status}")
        self.status = ComponentStatus.PUBLISHED
        self._add_event(ComponentPublished(component_id=self.id))

    def add_rating(self, author_id: UUID, score: int, review: str) -> Rating:
        if any(r.author_id == author_id for r in self._ratings):
            raise ConflictError("Author already rated this component")
        rating = Rating(id=uuid4(), author_id=author_id, score=score, review=review)
        self._ratings.append(rating)
        self._recalculate_average()
        self._add_event(RatingAdded(component_id=self.id, score=score))
        return rating

    def can_be_promoted(self) -> bool:
        return (
            self.status == ComponentStatus.PUBLISHED
            and self.rating_average >= 4.0
            and self.download_count >= 50
            and len(self._ratings) >= 5
        )

    def promote(self) -> None:
        if not self.can_be_promoted():
            raise InvalidStateError("Component does not meet promotion criteria")
        self.status = ComponentStatus.PROMOTED
        self._add_event(ComponentPromoted(component_id=self.id))

    def record_download(self) -> None:
        self.download_count += 1

    # --- Internal ---
    @property
    def rating_average(self) -> float:
        if not self._ratings:
            return 0.0
        return sum(r.score for r in self._ratings) / len(self._ratings)

    @property
    def ratings(self) -> tuple[Rating, ...]:
        return tuple(self._ratings)  # Immutable view

    def collect_events(self) -> list[DomainEvent]:
        events = list(self._events)
        self._events.clear()
        return events

    def _add_event(self, event: DomainEvent) -> None:
        self._events.append(event)

    def _recalculate_average(self) -> None:
        pass  # rating_average is a computed property
```

### Key Rules

- All mutations through the root's methods (never `component._ratings.append()` from outside)
- Factory method `create()` enforces invariants at birth
- Business rules are methods, not external services
- Events collected, not dispatched — the application layer dispatches

## Value Objects

Immutable, equality by value. Use `frozen=True` dataclasses or Pydantic `BaseModel(frozen=True)`.

```python
from dataclasses import dataclass
from enum import StrEnum

@dataclass(frozen=True, slots=True)
class SemanticVersion:
    major: int
    minor: int
    patch: int

    @staticmethod
    def parse(version: str) -> SemanticVersion:
        parts = version.split(".")
        if len(parts) != 3:
            raise ValueError(f"Invalid version: {version}")
        return SemanticVersion(*map(int, parts))

    def __str__(self) -> str:
        return f"{self.major}.{self.minor}.{self.patch}"

    def is_compatible_with(self, other: SemanticVersion) -> bool:
        return self.major == other.major

@dataclass(frozen=True, slots=True)
class Email:
    value: str

    def __post_init__(self) -> None:
        if "@" not in self.value or "." not in self.value.split("@")[1]:
            raise ValueError(f"Invalid email: {self.value}")
        object.__setattr__(self, "value", self.value.lower().strip())

class ComponentType(StrEnum):
    AGENT = "agent"
    SKILL = "skill"
    HOOK = "hook"
    PACK = "pack"

class ComponentStatus(StrEnum):
    DRAFT = "draft"
    PUBLISHED = "published"
    PROMOTED = "promoted"
    ARCHIVED = "archived"
```

### When to Use Value Objects

- Identity doesn't matter (two `Email("a@b.com")` are the same)
- Immutable by design
- Self-validating in `__post_init__`
- Use `StrEnum` for bounded sets of values

## Entities (Child of Aggregate)

Have identity but are owned by an aggregate root.

```python
@dataclass
class Rating:
    """Entity — child of Component aggregate."""
    id: UUID
    author_id: UUID
    score: int
    review: str
    created_at: datetime = field(default_factory=lambda: datetime.now(UTC))

    def __post_init__(self) -> None:
        if not 1 <= self.score <= 5:
            raise ValueError(f"Score must be 1-5, got {self.score}")
```

## Domain Events

Record what happened. Dispatched after persistence succeeds.

```python
from dataclasses import dataclass
from datetime import datetime, UTC
from uuid import UUID

@dataclass(frozen=True)
class DomainEvent:
    occurred_at: datetime = field(default_factory=lambda: datetime.now(UTC))

@dataclass(frozen=True)
class ComponentCreated(DomainEvent):
    component_id: UUID = field(default=None)
    name: str = ""

@dataclass(frozen=True)
class ComponentPublished(DomainEvent):
    component_id: UUID = field(default=None)

@dataclass(frozen=True)
class ComponentPromoted(DomainEvent):
    component_id: UUID = field(default=None)

@dataclass(frozen=True)
class RatingAdded(DomainEvent):
    component_id: UUID = field(default=None)
    score: int = 0
```

## Repository Interfaces (Domain Layer)

Abstract interfaces — no SQLAlchemy, no framework imports.

```python
from abc import ABC, abstractmethod

class ComponentRepository(ABC):
    @abstractmethod
    async def find_by_id(self, id: UUID) -> Component | None: ...

    @abstractmethod
    async def find_by_name(self, name: str) -> Component | None: ...

    @abstractmethod
    async def search(
        self,
        query: str | None = None,
        type_filter: ComponentType | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> tuple[list[Component], int]: ...

    @abstractmethod
    async def save(self, component: Component) -> None: ...

    @abstractmethod
    async def delete(self, id: UUID) -> None: ...
```

### Repository Rules

- One repo per aggregate root
- Returns domain objects, not ORM models
- Interface in `domain/`, implementation in `infrastructure/`
- No query language leakage (`select`, `WHERE`) in the interface

## Domain Services

Cross-aggregate logic that doesn't belong in a single aggregate.

```python
class PromotionService:
    """Checks promotion eligibility across aggregates."""

    def __init__(self, component_repo: ComponentRepository, author_repo: AuthorRepository) -> None:
        self._components = component_repo
        self._authors = author_repo

    async def evaluate_promotion(self, component_id: UUID) -> PromotionResult:
        component = await self._components.find_by_id(component_id)
        if component is None:
            raise NotFoundError("Component", component_id)

        author = await self._authors.find_by_id(component.author_id)
        if author is None:
            raise NotFoundError("Author", component.author_id)

        return PromotionResult(
            eligible=component.can_be_promoted() and author.reputation >= 10,
            component=component,
            author=author,
        )
```

## Domain Exceptions

```python
class DomainError(Exception):
    """Base for all domain errors."""

class NotFoundError(DomainError):
    def __init__(self, entity: str, id: str | UUID) -> None:
        super().__init__(f"{entity} not found: {id}")
        self.entity = entity
        self.id = id

class ConflictError(DomainError):
    """Duplicate or conflicting state."""

class InvalidStateError(DomainError):
    """Invalid state transition."""

class ForbiddenError(DomainError):
    """Authorization failure in domain logic."""
```

## Application Services (Use Cases)

Orchestrate domain objects. Thin — no business logic here.

```python
@dataclass(frozen=True)
class PublishComponentCommand:
    name: str
    type: str
    description: str
    version: str
    author_id: UUID

class PublishComponentUseCase:
    def __init__(
        self,
        component_repo: ComponentRepository,
        event_bus: EventBus,
        validator: ComponentValidator,
    ) -> None:
        self._components = component_repo
        self._events = event_bus
        self._validator = validator

    async def execute(self, cmd: PublishComponentCommand) -> UUID:
        # 1. Validate
        self._validator.validate_frontmatter(cmd.type, cmd.description)

        # 2. Check uniqueness
        existing = await self._components.find_by_name(cmd.name)
        if existing:
            raise ConflictError(f"Component '{cmd.name}' already exists")

        # 3. Create aggregate
        component = Component.create(
            name=cmd.name,
            type=ComponentType(cmd.type),
            description=cmd.description,
            version=cmd.version,
            author_id=cmd.author_id,
        )
        component.publish()

        # 4. Persist
        await self._components.save(component)

        # 5. Dispatch events
        await self._events.publish(component.collect_events())

        return component.id
```

### Use Case Rules

- One use case per file / class
- Input is a Command or Query DTO (frozen dataclass)
- Orchestrates, does not decide — decisions live in the domain
- Dispatches events after persistence

## CQRS (Command/Query Separation)

Commands mutate state (return void/ID), queries read (return data).

```python
# Commands — go through aggregate + repository
class PublishComponentCommand: ...     # → UUID
class RateComponentCommand: ...        # → None
class PromoteComponentCommand: ...     # → None

# Queries — can bypass domain, go direct to read models
class SearchComponentsQuery: ...       # → PaginatedResponse
class GetLeaderboardQuery: ...         # → list[LeaderboardEntry]

# Query handler — reads directly, no domain objects needed
class SearchComponentsHandler:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def execute(self, query: SearchComponentsQuery) -> PaginatedResponse:
        stmt = select(ComponentModel).where(...)
        result = await self._session.execute(stmt)
        return PaginatedResponse(items=result.scalars().all(), ...)
```

## Infrastructure: SQLAlchemy Repository

Maps between domain objects and ORM models.

```python
from sqlalchemy import select
from sqlalchemy.orm import selectinload

class SqlAlchemyComponentRepository(ComponentRepository):
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def find_by_id(self, id: UUID) -> Component | None:
        stmt = (
            select(ComponentModel)
            .where(ComponentModel.id == id)
            .options(selectinload(ComponentModel.ratings))
        )
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        return self._to_domain(model) if model else None

    async def save(self, component: Component) -> None:
        model = self._to_model(component)
        merged = await self._session.merge(model)
        await self._session.flush()

    def _to_domain(self, model: ComponentModel) -> Component:
        """ORM model → Domain aggregate."""
        ratings = [
            Rating(id=r.id, author_id=r.author_id, score=r.score, review=r.review)
            for r in model.ratings
        ]
        component = Component(
            id=model.id,
            name=model.name,
            type=ComponentType(model.type),
            description=model.description,
            version=SemanticVersion.parse(model.version),
            author_id=model.author_id,
            status=ComponentStatus(model.status),
            download_count=model.download_count,
        )
        component._ratings = ratings
        return component

    def _to_model(self, component: Component) -> ComponentModel:
        """Domain aggregate → ORM model."""
        return ComponentModel(
            id=component.id,
            name=component.name,
            type=component.type.value,
            description=component.description,
            version=str(component.version),
            author_id=component.author_id,
            status=component.status.value,
            download_count=component.download_count,
            rating_average=component.rating_average,
        )
```

## Event Bus

Simple async event dispatcher.

```python
from collections import defaultdict
from collections.abc import Callable, Awaitable

class EventBus:
    def __init__(self) -> None:
        self._handlers: dict[type, list[Callable]] = defaultdict(list)

    def subscribe[E: DomainEvent](
        self, event_type: type[E], handler: Callable[[E], Awaitable[None]]
    ) -> None:
        self._handlers[event_type].append(handler)

    async def publish(self, events: list[DomainEvent]) -> None:
        for event in events:
            for handler in self._handlers.get(type(event), []):
                await handler(event)
```

## Testing DDD

```python
# Domain tests — pure, fast, no I/O
def test_component_publish() -> None:
    component = Component.create(
        name="test-agent", type=ComponentType.AGENT,
        description="A test", version="1.0.0", author_id=uuid4(),
    )
    component.publish()
    assert component.status == ComponentStatus.PUBLISHED
    events = component.collect_events()
    assert any(isinstance(e, ComponentPublished) for e in events)

def test_cannot_publish_twice() -> None:
    component = make_published_component()
    with pytest.raises(InvalidStateError):
        component.publish()

def test_rating_enforces_one_per_author() -> None:
    component = make_published_component()
    author_id = uuid4()
    component.add_rating(author_id, 5, "Great!")
    with pytest.raises(ConflictError):
        component.add_rating(author_id, 4, "Changed my mind")

# Application tests — mock repositories
@pytest.mark.asyncio
async def test_publish_component_use_case() -> None:
    repo = AsyncMock(spec=ComponentRepository)
    repo.find_by_name.return_value = None
    bus = AsyncMock(spec=EventBus)
    validator = ComponentValidator()

    use_case = PublishComponentUseCase(repo, bus, validator)
    result = await use_case.execute(PublishComponentCommand(
        name="new-skill", type="skill",
        description="A skill", version="1.0.0", author_id=uuid4(),
    ))

    assert isinstance(result, UUID)
    repo.save.assert_awaited_once()
    bus.publish.assert_awaited_once()
```

## Anti-Patterns

| Anti-Pattern | Why | Correct |
|--------------|-----|---------|
| Logic in service, anemic domain | Domain becomes data bag | Put rules in aggregate methods |
| Repository returns ORM models | Domain depends on infra | Map to domain objects |
| Framework imports in domain | Coupling, untestable | Domain has zero framework deps |
| Dispatching events before persist | Data inconsistency | Collect events, dispatch after save |
| One repo per table | Missing aggregate boundaries | One repo per aggregate root |
| Aggregate calls another repo | Cross-boundary coupling | Use domain service or event |
| Setters on aggregate | Bypasses invariants | Named methods with validation |
