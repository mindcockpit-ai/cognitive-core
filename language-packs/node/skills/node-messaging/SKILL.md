---
name: node-messaging
description: "Messaging and middleware patterns for Node.js/TypeScript — EventEmitter, BullMQ, RabbitMQ, Redis Streams, Kafka.js, NATS. Graduated complexity from simple to enterprise scale."
user-invocable: false
allowed-tools: Read, Grep, Glob
catalog_description: "Messaging patterns — EventEmitter, BullMQ, RabbitMQ, Kafka.js, NATS."
---

# Node.js Messaging & Middleware Patterns

Graduated messaging patterns from in-process to distributed. Pick the right tool for your scale.

## Decision Matrix

| Pattern | Complexity | Persistence | Scale | Use When |
|---------|-----------|-------------|-------|----------|
| EventEmitter (typed) | Minimal | None | Single process | Decoupled modules, no durability needed |
| BullMQ (Redis) | Low | Redis | Single service | Job queues, retries, scheduling, rate limiting |
| AMQP (RabbitMQ) | Medium | Broker | Multi-service | Routing topologies, fanout, RPC-over-queue |
| Redis Streams | Medium | Redis | Multi-consumer | Event sourcing lite, consumer groups |
| Kafka.js | High | Kafka cluster | Multi-service | High-throughput event streaming, audit logs |
| NATS | Medium | NATS JetStream | Multi-service | Lightweight cloud-native, request/reply |

## 1. Typed EventEmitter

Zero dependencies. Built-in `node:events` with strict TypeScript typing.

```typescript
import { EventEmitter } from "node:events";

interface AppEvents {
  "component.published": [{ componentId: string; authorId: string }];
  "rating.added": [{ componentId: string; score: number }];
}

class TypedEventEmitter<T extends Record<string, unknown[]>> {
  private emitter = new EventEmitter();

  on<K extends keyof T & string>(event: K, fn: (...args: T[K]) => void): this {
    this.emitter.on(event, fn as (...args: unknown[]) => void);
    return this;
  }

  emit<K extends keyof T & string>(event: K, ...args: T[K]): boolean {
    return this.emitter.emit(event, ...args);
  }

  off<K extends keyof T & string>(event: K, fn: (...args: T[K]) => void): this {
    this.emitter.off(event, fn as (...args: unknown[]) => void);
    return this;
  }
}

export const bus = new TypedEventEmitter<AppEvents>();

bus.on("component.published", async ({ componentId }) => {
  await updateSearchIndex(componentId);
});
```

**Limitations:** Events lost on crash, no retry, single process only.

## 2. BullMQ (Redis)

Modern Redis-backed job queue with delayed jobs, repeatable schedules, rate limiting, and flow dependencies.

```bash
npm install bullmq
```

```typescript
import { Queue, Worker, FlowProducer, type Job } from "bullmq";

const connection = { host: "localhost", port: 6379 };

// Queue
export const componentQueue = new Queue<{
  componentId: string;
  action: "index" | "validate" | "thumbnail";
}>("component-processing", { connection });

// Worker
const worker = new Worker(
  "component-processing",
  async (job: Job) => {
    switch (job.data.action) {
      case "validate": await validateFrontmatter(job.data.componentId); break;
      case "index":    await updateSearchIndex(job.data.componentId);   break;
      case "thumbnail": await generateThumbnail(job.data.componentId);  break;
    }
  },
  { connection, concurrency: 5, limiter: { max: 100, duration: 60_000 } },
);

// Enqueue with retry
await componentQueue.add("process-upload", { componentId: id, action: "validate" }, {
  attempts: 3,
  backoff: { type: "exponential", delay: 1000 },
  removeOnComplete: { age: 86_400 },
});

// Repeatable (cron)
await componentQueue.add("daily-stats", { componentId: "*", action: "index" }, {
  repeat: { pattern: "0 2 * * *" },
});

// Flow — parent waits for children
const flow = new FlowProducer({ connection });
await flow.add({
  name: "publish-pipeline",
  queueName: "component-processing",
  data: { componentId: id, action: "index" },
  children: [
    { name: "validate", queueName: "component-processing", data: { componentId: id, action: "validate" } },
    { name: "thumbnail", queueName: "component-processing", data: { componentId: id, action: "thumbnail" } },
  ],
});
```

