---
name: python-messaging
description: Async messaging and middleware patterns for Python — in-process events, background tasks, Redis queues, Celery, Redis Streams, and Kafka. Graduated complexity from simple to enterprise scale.
user-invocable: false
allowed-tools: Read, Grep, Glob
catalog_description: Messaging patterns — event bus, background tasks, Redis, Celery, Kafka.
---

# Python Messaging & Middleware Patterns

Graduated messaging patterns from in-process to distributed. Pick the right tool for your scale.

## Decision Matrix

| Pattern | Complexity | Persistence | Scale | Use When |
|---------|-----------|-------------|-------|----------|
| In-process EventBus | Minimal | None | Single process | Domain events, no durability needed |
| FastAPI BackgroundTasks | Minimal | None | Single process | Fire-and-forget after response |
| ARQ (Redis) | Low | Redis | Single service | Async jobs, retries, scheduling |
| Celery + Redis/RabbitMQ | Medium | Broker | Multi-worker | Heavy background processing, periodic tasks |
| Redis Streams | Medium | Redis | Multi-consumer | Event sourcing lite, consumer groups |
| Kafka (aiokafka) | High | Kafka cluster | Multi-service | High-throughput event streaming, audit logs |

## 1. In-Process EventBus

Zero dependencies. Good for DDD domain events within a single service.

```python
from collections import defaultdict
from collections.abc import Awaitable, Callable
from dataclasses import dataclass, field
from datetime import datetime, UTC

@dataclass(frozen=True)
class DomainEvent:
    occurred_at: datetime = field(default_factory=lambda: datetime.now(UTC))

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

# Usage in FastAPI dependency injection
def create_event_bus() -> EventBus:
    bus = EventBus()
    bus.subscribe(ComponentPublished, notify_author)
    bus.subscribe(ComponentPublished, update_search_index)
    bus.subscribe(RatingAdded, recalculate_reputation)
    return bus
```

**Limitations:** Events lost on crash, no retry, single process only.

## 2. FastAPI BackgroundTasks

Built into FastAPI. Runs after the response is sent. No extra infrastructure.

```python
from fastapi import BackgroundTasks

async def send_welcome_email(email: str, name: str) -> None:
    async with httpx.AsyncClient() as client:
        await client.post("https://api.email.service/send", json={
            "to": email,
            "template": "welcome",
            "vars": {"name": name},
        })

async def update_download_stats(component_id: UUID) -> None:
    async with get_session() as session:
        await session.execute(
            update(ComponentModel)
            .where(ComponentModel.id == component_id)
            .values(download_count=ComponentModel.download_count + 1)
        )
        await session.commit()

@router.post("/components/{id}/download")
async def download_component(
    id: UUID,
    background_tasks: BackgroundTasks,
    service: ComponentService = Depends(get_component_service),
) -> ComponentResponse:
    component = await service.get_by_id(id)
    background_tasks.add_task(update_download_stats, id)
    background_tasks.add_task(send_welcome_email, "user@example.com", "User")
    return component
```

**Limitations:** No retry, no persistence, lost on process restart.

## 3. ARQ — Async Redis Queue

Lightweight, async-native. Perfect for FastAPI projects that need reliable background jobs.

```bash
pip install arq
```

### Worker Definition

```python
# src/workers.py
from arq import create_pool
from arq.connections import RedisSettings, ArqRedis

async def send_notification(ctx: dict, user_id: UUID, message: str) -> None:
    """Background job — runs in worker process."""
    session = ctx["session"]
    user = await session.get(UserModel, user_id)
    await email_service.send(user.email, message)

async def process_component_upload(ctx: dict, component_id: UUID) -> None:
    """Validate frontmatter, generate thumbnails, index for search."""
    session = ctx["session"]
    component = await session.get(ComponentModel, component_id)
    await validate_frontmatter(component.frontmatter)
    await update_search_index(component)

async def startup(ctx: dict) -> None:
    ctx["session"] = async_session()

async def shutdown(ctx: dict) -> None:
    await ctx["session"].close()

class WorkerSettings:
    functions = [send_notification, process_component_upload]
    on_startup = startup
    on_shutdown = shutdown
    redis_settings = RedisSettings(host="localhost", port=6379)
    max_jobs = 10
    job_timeout = 300  # 5 minutes
```

### Enqueue from FastAPI

```python
from arq.connections import ArqRedis, create_pool

async def get_arq_pool() -> ArqRedis:
    return await create_pool(RedisSettings())

@router.post("/components")
async def publish_component(
    request: CreateComponentRequest,
    arq: ArqRedis = Depends(get_arq_pool),
    service: ComponentService = Depends(get_component_service),
) -> ComponentResponse:
    component = await service.publish(request)

    # Enqueue background processing (reliable, survives restarts)
    await arq.enqueue_job(
        "process_component_upload",
        component.id,
        _job_id=f"upload-{component.id}",  # Idempotency key
    )
    return component
```

