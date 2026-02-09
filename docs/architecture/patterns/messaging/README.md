# Messaging Pattern

Asynchronous message processing for decoupled, scalable systems.

## Problem

- Synchronous calls create tight coupling
- Systems need to handle high throughput
- Failures shouldn't cascade across services
- Work needs to be distributed across workers

## Solution: Message Queue Architecture

```
┌──────────────┐       ┌───────────────┐       ┌──────────────┐
│   Producer   │──────►│  Message Queue │──────►│   Consumer   │
│              │       │   (Broker)     │       │              │
└──────────────┘       └───────────────┘       └──────────────┘
      │                       │                       │
      │                       │                       │
   Publish               Store/Route              Subscribe
   Message              & Guarantee              & Process
```

## Abstract Interface

All messaging implementations must satisfy:

```python
# Abstract Producer Interface
class MessageProducer(Protocol):
    def send(self, topic: str, message: Message) -> None: ...
    def send_batch(self, topic: str, messages: list[Message]) -> None: ...
    def close(self) -> None: ...

# Abstract Consumer Interface
class MessageConsumer(Protocol):
    def subscribe(self, topics: list[str]) -> None: ...
    def poll(self, timeout: float) -> list[Message]: ...
    def commit(self) -> None: ...
    def close(self) -> None: ...

# Message envelope
@dataclass
class Message:
    key: str | None
    value: bytes
    headers: dict[str, str]
    timestamp: datetime
```

```java
// Java Abstract Interface
public interface MessageProducer<K, V> {
    void send(String topic, Message<K, V> message);
    void sendBatch(String topic, List<Message<K, V>> messages);
    void close();
}

public interface MessageConsumer<K, V> {
    void subscribe(List<String> topics);
    List<Message<K, V>> poll(Duration timeout);
    void commit();
    void close();
}
```

## Patterns

### 1. Point-to-Point (Queue)

Each message processed by exactly one consumer.

```
Producer ──► Queue ──► Consumer 1
                  └──► Consumer 2 (competing)
```

**Use when**: Work distribution, task processing

### 2. Publish-Subscribe (Topic)

Each message delivered to all subscribers.

```
Producer ──► Topic ──► Subscriber 1
                  ├──► Subscriber 2
                  └──► Subscriber 3
```

**Use when**: Event broadcasting, notifications

### 3. Request-Reply

Synchronous-style messaging with response queue.

```
Client ──► Request Queue ──► Server
   ▲                           │
   └───── Reply Queue ◄────────┘
```

**Use when**: RPC over messaging, distributed calls

## Trade-offs

| Aspect | Benefit | Cost |
|--------|---------|------|
| Decoupling | Independent deployment | Added complexity |
| Scalability | Horizontal scaling | Queue management |
| Reliability | Message persistence | Latency overhead |
| Ordering | Guaranteed (per partition) | Throughput trade-off |

## Implementation Examples

| Technology | Best For | Guide |
|------------|----------|-------|
| **Apache Kafka** | High throughput, event streaming | [kafka/](./implementations/kafka/) |
| **RabbitMQ** | Complex routing, RPC patterns | [rabbitmq/](./implementations/rabbitmq/) |
| **AWS SQS** | Serverless, managed queue | [sqs/](./implementations/sqs/) |
| **Redis Streams** | Simple pub/sub, caching | [redis/](./implementations/redis/) |

## Selection Guide

```
Is event streaming/replay needed?
├── Yes → Kafka
└── No
    └── Need complex routing?
        ├── Yes → RabbitMQ
        └── No
            └── Cloud-native/serverless?
                ├── Yes → AWS SQS/Azure Service Bus
                └── No → Redis Streams
```

## Fitness Criteria

| Criteria | Threshold | Description |
|----------|-----------|-------------|
| `message_acknowledgment` | 100% | All messages properly ack'd |
| `dead_letter_handling` | 100% | Failed messages routed to DLQ |
| `idempotent_consumers` | 100% | Duplicate handling |
| `error_retry` | 90% | Exponential backoff |
| `monitoring` | 100% | Metrics and alerting |

## See Also

- [API Integration](../api-integration/) - Synchronous integration
- [Testing](../testing/) - Testing messaging systems
- [CI/CD](../ci-cd/) - Pipeline patterns
