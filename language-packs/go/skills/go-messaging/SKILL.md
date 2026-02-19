---
name: go-messaging
description: "Messaging and middleware patterns for Go — channels, goroutines, NATS, RabbitMQ, Redis Streams, Kafka. Graduated complexity from simple to enterprise scale."
user-invocable: false
allowed-tools: Read, Grep, Glob
catalog_description: "Messaging patterns — channels, NATS, RabbitMQ, Redis Streams, Kafka."
---

# Go Messaging & Middleware Patterns

Graduated messaging patterns from in-process concurrency primitives to distributed streaming.

## Decision Matrix

| Pattern | Complexity | Persistence | Scale | Use When |
|---------|-----------|-------------|-------|----------|
| Channels (fan-out/fan-in) | Minimal | None | Single process | In-process pipelines, no durability needed |
| Goroutines + Context | Low | None | Single process | Cancellation, timeouts, graceful shutdown |
| NATS (nats.go) | Low | Optional (JetStream) | Multi-service | Lightweight pub/sub, request/reply, cloud-native |
| RabbitMQ (amqp091-go) | Medium | Broker | Multi-worker | Task queues, routing, dead-letter handling |
| Redis Streams (go-redis/v9) | Medium | Redis | Multi-consumer | Event sourcing lite, consumer groups |
| Kafka (segmentio/kafka-go) | High | Kafka cluster | Multi-service | High-throughput event streaming, audit logs |

## 1. Channels -- Fan-Out / Fan-In

Zero dependencies. Use channels as typed, in-process message queues with generics.

```go
package pipeline

import "sync"

type Result[T any] struct {
    Value T
    Err   error
}

// FanOut distributes work from source to n workers applying fn.
func FanOut[In, Out any](source <-chan In, n int, fn func(In) Result[Out]) []<-chan Result[Out] {
    outputs := make([]<-chan Result[Out], n)
    for i := range n {
        ch := make(chan Result[Out])
        outputs[i] = ch
        go func() {
            defer close(ch)
            for item := range source {
                ch <- fn(item)
            }
        }()
    }
    return outputs
}

// FanIn merges multiple channels into one.
func FanIn[T any](channels ...<-chan T) <-chan T {
    var wg sync.WaitGroup
    merged := make(chan T)
    wg.Add(len(channels))
    for _, ch := range channels {
        go func() {
            defer wg.Done()
            for val := range ch {
                merged <- val
            }
        }()
    }
    go func() { wg.Wait(); close(merged) }()
    return merged
}
```

```go
// Usage: fan out to 5 workers, fan in results
source := make(chan string, 100)
go func() { defer close(source); for _, u := range urls { source <- u } }()

workers := FanOut(source, 5, func(url string) Result[int] {
    code, err := fetchStatusCode(url)
    return Result[int]{Value: code, Err: err}
})
for r := range FanIn(workers...) {
    if r.Err != nil { slog.Error("failed", "error", r.Err); continue }
    slog.Info("status", "code", r.Value)
}
```

**Limitations:** No persistence, no retry, single process only.

## 2. Goroutines + Context -- Cancellation & Graceful Shutdown

Every long-lived goroutine must respect `context.Context`. Non-negotiable in production Go.

```go
type Pool[T any] struct {
    jobs    chan T
    handler func(context.Context, T) error
    workers int
}

func NewPool[T any](workers, buf int, h func(context.Context, T) error) *Pool[T] {
    return &Pool[T]{jobs: make(chan T, buf), handler: h, workers: workers}
}

func (p *Pool[T]) Run(ctx context.Context) {
    var wg sync.WaitGroup
    for range p.workers {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for {
                select {
                case job, ok := <-p.jobs:
                    if !ok { return }
                    jctx, cancel := context.WithTimeout(ctx, 30*time.Second)
                    if err := p.handler(jctx, job); err != nil {
                        slog.Error("job failed", "error", err)
                    }
                    cancel()
                case <-ctx.Done():
                    for job := range p.jobs { // drain remaining
                        dc, c := context.WithTimeout(context.Background(), 5*time.Second)
                        _ = p.handler(dc, job); c()
                    }
                    return
                }
            }
        }()
    }
    <-ctx.Done(); close(p.jobs); wg.Wait()
}
```

```go
// Signal-based graceful shutdown
ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
defer stop()
pool := worker.NewPool(4, 100, processEvent)
pool.Run(ctx) // blocks until signal, drains, exits
```