## 3. AMQP (RabbitMQ)

Flexible routing, fanout, and dead-letter exchanges. `amqp-connection-manager` handles reconnection.

```bash
npm install amqp-connection-manager amqplib
npm install -D @types/amqplib
```

```typescript
import amqp from "amqp-connection-manager";
import type { ConfirmChannel, ConsumeMessage } from "amqplib";

const conn = amqp.connect(["amqp://localhost:5672"]);

// Publisher
const pubCh = conn.createChannel({
  json: true,
  setup: async (ch: ConfirmChannel) => {
    await ch.assertExchange("marketplace", "topic", { durable: true });
  },
});

export async function publishEvent(routingKey: string, payload: Record<string, unknown>) {
  await pubCh.publish("marketplace", routingKey, payload, {
    persistent: true, messageId: crypto.randomUUID(),
  });
}

// Consumer
conn.createChannel({
  json: true,
  setup: async (ch: ConfirmChannel) => {
    await ch.assertExchange("marketplace", "topic", { durable: true });
    const q = await ch.assertQueue("search-indexer", { durable: true });
    await ch.bindQueue(q.queue, "marketplace", "component.*");
    await ch.bindQueue(q.queue, "marketplace", "rating.*");
    ch.prefetch(10);

    // Dead-letter exchange
    await ch.assertExchange("marketplace.dlx", "fanout", { durable: true });
    await ch.assertQueue("marketplace.dead-letters", { durable: true });
    await ch.bindQueue("marketplace.dead-letters", "marketplace.dlx", "");

    await ch.consume(q.queue, async (msg: ConsumeMessage | null) => {
      if (!msg) return;
      try {
        const data = JSON.parse(msg.content.toString());
        await handleEvent(msg.fields.routingKey, data);
        ch.ack(msg);
      } catch {
        ch.nack(msg, false, false); // send to DLX, no requeue
      }
    });
  },
});
```

## 4. Redis Streams

Persistent, ordered event log with consumer groups via `ioredis`.

```bash
npm install ioredis
```

```typescript
import Redis from "ioredis";

export class RedisEventStream {
  constructor(private client: Redis, private stream: string) {}

  async publish(eventType: string, data: Record<string, unknown>): Promise<string> {
    return this.client.xadd(this.stream, "MAXLEN", "~", "10000", "*",
      "event_type", eventType, "data", JSON.stringify(data), "event_id", crypto.randomUUID());
  }

  async subscribe(
    group: string, consumer: string,
    handler: (eventType: string, data: Record<string, unknown>) => Promise<void>,
  ): Promise<void> {
    try { await this.client.xgroup("CREATE", this.stream, group, "0", "MKSTREAM"); } catch { /* exists */ }

    while (true) {
      const results = await this.client.xreadgroup(
        "GROUP", group, consumer, "COUNT", "10", "BLOCK", "5000", "STREAMS", this.stream, ">");
      if (!results) continue;

      for (const [, messages] of results) {
        for (const [msgId, fields] of messages) {
          const fm = new Map<string, string>();
          for (let i = 0; i < fields.length; i += 2) fm.set(fields[i], fields[i + 1]);
          await handler(fm.get("event_type") ?? "unknown", JSON.parse(fm.get("data") ?? "{}"));
          await this.client.xack(this.stream, group, msgId);
        }
      }
    }
  }
}

// Usage
const stream = new RedisEventStream(redis, "marketplace-events");
await stream.publish("component.published", { componentId: "abc-123" });
await stream.subscribe("indexer-group", "worker-1", async (type, data) => {
  if (type === "component.published") await updateSearchIndex(data.componentId as string);
});
```

## 5. Kafka.js

High-throughput distributed event streaming for multi-service architectures.

```bash
npm install kafkajs
```

