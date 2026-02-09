# Apache Kafka Implementation

Implementation of the Messaging pattern using Apache Kafka.

## Overview

Kafka provides high-throughput, fault-tolerant, distributed event streaming for building real-time data pipelines and streaming applications.

## When to Use Kafka

- High-throughput event streaming (millions of events/sec)
- Event sourcing and replay
- Log aggregation
- Stream processing
- Microservices event bus

## Python Implementation

### Installation

```bash
pip install aiokafka  # Async
# or
pip install confluent-kafka  # High performance
```

### Producer Implementation

```python
from dataclasses import dataclass
from typing import Any
import json
from aiokafka import AIOKafkaProducer

@dataclass
class KafkaConfig:
    bootstrap_servers: str
    client_id: str
    acks: str = "all"  # Wait for all replicas
    retries: int = 3
    compression: str = "gzip"


class KafkaMessageProducer:
    """Async Kafka producer with retry and serialization."""

    def __init__(self, config: KafkaConfig):
        self.config = config
        self._producer: AIOKafkaProducer | None = None

    async def start(self):
        self._producer = AIOKafkaProducer(
            bootstrap_servers=self.config.bootstrap_servers,
            client_id=self.config.client_id,
            acks=self.config.acks,
            compression_type=self.config.compression,
            value_serializer=lambda v: json.dumps(v).encode("utf-8"),
            key_serializer=lambda k: k.encode("utf-8") if k else None,
        )
        await self._producer.start()

    async def stop(self):
        if self._producer:
            await self._producer.stop()

    async def send(
        self,
        topic: str,
        value: dict[str, Any],
        key: str | None = None,
        headers: dict[str, str] | None = None,
    ) -> None:
        if not self._producer:
            raise RuntimeError("Producer not started")

        kafka_headers = (
            [(k, v.encode()) for k, v in headers.items()]
            if headers
            else None
        )
        await self._producer.send_and_wait(
            topic=topic,
            value=value,
            key=key,
            headers=kafka_headers,
        )

    async def send_batch(
        self,
        topic: str,
        messages: list[tuple[str | None, dict]],
    ) -> None:
        """Send multiple messages efficiently."""
        if not self._producer:
            raise RuntimeError("Producer not started")

        batch = self._producer.create_batch()
        for key, value in messages:
            metadata = batch.append(
                key=key.encode() if key else None,
                value=json.dumps(value).encode(),
                timestamp=None,
            )
            if metadata is None:
                # Batch full, send and create new
                await self._producer.send_and_wait(topic, batch=batch)
                batch = self._producer.create_batch()
                batch.append(
                    key=key.encode() if key else None,
                    value=json.dumps(value).encode(),
                    timestamp=None,
                )
        # Send remaining
        if batch.record_count() > 0:
            await self._producer.send_and_wait(topic, batch=batch)

    async def __aenter__(self):
        await self.start()
        return self

    async def __aexit__(self, *args):
        await self.stop()
```

### Consumer Implementation

```python
from aiokafka import AIOKafkaConsumer
from aiokafka.errors import KafkaError
import logging

logger = logging.getLogger(__name__)


@dataclass
class ConsumerConfig:
    bootstrap_servers: str
    group_id: str
    topics: list[str]
    auto_offset_reset: str = "earliest"
    enable_auto_commit: bool = False  # Manual commit for reliability


class KafkaMessageConsumer:
    """Async Kafka consumer with manual commit and error handling."""

    def __init__(self, config: ConsumerConfig):
        self.config = config
        self._consumer: AIOKafkaConsumer | None = None
        self._running = False

    async def start(self):
        self._consumer = AIOKafkaConsumer(
            *self.config.topics,
            bootstrap_servers=self.config.bootstrap_servers,
            group_id=self.config.group_id,
            auto_offset_reset=self.config.auto_offset_reset,
            enable_auto_commit=self.config.enable_auto_commit,
            value_deserializer=lambda v: json.loads(v.decode("utf-8")),
        )
        await self._consumer.start()
        self._running = True

    async def stop(self):
        self._running = False
        if self._consumer:
            await self._consumer.stop()

    async def consume(
        self,
        handler: Callable[[dict], Awaitable[None]],
        max_messages: int | None = None,
    ) -> None:
        """Consume messages with manual commit after successful processing."""
        if not self._consumer:
            raise RuntimeError("Consumer not started")

        count = 0
        async for msg in self._consumer:
            if not self._running:
                break

            try:
                await handler(msg.value)
                await self._consumer.commit()
                count += 1

                if max_messages and count >= max_messages:
                    break
            except Exception as e:
                logger.error(
                    f"Error processing message: {e}",
                    extra={"topic": msg.topic, "offset": msg.offset},
                )
                # Don't commit - message will be reprocessed
                # Could implement DLQ here

    async def __aenter__(self):
        await self.start()
        return self

    async def __aexit__(self, *args):
        await self.stop()
```