## 3. NATS -- Lightweight Cloud-Native Messaging

Minimal latency pub/sub with optional persistence via JetStream. Single binary server.

```bash
go get github.com/nats-io/nats.go
```

```go
type Event struct {
    Type string          `json:"type"`
    Data json.RawMessage `json:"data"`
}

type NATSBus struct{ conn *nats.Conn }

func NewNATSBus(url string) (*NATSBus, error) {
    nc, err := nats.Connect(url, nats.RetryOnFailedConnect(true), nats.MaxReconnects(-1))
    if err != nil { return nil, err }
    return &NATSBus{conn: nc}, nil
}

func (b *NATSBus) Publish(subject string, event Event) error {
    data, _ := json.Marshal(event)
    return b.conn.Publish(subject, data)
}

func (b *NATSBus) Subscribe(subject string, h func(Event)) (*nats.Subscription, error) {
    return b.conn.Subscribe(subject, func(msg *nats.Msg) {
        var e Event
        if json.Unmarshal(msg.Data, &e) == nil { h(e) }
    })
}

// QueueSubscribe load-balances across a consumer group.
func (b *NATSBus) QueueSubscribe(subject, queue string, h func(Event)) (*nats.Subscription, error) {
    return b.conn.QueueSubscribe(subject, queue, func(msg *nats.Msg) {
        var e Event
        if json.Unmarshal(msg.Data, &e) == nil { h(e) }
    })
}

func (b *NATSBus) Close() { b.conn.Drain() }

// JetStream adds persistence. Call once at startup.
func (b *NATSBus) SetupJetStream(name string, subjects []string) (nats.JetStreamContext, error) {
    js, err := b.conn.JetStream()
    if err != nil { return nil, err }
    _, err = js.AddStream(&nats.StreamConfig{
        Name: name, Subjects: subjects,
        Retention: nats.LimitsPolicy, MaxAge: 72 * time.Hour, Storage: nats.FileStorage,
    })
    return js, err
}
```

```yaml
# docker-compose.yml
services:
  nats:
    image: nats:2.10-alpine
    ports: ["4222:4222", "8222:8222"]
    command: ["--jetstream", "--store_dir", "/data"]
    volumes: [nats_data:/data]
volumes:
  nats_data:
```

## 4. RabbitMQ -- Task Queues with Routing

Reliable work queues with ack/nack, dead-letter exchanges, and flexible routing.

```bash
go get github.com/rabbitmq/amqp091-go
```

```go
type Client struct { conn *amqp.Connection; ch *amqp.Channel }

func NewClient(url string) (*Client, error) {
    conn, err := amqp.Dial(url)
    if err != nil { return nil, fmt.Errorf("dial: %w", err) }
    ch, err := conn.Channel()
    if err != nil { conn.Close(); return nil, fmt.Errorf("channel: %w", err) }
    ch.Qos(1, 0, false) // prefetch 1 for fair dispatch
    return &Client{conn: conn, ch: ch}, nil
}

// DeclareWithDLX sets up queue + dead-letter exchange for poison message handling.
func (c *Client) DeclareWithDLX(queue string) error {
    dlx, dlq := queue+".dlx", queue+".dead"
    c.ch.ExchangeDeclare(dlx, "direct", true, false, false, false, nil)
    c.ch.QueueDeclare(dlq, true, false, false, false, nil)
    c.ch.QueueBind(dlq, queue, dlx, false, nil)
    _, err := c.ch.QueueDeclare(queue, true, false, false, false, amqp.Table{
        "x-dead-letter-exchange": dlx, "x-dead-letter-routing-key": queue,
    })
    return err
}

func (c *Client) Publish(ctx context.Context, queue string, body any) error {
    data, _ := json.Marshal(body)
    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()
    return c.ch.PublishWithContext(ctx, "", queue, false, false, amqp.Publishing{
        DeliveryMode: amqp.Persistent, ContentType: "application/json",
        Body: data, Timestamp: time.Now(),
    })
}

func (c *Client) Consume(ctx context.Context, queue string, handler func([]byte) error) error {
    msgs, err := c.ch.Consume(queue, "", false, false, false, false, nil)
    if err != nil { return err }
    for {
        select {
        case msg, ok := <-msgs:
            if !ok { return nil }
            if err := handler(msg.Body); err != nil {
                msg.Nack(false, false) // -> DLX
            } else { msg.Ack(false) }
        case <-ctx.Done(): return ctx.Err()
        }
    }
}

func (c *Client) Close() { c.ch.Close(); c.conn.Close() }
```