```typescript
import { Kafka, CompressionTypes, type EachMessagePayload } from "kafkajs";

const kafka = new Kafka({ clientId: "marketplace-api", brokers: ["localhost:9092"] });

// Producer
export class KafkaEventProducer {
  private producer = kafka.producer({ idempotent: true });
  async connect() { await this.producer.connect(); }
  async disconnect() { await this.producer.disconnect(); }

  async publish(topic: string, key: string, event: Record<string, unknown>) {
    await this.producer.send({
      topic, compression: CompressionTypes.GZIP,
      messages: [{ key, value: JSON.stringify(event),
        headers: { "event-id": crypto.randomUUID(), timestamp: Date.now().toString() } }],
    });
  }
}

// Consumer
export class KafkaEventConsumer {
  private consumer = kafka.consumer({ groupId: this.groupId });
  constructor(private groupId: string) {}

  async subscribe(topics: string[]) {
    await this.consumer.connect();
    for (const topic of topics) await this.consumer.subscribe({ topic, fromBeginning: false });
  }

  async consume(handler: (topic: string, data: Record<string, unknown>) => Promise<void>) {
    await this.consumer.run({
      autoCommit: false,
      eachMessage: async ({ topic, partition, message }: EachMessagePayload) => {
        await handler(topic, JSON.parse(message.value?.toString() ?? "{}"));
        await this.consumer.commitOffsets([{ topic, partition,
          offset: (Number(message.offset) + 1).toString() }]);
      },
    });
  }

  async disconnect() { await this.consumer.disconnect(); }
}
```

Topic design: `marketplace.components`, `marketplace.ratings`, `marketplace.downloads`, `marketplace.notifications` -- keyed by entity ID for partition ordering.

## 6. NATS

Lightweight, cloud-native messaging with request/reply and JetStream persistence.

```bash
npm install nats
```

### Core Pub/Sub

```typescript
import { connect, StringCodec, AckPolicy, DeliverPolicy } from "nats";

const sc = StringCodec();
const nc = await connect({ servers: "localhost:4222" });

// Publish
nc.publish("marketplace.component.published", sc.encode(JSON.stringify({ componentId: "abc-123" })));

// Subscribe (wildcard)
const sub = nc.subscribe("marketplace.component.*");
for await (const msg of sub) {
  const data = JSON.parse(sc.decode(msg.data));
  console.log(`${msg.subject}:`, data);
}
```

### JetStream (Persistent)

```typescript
const jsm = await nc.jetstreamManager();
const js = nc.jetstream();

await jsm.streams.add({
  name: "MARKETPLACE", subjects: ["marketplace.>"],
  retention: "limits", max_msgs: 100_000,
  max_age: 7 * 24 * 60 * 60 * 1_000_000_000,
});

await js.publish("marketplace.component.published", sc.encode(JSON.stringify({ componentId: "abc-123" })));

// Durable consumer
await jsm.consumers.add("MARKETPLACE", {
  durable_name: "search-indexer", ack_policy: AckPolicy.Explicit,
  deliver_policy: DeliverPolicy.All, filter_subject: "marketplace.component.*",
});
const messages = await (await js.consumers.get("MARKETPLACE", "search-indexer")).consume();
for await (const msg of messages) {
  await processEvent(msg.subject, JSON.parse(sc.decode(msg.data)));
  msg.ack();
}
```

### Request/Reply

```typescript
// Responder
for await (const msg of nc.subscribe("marketplace.rpc.getComponent")) {
  const component = await componentService.getById(JSON.parse(sc.decode(msg.data)).id);
  msg.respond(sc.encode(JSON.stringify(component)));
}

// Requester
const resp = await nc.request("marketplace.rpc.getComponent",
  sc.encode(JSON.stringify({ id: "abc-123" })), { timeout: 5000 });
```

## Docker Compose (Local Dev)

```yaml
services:
  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
  rabbitmq:
    image: rabbitmq:4-management-alpine
    ports: ["5672:5672", "15672:15672"]
  kafka:
    image: bitnami/kafka:3.8
    ports: ["9092:9092"]
    environment:
      KAFKA_CFG_NODE_ID: 0
      KAFKA_CFG_PROCESS_ROLES: controller,broker
      KAFKA_CFG_CONTROLLER_QUORUM_VOTERS: 0@kafka:9093
      KAFKA_CFG_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9093
      KAFKA_CFG_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_CFG_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
  nats:
    image: nats:2-alpine
    ports: ["4222:4222", "8222:8222"]
    command: ["--jetstream", "--store_dir=/data", "-m", "8222"]
```