### Usage Example

```python
import asyncio
from kafka_client import (
    KafkaMessageProducer, KafkaConfig,
    KafkaMessageConsumer, ConsumerConfig,
)

async def main():
    # Producer
    producer_config = KafkaConfig(
        bootstrap_servers="localhost:9092",
        client_id="my-app",
    )

    async with KafkaMessageProducer(producer_config) as producer:
        await producer.send(
            topic="user-events",
            key="user-123",
            value={
                "event_type": "user_created",
                "user_id": "123",
                "email": "user@example.com",
                "timestamp": datetime.utcnow().isoformat(),
            },
            headers={"correlation_id": "abc-123"},
        )

    # Consumer
    consumer_config = ConsumerConfig(
        bootstrap_servers="localhost:9092",
        group_id="my-consumer-group",
        topics=["user-events"],
    )

    async def handle_message(message: dict):
        print(f"Received: {message}")
        # Process message...

    async with KafkaMessageConsumer(consumer_config) as consumer:
        await consumer.consume(handle_message)

asyncio.run(main())
```

## Java Implementation

### Maven Dependencies

```xml
<dependency>
    <groupId>org.apache.kafka</groupId>
    <artifactId>kafka-clients</artifactId>
    <version>3.6.0</version>
</dependency>
```

### Producer Implementation

```java
@Service
@RequiredArgsConstructor
public class KafkaMessageProducer implements MessageProducer<String, Object> {
    private final KafkaTemplate<String, Object> kafkaTemplate;

    @Override
    public void send(String topic, Message<String, Object> message) {
        var record = new ProducerRecord<>(
            topic,
            message.getKey(),
            message.getValue()
        );
        message.getHeaders().forEach((k, v) ->
            record.headers().add(k, v.getBytes(StandardCharsets.UTF_8))
        );

        kafkaTemplate.send(record)
            .whenComplete((result, ex) -> {
                if (ex != null) {
                    log.error("Failed to send message", ex);
                } else {
                    log.debug("Message sent: topic={}, offset={}",
                        result.getRecordMetadata().topic(),
                        result.getRecordMetadata().offset());
                }
            });
    }
}
```

### Consumer Implementation

```java
@Service
@RequiredArgsConstructor
@Slf4j
public class UserEventConsumer {

    @KafkaListener(
        topics = "user-events",
        groupId = "my-consumer-group",
        containerFactory = "kafkaListenerContainerFactory"
    )
    public void handleUserEvent(
        @Payload UserEvent event,
        @Header(KafkaHeaders.RECEIVED_KEY) String key,
        Acknowledgment ack
    ) {
        try {
            log.info("Processing event: key={}, type={}",
                key, event.getEventType());

            processEvent(event);

            ack.acknowledge();  // Manual commit
        } catch (Exception e) {
            log.error("Failed to process event", e);
            // Don't acknowledge - will be retried
            throw e;
        }
    }

    private void processEvent(UserEvent event) {
        switch (event.getEventType()) {
            case "user_created" -> handleUserCreated(event);
            case "user_updated" -> handleUserUpdated(event);
            case "user_deleted" -> handleUserDeleted(event);
            default -> log.warn("Unknown event type: {}", event.getEventType());
        }
    }
}
```

## Configuration

### Producer Configuration

```yaml
# application.yml (Spring Boot)
spring:
  kafka:
    bootstrap-servers: localhost:9092
    producer:
      acks: all
      retries: 3
      batch-size: 16384
      compression-type: gzip
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer
```

### Consumer Configuration

```yaml
spring:
  kafka:
    consumer:
      group-id: my-consumer-group
      auto-offset-reset: earliest
      enable-auto-commit: false
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.springframework.kafka.support.serializer.JsonDeserializer
    listener:
      ack-mode: manual
      concurrency: 3
```

## Best Practices

1. **Use manual commits** - Ensure at-least-once delivery
2. **Implement idempotency** - Handle duplicate messages
3. **Use partitions wisely** - Key-based for ordering
4. **Set proper retention** - Based on replay needs
5. **Monitor lag** - Alert on consumer lag

## Dead Letter Queue

```python
async def consume_with_dlq(
    consumer: KafkaMessageConsumer,
    producer: KafkaMessageProducer,
    handler: Callable,
    dlq_topic: str,
    max_retries: int = 3,
):
    async def wrapped_handler(message: dict):
        retries = message.get("_retries", 0)
        try:
            await handler(message)
        except Exception as e:
            if retries >= max_retries:
                # Send to DLQ
                await producer.send(
                    topic=dlq_topic,
                    value={**message, "_error": str(e), "_retries": retries},
                )
            else:
                # Retry with backoff
                message["_retries"] = retries + 1
                raise

    await consumer.consume(wrapped_handler)
```

## See Also

- [Messaging Pattern](../../README.md)
- [RabbitMQ Implementation](../rabbitmq/)
- [Testing Pattern](../../../testing/)