### Scheduled / Cron Jobs

```python
from arq.cron import cron

class WorkerSettings:
    functions = [send_notification, process_component_upload]
    cron_jobs = [
        cron(calculate_daily_stats, hour=2, minute=0),     # 2 AM daily
        cron(cleanup_expired_tokens, hour={0, 12}),         # Twice daily
        cron(refresh_search_index, minute={0, 30}),         # Every 30 min
    ]
```

### Run Worker

```bash
arq src.workers.WorkerSettings
```

## 4. Celery + Redis

Industry standard for heavy background processing. More complex but battle-tested.

```bash
pip install celery[redis]
```

### Task Definition

```python
# src/tasks/celery_app.py
from celery import Celery

app = Celery(
    "marketplace",
    broker="redis://localhost:6379/0",
    backend="redis://localhost:6379/1",
)

app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    task_track_started=True,
    task_acks_late=True,          # Acknowledge after completion (reliable)
    worker_prefetch_multiplier=1,  # Fair scheduling
)

# src/tasks/components.py
from src.tasks.celery_app import app

@app.task(bind=True, max_retries=3, default_retry_delay=60)
def process_upload(self, component_id: str) -> dict:
    """Heavy processing — runs in Celery worker."""
    try:
        # Celery tasks are sync by default
        result = sync_validate_and_index(component_id)
        return {"status": "ok", "component_id": component_id}
    except TransientError as exc:
        raise self.retry(exc=exc)

@app.task
def calculate_weekly_report() -> None:
    """Periodic task."""
    generate_report()
```

### Periodic Tasks (Celery Beat)

```python
app.conf.beat_schedule = {
    "daily-stats": {
        "task": "src.tasks.stats.calculate_daily_stats",
        "schedule": crontab(hour=2, minute=0),
    },
    "cleanup-tokens": {
        "task": "src.tasks.auth.cleanup_expired_tokens",
        "schedule": crontab(hour="*/6"),  # Every 6 hours
    },
}
```

### Enqueue from FastAPI

```python
from src.tasks.components import process_upload

@router.post("/components")
async def publish_component(request: CreateComponentRequest) -> ComponentResponse:
    component = await service.publish(request)
    process_upload.delay(str(component.id))  # Fire and forget
    return component
```

### Run

```bash
celery -A src.tasks.celery_app worker --loglevel=info
celery -A src.tasks.celery_app beat --loglevel=info  # Scheduler
```

**Note:** Celery tasks are sync. For async FastAPI projects, prefer **ARQ** unless you need Celery's ecosystem (monitoring with Flower, complex routing, multi-broker).

## 5. Redis Streams

Persistent, ordered event log with consumer groups. Good for event sourcing lite.

```python
import redis.asyncio as redis
import json
from uuid import uuid4

class RedisEventStream:
    def __init__(self, client: redis.Redis, stream: str) -> None:
        self._client = client
        self._stream = stream

    async def publish(self, event_type: str, data: dict) -> str:
        """Publish event to stream. Returns message ID."""
        message = {
            "event_type": event_type,
            "data": json.dumps(data),
            "event_id": str(uuid4()),
        }
        return await self._client.xadd(self._stream, message, maxlen=10000)

    async def subscribe(
        self, group: str, consumer: str, handler: Callable
    ) -> None:
        """Consume events in a consumer group."""
        # Create group if not exists
        try:
            await self._client.xgroup_create(self._stream, group, id="0", mkstream=True)
        except redis.ResponseError:
            pass  # Group already exists

        while True:
            messages = await self._client.xreadgroup(
                group, consumer, {self._stream: ">"}, count=10, block=5000
            )
            for stream_name, entries in messages:
                for msg_id, fields in entries:
                    event = json.loads(fields[b"data"])
                    await handler(fields[b"event_type"].decode(), event)
                    await self._client.xack(self._stream, group, msg_id)
```

### Usage

```python
stream = RedisEventStream(redis_client, "marketplace-events")

# Producer
await stream.publish("component.published", {
    "component_id": str(component.id),
    "author_id": str(component.author_id),
})

# Consumer (in separate worker)
async def handle_event(event_type: str, data: dict) -> None:
    match event_type:
        case "component.published":
            await update_search_index(data["component_id"])
        case "rating.added":
            await recalculate_reputation(data["author_id"])

await stream.subscribe("indexer-group", "worker-1", handle_event)
```

## 6. Kafka (aiokafka)

High-throughput distributed event streaming. Use when you have multiple services that need reliable, ordered event delivery.

```bash
pip install aiokafka
```

### Producer

