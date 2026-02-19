---
name: rust-messaging
description: "Messaging and middleware patterns for Rust — tokio channels, crossbeam, NATS, RabbitMQ (lapin), Redis Streams, Kafka (rdkafka). Graduated complexity from simple to enterprise scale."
user-invocable: false
allowed-tools: Read, Grep, Glob
catalog_description: "Messaging patterns — tokio channels, NATS, lapin, Redis Streams, rdkafka."
---

# Rust Messaging & Middleware Patterns

Graduated messaging patterns from in-process channels to distributed streaming. Pick the right tool for your scale.

## Decision Matrix

| Pattern | Complexity | Persistence | Scale | Use When |
|---------|-----------|-------------|-------|----------|
| Tokio Channels | Minimal | None | Single process | Task coordination, fan-out within one binary |
| Crossbeam Channels | Minimal | None | Single process | CPU-bound pipelines, MPMC, blocking threads |
| NATS (async-nats) | Low | Optional (JetStream) | Multi-service | Lightweight pub/sub, request-reply |
| RabbitMQ (lapin) | Medium | Broker | Multi-service | Reliable task queues, routing, dead-letter |
| Redis Streams (redis-rs) | Medium | Redis | Multi-consumer | Event sourcing lite, consumer groups |
| Kafka (rdkafka) | High | Kafka cluster | Multi-service | High-throughput streaming, audit logs, replay |

## 1. Tokio Channels

Zero external dependencies beyond `tokio`. Four channel types for different coordination patterns.

```toml
[dependencies]
tokio = { version = "1", features = ["full"] }
```

### mpsc -- Multiple producers, single consumer

The workhorse channel. Use for task queues and actor-style message passing.

```rust
use tokio::sync::mpsc;

#[derive(Debug)]
enum Command {
    Process { id: u64, payload: String },
    Shutdown,
}

async fn worker(mut rx: mpsc::Receiver<Command>) {
    while let Some(cmd) = rx.recv().await {
        match cmd {
            Command::Process { id, payload } => println!("processing {id}: {payload}"),
            Command::Shutdown => break,
        }
    }
}

let (tx, rx) = mpsc::channel::<Command>(64);
let handle = tokio::spawn(worker(rx));
let tx2 = tx.clone(); // multiple producers
tx.send(Command::Process { id: 1, payload: "hello".into() }).await.unwrap();
tx2.send(Command::Shutdown).await.unwrap();
drop(tx); drop(tx2);
handle.await.unwrap();
```

### broadcast -- Fan-out to all consumers

```rust
let (tx, _) = tokio::sync::broadcast::channel::<String>(128);
let mut rx1 = tx.subscribe();
let mut rx2 = tx.subscribe();
tx.send("event happened".into()).unwrap();
assert_eq!(rx1.recv().await.unwrap(), "event happened");
assert_eq!(rx2.recv().await.unwrap(), "event happened");
```

### watch -- Latest-value (config updates, shutdown signals)

```rust
let (tx, mut rx) = tokio::sync::watch::channel(false);
tokio::spawn(async move {
    while !*rx.borrow_and_update() { rx.changed().await.unwrap(); }
    println!("shutdown received");
});
tx.send(true).unwrap();
```

### oneshot -- Single request-reply

```rust
let (tx, rx) = tokio::sync::oneshot::channel();
tokio::spawn(async move { tx.send("result".to_string()).unwrap(); });
let response = rx.await.unwrap();
```

**Limitations:** No persistence, no retry, single process only.

## 2. Crossbeam Channels

MPMC with `select!`. Best for CPU-bound thread pools, not async code.

```toml
[dependencies]
crossbeam-channel = "0.5"
```

```rust
use crossbeam_channel::{bounded, select, tick, Receiver};
use std::{thread, time::Duration};

fn worker_pool(rx: Receiver<String>, count: usize) -> Vec<thread::JoinHandle<()>> {
    (0..count).map(|i| {
        let rx = rx.clone();
        thread::spawn(move || { while let Ok(msg) = rx.recv() { println!("w{i}: {msg}"); } })
    }).collect()
}

let (tx, rx) = bounded::<String>(128);
let handles = worker_pool(rx.clone(), 4);
// select! for multiplexing multiple channels
let ticker = tick(Duration::from_secs(5));
select! {
    recv(rx) -> msg => println!("{}", msg.unwrap()),
    recv(ticker) -> _ => println!("heartbeat"),
}
drop(tx);
for h in handles { h.join().unwrap(); }
```