```yaml
# docker-compose.yml
services:
  rabbitmq:
    image: rabbitmq:3.13-management-alpine
    ports: ["5672:5672", "15672:15672"]
    environment:
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: guest
    volumes: [rabbitmq_data:/var/lib/rabbitmq]
volumes:
  rabbitmq_data:
```

## 5. Redis Streams -- Consumer Groups

Persistent ordered event log with consumer groups. Event sourcing lite without Kafka overhead.

```bash
go get github.com/redis/go-redis/v9
```

```go
type Stream struct { client *redis.Client; name string }

func NewStream(c *redis.Client, name string) *Stream { return &Stream{client: c, name: name} }

func (s *Stream) Publish(ctx context.Context, eventType string, data any) (string, error) {
    payload, _ := json.Marshal(data)
    return s.client.XAdd(ctx, &redis.XAddArgs{
        Stream: s.name, MaxLen: 10000, Approx: true,
        Values: map[string]any{"event_type": eventType, "data": string(payload)},
    }).Result()
}

func (s *Stream) Consume(ctx context.Context, group, consumer string, handler func(string, []byte) error) error {
    err := s.client.XGroupCreateMkStream(ctx, s.name, group, "0").Err()
    if err != nil && err.Error() != "BUSYGROUP Consumer Group name already exists" {
        return fmt.Errorf("create group: %w", err)
    }
    for {
        select { case <-ctx.Done(): return ctx.Err(); default: }
        streams, err := s.client.XReadGroup(ctx, &redis.XReadGroupArgs{
            Group: group, Consumer: consumer, Streams: []string{s.name, ">"},
            Count: 10, Block: 5 * time.Second,
        }).Result()
        if err != nil { if err == redis.Nil { continue }; return err }
        for _, st := range streams {
            for _, msg := range st.Messages {
                et, data := msg.Values["event_type"].(string), []byte(msg.Values["data"].(string))
                if err := handler(et, data); err != nil {
                    slog.Error("handler failed", "error", err, "id", msg.ID)
                    continue // skip ack -- reclaim via XPENDING
                }
                s.client.XAck(ctx, s.name, group, msg.ID)
            }
        }
    }
}
```

```go
rdb := redis.NewClient(&redis.Options{Addr: "localhost:6379"})
stream := redisstream.NewStream(rdb, "service-events")
stream.Publish(ctx, "order.created", map[string]any{"order_id": "ord-123"})
stream.Consume(ctx, "billing-group", "worker-1", func(et string, data []byte) error {
    if et == "order.created" { return processBilling(data) }
    return nil
})
```

## 6. Kafka -- High-Throughput Event Streaming

Partitioned, replicated, ordered event streams at scale.

```bash
go get github.com/segmentio/kafka-go
```

```go
type Producer struct{ writer *kafka.Writer }

func NewProducer(brokers []string, topic string) *Producer {
    return &Producer{writer: &kafka.Writer{
        Addr: kafka.TCP(brokers...), Topic: topic,
        Balancer: &kafka.LeastBytes{}, RequiredAcks: kafka.RequireAll,
    }}
}

func (p *Producer) Publish(ctx context.Context, key string, event any) error {
    data, _ := json.Marshal(event)
    return p.writer.WriteMessages(ctx, kafka.Message{Key: []byte(key), Value: data})
}

func (p *Producer) Close() error { return p.writer.Close() }

type Consumer struct{ reader *kafka.Reader }

func NewConsumer(brokers []string, topic, groupID string) *Consumer {
    return &Consumer{reader: kafka.NewReader(kafka.ReaderConfig{
        Brokers: brokers, Topic: topic, GroupID: groupID,
        MinBytes: 1e3, MaxBytes: 10e6, StartOffset: kafka.FirstOffset,
    })}
}

func (c *Consumer) Consume(ctx context.Context, handler func(key, value []byte) error) error {
    for {
        msg, err := c.reader.FetchMessage(ctx)
        if err != nil { return err }
        if err := handler(msg.Key, msg.Value); err != nil {
            slog.Error("failed", "error", err, "offset", msg.Offset); continue
        }
        if err := c.reader.CommitMessages(ctx, msg); err != nil { return err }
    }
}

func (c *Consumer) Close() error { return c.reader.Close() }
```