## Testing Patterns

### EventEmitter (Vitest)

```typescript
import { describe, it, expect, vi } from "vitest";

describe("TypedEventEmitter", () => {
  it("dispatches to registered handlers", () => {
    const bus = new TypedEventEmitter<{ "item.created": [{ id: string }] }>();
    const handler = vi.fn();
    bus.on("item.created", handler);
    bus.emit("item.created", { id: "abc" });
    expect(handler).toHaveBeenCalledWith({ id: "abc" });
  });
});
```

### BullMQ (integration with Redis)

```typescript
import { describe, it, expect, afterAll } from "vitest";
import { Queue, Worker, type Job } from "bullmq";

const connection = { host: "localhost", port: 6379 };

describe("component queue", () => {
  const queue = new Queue("test-queue", { connection });
  afterAll(async () => { await queue.obliterate({ force: true }); await queue.close(); });

  it("processes a job", async () => {
    const results: string[] = [];
    const worker = new Worker("test-queue", async (job: Job) => { results.push(job.data.action); }, { connection });
    await queue.add("test", { componentId: "x", action: "validate" });
    await new Promise<void>((r) => worker.on("completed", () => r()));
    expect(results).toContain("validate");
    await worker.close();
  });
});
```

### Kafka (testcontainers)

```typescript
import { GenericContainer, type StartedTestContainer } from "testcontainers";

let container: StartedTestContainer;
beforeAll(async () => {
  container = await new GenericContainer("bitnami/kafka:3.8")
    .withExposedPorts(9092).withEnvironment({ /* KRaft config */ }).start();
}, 60_000);
afterAll(() => container?.stop());

it("roundtrip publish/consume", async () => {
  const producer = new KafkaEventProducer();
  await producer.connect();
  await producer.publish("test-topic", "key-1", { action: "test" });
  await producer.disconnect();
  // assert consumer receives...
});
```

## Graduated Migration Path

```
Phase 1: TypedEventEmitter (in-process)
    +-- MVP, single service, < 100 req/s
    +-- Upgrade trigger: need retry, persistence, crash recovery

Phase 2: BullMQ + Redis
    +-- Background jobs, scheduling, rate limiting, < 1K req/s
    +-- Upgrade trigger: pub/sub routing, multiple consumers

Phase 3a: RabbitMQ           |  Phase 3b: Redis Streams
    +-- Routing, fanout, DLX |      +-- Event sourcing lite, < 10K msg/s
    +-- Upgrade: replay need |      +-- Upgrade: cross-service, high throughput

Phase 4a: Kafka.js           |  Phase 4b: NATS
    +-- Multi-service, audit |      +-- Cloud-native, request/reply
    +-- > 10K msg/s          |      +-- JetStream, lighter ops than Kafka
```

## Anti-Patterns

**Untyped events** -- Always define event interfaces. Loose string events lead to silent failures when producers change payload shape.

**Ignoring backpressure** -- Use BullMQ `limiter`, Kafka `maxInFlightRequests`, or NATS flow control. Unbounded producers exhaust Redis memory or Kafka disk.

**No dead-letter handling** -- Configure BullMQ `removeOnFail`, RabbitMQ DLX, or Kafka error topics. Never silently drop failures.

**Shared Redis for cache and queue** -- Eviction policies (`allkeys-lru`) will delete queue data. Use separate instances.

**Missing idempotency** -- At-least-once means duplicates. Use dedup keys, upserts, or idempotency tables.

**Giant payloads** -- Keep messages small (IDs + metadata). Store blobs in object storage. Kafka default limit: 1MB.

**No graceful shutdown** -- Always drain in-flight work on `SIGTERM`/`SIGINT`:

```typescript
const shutdown = async (signal: string) => {
  console.log(`${signal} received, draining...`);
  await worker.close();        // BullMQ
  await consumer.disconnect(); // Kafka
  await nc.drain();            // NATS
  process.exit(0);
};
process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
```