**When to use crossbeam vs tokio:** Use crossbeam for blocking thread pools. Use tokio channels inside async runtimes. Never mix blocking crossbeam calls in async tasks.

## 3. NATS (async-nats)

Lightweight, high-performance messaging. JetStream adds persistence and exactly-once delivery.

```toml
[dependencies]
async-nats = "0.38"
tokio = { version = "1", features = ["full"] }
serde_json = "1"
```

### Pub/Sub and Request-Reply

```rust
use async_nats::Client;

async fn pub_sub(client: &Client) -> Result<(), async_nats::Error> {
    let mut sub = client.subscribe("events.>").await?;
    client.publish("events.component", r#"{"id":"abc"}"#.into()).await?;
    let msg = sub.next().await.unwrap();
    println!("{}", String::from_utf8_lossy(&msg.payload));
    Ok(())
}

// Request-reply: built-in timeout
let resp = client.request("services.lookup", "query".into()).await?;
```

### JetStream (persistent streams)

```rust
use async_nats::jetstream;

let js = jetstream::new(client);
js.create_stream(jetstream::stream::Config {
    name: "COMPONENTS".into(),
    subjects: vec!["components.>".into()],
    retention: jetstream::stream::RetentionPolicy::WorkQueue,
    ..Default::default()
}).await?;

js.publish("components.created", "payload".into()).await?.await?;

let consumer = js.create_consumer_on_stream(
    jetstream::consumer::pull::Config {
        durable_name: Some("indexer".into()),
        ..Default::default()
    },
    "COMPONENTS",
).await?;

let mut messages = consumer.messages().await?;
while let Some(Ok(msg)) = messages.next().await {
    println!("{}", String::from_utf8_lossy(&msg.payload));
    msg.ack().await?;
}
```

**Docker:** `docker run -d --name nats -p 4222:4222 -p 8222:8222 nats:2.10 --jetstream --store_dir /data`

## 4. RabbitMQ (lapin)

Async AMQP client. Rich routing, dead-letter queues, TTL, priority queues.

```toml
[dependencies]
lapin = "2"
tokio = { version = "1", features = ["full"] }
tokio-executor-trait = "2"
tokio-reactor-trait = "1"
serde_json = "1"
```

### Producer and Consumer

```rust
use lapin::{options::*, types::FieldTable, BasicProperties, Connection, ConnectionProperties};
use futures_lite::StreamExt;

async fn setup() -> Result<lapin::Channel, lapin::Error> {
    let conn = Connection::connect(
        "amqp://guest:guest@localhost:5672",
        ConnectionProperties::default()
            .with_executor(tokio_executor_trait::Tokio::current())
            .with_reactor(tokio_reactor_trait::Tokio),
    ).await?;
    let ch = conn.create_channel().await?;
    ch.queue_declare("tasks", QueueDeclareOptions::default(), FieldTable::default()).await?;
    Ok(ch)
}

// Publish with persistence
async fn publish(ch: &lapin::Channel, task: &serde_json::Value) -> Result<(), lapin::Error> {
    ch.basic_publish("", "tasks", BasicPublishOptions::default(),
        &serde_json::to_vec(task).unwrap(),
        BasicProperties::default().with_delivery_mode(2), // persistent
    ).await?.await?;
    Ok(())
}

// Consume with manual ack
async fn consume(ch: &lapin::Channel) -> Result<(), lapin::Error> {
    ch.basic_qos(10, BasicQosOptions::default()).await?;
    let mut consumer = ch.basic_consume(
        "tasks", "worker-1", BasicConsumeOptions::default(), FieldTable::default(),
    ).await?;
    while let Some(delivery) = consumer.next().await {
        let delivery = delivery?;
        let task: serde_json::Value = serde_json::from_slice(&delivery.data).unwrap();
        println!("processing: {task}");
        delivery.ack(BasicAckOptions::default()).await?;
    }
    Ok(())
}
```

### Dead-letter queue setup

```rust
let mut args = FieldTable::default();
args.insert("x-dead-letter-exchange".into(),
    lapin::types::AMQPValue::LongString("dlx".into()));
args.insert("x-message-ttl".into(),
    lapin::types::AMQPValue::LongLong(60_000));
ch.queue_declare("tasks", QueueDeclareOptions::default(), args).await?;
```