**Topic design:** Key by entity ID for ordering. Co-partition related topics (orders + payments both keyed by `order_id`). Separate topic for append-only audit with long retention.

```yaml
# docker-compose.yml (KRaft mode, no ZooKeeper)
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

**Channels/goroutines** -- pure unit tests, no infrastructure:

```go
func TestFanOutFanIn(t *testing.T) {
    source := make(chan int, 5)
    for i := range 5 { source <- i }
    close(source)
    workers := FanOut(source, 3, func(n int) Result[int] { return Result[int]{Value: n * 2} })
    var got int
    for r := range FanIn(workers...) { if r.Err != nil { t.Fatal(r.Err) }; got++ }
    if got != 5 { t.Fatalf("expected 5, got %d", got) }
}
```

**NATS** -- embedded test server, no Docker:

```go
func runTestServer(t *testing.T) string {
    t.Helper()
    srv, _ := natsserver.NewServer(&natsserver.Options{Port: -1})
    srv.Start(); t.Cleanup(srv.Shutdown)
    if !srv.ReadyForConnections(3 * time.Second) { t.Fatal("not ready") }
    return srv.ClientURL()
}

func TestNATSPubSub(t *testing.T) {
    bus, _ := NewNATSBus(runTestServer(t))
    defer bus.Close()
    ch := make(chan Event, 1)
    bus.Subscribe("test.>", func(e Event) { ch <- e })
    bus.Publish("test.foo", Event{Type: "ping", Data: json.RawMessage(`{}`)})
    select {
    case e := <-ch: if e.Type != "ping" { t.Fail() }
    case <-time.After(2 * time.Second): t.Fatal("timeout")
    }
}
```

**Kafka/RabbitMQ/Redis** -- `testcontainers-go` for integration tests:

```go
func TestKafkaRoundtrip(t *testing.T) {
    ctx := context.Background()
    ctr, _ := kafka.Run(ctx, "confluentinc/confluent-local:7.6.0")
    t.Cleanup(func() { ctr.Terminate(ctx) })
    brokers, _ := ctr.Brokers(ctx)

    p := NewProducer(brokers, "test-topic"); defer p.Close()
    p.Publish(ctx, "k1", map[string]string{"action": "test"})

    c := NewConsumer(brokers, "test-topic", "test-group"); defer c.Close()
    rctx, cancel := context.WithTimeout(ctx, 10*time.Second); defer cancel()
    msg, _ := c.reader.FetchMessage(rctx)
    if string(msg.Key) != "k1" { t.Fatalf("got key %s", msg.Key) }
}
```

Same pattern with `modules/rabbitmq` and `modules/redis`.

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| Goroutine leak | Blocks forever, no ctx | Always `select` on `<-ctx.Done()` |
| Unbuffered deadlock | Send + recv in same goroutine | Buffer the channel or split goroutines |
| Missing `close(ch)` | `range` loops hang forever | Producer must `defer close(ch)` |
| Bare `go func()` | No error recovery, no tracking | Use `errgroup.Group` or worker pool |
| Ignoring context | No cancel, no timeout | Thread ctx everywhere; respect `ctx.Done()` |
| Shared state, no sync | Data races | Communicate via channels or use `sync.Mutex` |
| Busy-wait polling | CPU waste | Use blocking channel recv or `select` |
| No DLX/DLQ (brokers) | Poison messages block queue | Nack after max retries, route to dead-letter |

## Graduated Migration Path

```
Phase 1: Channels + Goroutines
    -- Single-binary services, CLI tools, < 1K msg/s in-process
    -- Upgrade when: need persistence or cross-process delivery

Phase 2: NATS (Core or JetStream)
    -- Microservices pub/sub, request/reply, < 50K msg/s
    -- Upgrade when: need complex routing, priority queues, DLX

Phase 3: RabbitMQ
    -- Task queues, routing topologies, < 30K msg/s durable
    -- Upgrade when: need event replay, consumer groups at scale

Phase 4: Redis Streams
    -- Event sourcing lite, consumer groups, < 100K msg/s
    -- Upgrade when: need partitioning, replication, multi-DC

Phase 5: Kafka
    -- High-throughput streaming, audit logs, > 100K msg/s
    -- Enterprise scale, full event streaming platform
```