```python
from aiokafka import AIOKafkaProducer
import json

class KafkaEventProducer:
    def __init__(self, bootstrap_servers: str = "localhost:9092") -> None:
        self._producer = AIOKafkaProducer(
            bootstrap_servers=bootstrap_servers,
            value_serializer=lambda v: json.dumps(v).encode("utf-8"),
            key_serializer=lambda k: k.encode("utf-8") if k else None,
        )

    async def start(self) -> None:
        await self._producer.start()

    async def stop(self) -> None:
        await self._producer.stop()

    async def publish(
        self, topic: str, key: str, event: dict
    ) -> None:
        await self._producer.send_and_wait(topic, value=event, key=key)

# FastAPI lifespan integration
@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    producer = KafkaEventProducer(settings.kafka_servers)
    await producer.start()
    app.state.kafka = producer
    yield
    await producer.stop()
```

### Consumer

```python
from aiokafka import AIOKafkaConsumer

class KafkaEventConsumer:
    def __init__(
        self,
        topics: list[str],
        group_id: str,
        bootstrap_servers: str = "localhost:9092",
    ) -> None:
        self._consumer = AIOKafkaConsumer(
            *topics,
            bootstrap_servers=bootstrap_servers,
            group_id=group_id,
            value_deserializer=lambda v: json.loads(v.decode("utf-8")),
            auto_offset_reset="earliest",
            enable_auto_commit=False,
        )

    async def consume(self, handler: Callable[[str, dict], Awaitable[None]]) -> None:
        await self._consumer.start()
        try:
            async for msg in self._consumer:
                await handler(msg.topic, msg.value)
                await self._consumer.commit()
        finally:
            await self._consumer.stop()

# Worker
async def main() -> None:
    consumer = KafkaEventConsumer(
        topics=["marketplace.components", "marketplace.ratings"],
        group_id="search-indexer",
    )
    await consumer.consume(handle_marketplace_event)
```

### Topic Design

```
marketplace.components      — component CRUD events (keyed by component_id)
marketplace.ratings          — rating events (keyed by component_id)
marketplace.downloads        — download tracking (keyed by component_id)
marketplace.authors          — author profile events (keyed by author_id)
marketplace.notifications    — email/push notification triggers
```

### Docker Compose (for local dev)

```yaml
services:
  kafka:
    image: bitnami/kafka:3.7
    ports:
      - "9092:9092"
    environment:
      KAFKA_CFG_NODE_ID: 0
      KAFKA_CFG_PROCESS_ROLES: controller,broker
      KAFKA_CFG_CONTROLLER_QUORUM_VOTERS: 0@kafka:9093
      KAFKA_CFG_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9093
      KAFKA_CFG_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_CFG_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
    volumes:
      - kafka_data:/bitnami/kafka

volumes:
  kafka_data:
```

## Testing Messaging

### In-process EventBus

```python
@pytest.mark.asyncio
async def test_event_bus_dispatches() -> None:
    bus = EventBus()
    received: list[DomainEvent] = []
    bus.subscribe(ComponentPublished, lambda e: received.append(e))

    event = ComponentPublished(component_id=uuid4())
    await bus.publish([event])

    assert len(received) == 1
    assert received[0].component_id == event.component_id
```

### ARQ Tasks (with arq testing utilities)

```python
@pytest.mark.asyncio
async def test_process_upload_task() -> None:
    # Test the function directly (it's just an async function)
    ctx = {"session": mock_session}
    await process_component_upload(ctx, component_id=test_id)
    mock_session.get.assert_awaited_once()
```

### Kafka (with testcontainers)

```python
import pytest
from testcontainers.kafka import KafkaContainer

@pytest.fixture(scope="session")
def kafka_server():
    with KafkaContainer() as kafka:
        yield kafka.get_bootstrap_server()

@pytest.mark.asyncio
async def test_kafka_roundtrip(kafka_server: str) -> None:
    producer = KafkaEventProducer(kafka_server)
    await producer.start()
    await producer.publish("test-topic", "key-1", {"action": "test"})
    await producer.stop()

    received = []
    consumer = KafkaEventConsumer(["test-topic"], "test-group", kafka_server)
    # Consume with timeout...
```

## Graduated Migration Path

```
Phase 1: EventBus (in-process)
    └─ Good for: MVP, single-service, < 100 req/s
    └─ Upgrade trigger: need retry/persistence

Phase 2: ARQ + Redis
    └─ Good for: background jobs, scheduling, < 1K req/s
    └─ Upgrade trigger: need multiple consumers, event replay

Phase 3: Redis Streams
    └─ Good for: event sourcing lite, consumer groups, < 10K msg/s
    └─ Upgrade trigger: need cross-service, high throughput

Phase 4: Kafka
    └─ Good for: multi-service, audit logs, > 10K msg/s
    └─ Enterprise scale, full event streaming
```