**Docker:** `docker run -d --name rabbitmq -p 5672:5672 -p 15672:15672 rabbitmq:3.13-management`

## 5. Redis Streams (redis-rs)

Persistent ordered event log with consumer groups. Lighter operational footprint than Kafka.

```toml
[dependencies]
redis = { version = "0.27", features = ["tokio-comp", "streams"] }
tokio = { version = "1", features = ["full"] }
serde_json = "1"
```

### Producer and Consumer

```rust
use redis::AsyncCommands;
use redis::streams::{StreamReadOptions, StreamReadReply};

async fn publish_event(
    conn: &mut redis::aio::MultiplexedConnection,
    stream: &str, event_type: &str, data: &serde_json::Value,
) -> redis::RedisResult<String> {
    conn.xadd_maxlen(stream, redis::streams::StreamMaxlen::Approx(10_000), "*", &[
        ("event_type", event_type),
        ("data", &serde_json::to_string(data).unwrap()),
    ]).await
}

async fn consume_stream(
    conn: &mut redis::aio::MultiplexedConnection,
    stream: &str, group: &str, consumer: &str,
) -> redis::RedisResult<()> {
    // Create consumer group (ignore if exists)
    let _: redis::RedisResult<()> = redis::cmd("XGROUP")
        .arg("CREATE").arg(stream).arg(group).arg("0").arg("MKSTREAM")
        .query_async(conn).await;

    let opts = StreamReadOptions::default().group(group, consumer).count(10).block(5_000);
    loop {
        let reply: StreamReadReply = conn.xread_options(&[stream], &[">"], &opts).await?;
        for key in &reply.keys {
            for id in &key.ids {
                println!("event: {}", id.id);
                let _: () = conn.xack(stream, group, &[&id.id]).await?;
            }
        }
    }
}
```

**Docker:** `docker run -d --name redis -p 6379:6379 redis:7-alpine redis-server --appendonly yes`

## 6. Kafka (rdkafka)

High-throughput distributed event streaming via librdkafka bindings.

```toml
[dependencies]
rdkafka = { version = "0.36", features = ["cmake-build", "tokio"] }
tokio = { version = "1", features = ["full"] }
serde_json = "1"
```

**Note:** `cmake-build` compiles librdkafka from source. Ensure `cmake` and a C compiler are on CI. Use `dynamic-linking` feature for system-installed librdkafka instead.

### Producer and Consumer

```rust
use rdkafka::config::ClientConfig;
use rdkafka::producer::{FutureProducer, FutureRecord};
use rdkafka::consumer::{CommitMode, Consumer, StreamConsumer};
use rdkafka::Message;
use std::time::Duration;

fn create_producer(brokers: &str) -> FutureProducer {
    ClientConfig::new()
        .set("bootstrap.servers", brokers)
        .set("message.timeout.ms", "5000")
        .set("acks", "all")
        .create().expect("producer creation failed")
}

async fn publish(producer: &FutureProducer, topic: &str, key: &str, event: &serde_json::Value)
    -> Result<(), Box<dyn std::error::Error>>
{
    let payload = serde_json::to_string(event)?;
    producer.send(FutureRecord::to(topic).key(key).payload(&payload), Duration::from_secs(5))
        .await.map_err(|(e, _)| e)?;
    Ok(())
}

fn create_consumer(brokers: &str, group_id: &str, topics: &[&str]) -> StreamConsumer {
    let consumer: StreamConsumer = ClientConfig::new()
        .set("bootstrap.servers", brokers)
        .set("group.id", group_id)
        .set("enable.auto.commit", "false")
        .set("auto.offset.reset", "earliest")
        .create().expect("consumer creation failed");
    consumer.subscribe(topics).expect("subscription failed");
    consumer
}

async fn consume_loop(consumer: &StreamConsumer) {
    use tokio_stream::StreamExt;
    let mut stream = consumer.stream();
    while let Some(Ok(msg)) = stream.next().await {
        if let Some(payload) = msg.payload() {
            let event: serde_json::Value = serde_json::from_slice(payload).unwrap_or_default();
            println!("[{}] {event}", msg.topic());
        }
        consumer.commit_message(&msg, CommitMode::Async).unwrap();
    }
}
```

### Topic Design

```
app.components      -- CRUD events (keyed by component_id)
app.ratings          -- rating events (keyed by component_id for co-partition)
app.downloads        -- download tracking (keyed by component_id)
app.notifications    -- email/push triggers (keyed by user_id)
```

### Docker Compose

```yaml
services:
  kafka:
    image: bitnami/kafka:3.7
    ports: ["9092:9092"]
    environment:
      KAFKA_CFG_NODE_ID: 0
      KAFKA_CFG_PROCESS_ROLES: controller,broker
      KAFKA_CFG_CONTROLLER_QUORUM_VOTERS: 0@kafka:9093
      KAFKA_CFG_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9093
      KAFKA_CFG_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_CFG_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
    volumes: [kafka_data:/bitnami/kafka]
volumes:
  kafka_data:
```

## Testing Patterns

### Tokio channels (unit test, no infra)

```rust
#[tokio::test]
async fn test_mpsc_round_trip() {
    let (tx, mut rx) = tokio::sync::mpsc::channel::<String>(8);
    tx.send("hello".into()).await.unwrap();
    drop(tx);
    assert_eq!(rx.recv().await.unwrap(), "hello");
    assert!(rx.recv().await.is_none());
}
```

### NATS (integration test)

```rust
#[tokio::test]
async fn test_nats_pub_sub() {
    let client = async_nats::connect("nats://localhost:4222").await.unwrap();
    let mut sub = client.subscribe("test.subject").await.unwrap();
    client.publish("test.subject", "ping".into()).await.unwrap();
    client.flush().await.unwrap();
    let msg = tokio::time::timeout(Duration::from_secs(2), sub.next()).await.unwrap().unwrap();
    assert_eq!(&msg.payload[..], b"ping");
}
```

### Kafka (with testcontainers)

```toml
[dev-dependencies]
testcontainers = "0.23"
testcontainers-modules = { version = "0.11", features = ["kafka"] }
```

```rust
use testcontainers::runners::AsyncRunner;
use testcontainers_modules::kafka::Kafka;

#[tokio::test]
async fn test_kafka_round_trip() {
    let node = Kafka::default().start().await.unwrap();
    let brokers = format!("127.0.0.1:{}", node.get_host_port_ipv4(9093).await.unwrap());
    let producer = create_producer(&brokers);
    publish(&producer, "test-topic", "k1", &serde_json::json!({"action": "test"})).await.unwrap();
    // consume with timeout and assert...
}
```

## Anti-Patterns

**Blocking in async context.** Never use `crossbeam_channel` or `std::sync::mpsc` inside tokio tasks. Use `tokio::sync` channels or `tokio::task::spawn_blocking`.

```rust
// BAD -- blocks the tokio worker thread
async fn bad(rx: crossbeam_channel::Receiver<String>) {
    let msg = rx.recv().unwrap(); // stalls executor
}

// GOOD -- offload to blocking thread pool
async fn good(rx: crossbeam_channel::Receiver<String>) {
    let msg = tokio::task::spawn_blocking(move || rx.recv().unwrap()).await.unwrap();
}
```

**Unbounded channels without backpressure.** `mpsc::unbounded_channel()` grows without limit under load. Always prefer bounded channels.

**Ignoring acknowledgements.** With RabbitMQ, Redis Streams, and Kafka, always ack after processing. Auto-ack or forgetting `xack`/`commit` causes message loss or infinite redelivery.

**`bincode` across service boundaries.** Binary formats break across versions. Use `serde_json` or protobuf for inter-service messages. Reserve `bincode` for in-process communication.

**Single consumer on partitioned Kafka topic.** Match consumer count to partition count within a consumer group to use available parallelism.

## Graduated Migration Path

```
Phase 1: Tokio Channels (in-process)
    |-- Good for: MVP, single binary, task coordination
    |-- Upgrade trigger: need persistence or multi-process

Phase 2: NATS
    |-- Good for: microservice pub/sub, request-reply, < 100K msg/s
    |-- Add JetStream when persistence needed
    |-- Upgrade trigger: complex routing, dead-letter, priority queues

Phase 3: RabbitMQ (lapin) or Redis Streams
    |-- RabbitMQ: reliable task queues, routing topologies, DLQ
    |-- Redis Streams: event sourcing lite, already running Redis
    |-- Upgrade trigger: high-throughput replay, cross-datacenter

Phase 4: Kafka (rdkafka)
    |-- Good for: multi-service streaming, audit logs, > 100K msg/s
    |-- Enterprise scale, full event replay, compacted topics
```
