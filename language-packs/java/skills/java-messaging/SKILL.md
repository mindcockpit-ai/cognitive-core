---
name: java-messaging
description: "Messaging and middleware patterns for Java — in-process events, Spring Events, RabbitMQ, JMS, Kafka, Redis Streams. Graduated complexity from simple to enterprise scale."
user-invocable: false
allowed-tools: Read, Grep, Glob
catalog_description: "Messaging patterns — Spring Events, RabbitMQ, JMS, Kafka, Redis Streams."
---

# Java Messaging & Middleware Patterns

Graduated messaging patterns from in-process to distributed. Pick the right tool for your scale.

## Decision Matrix

| Pattern | Complexity | Persistence | Scale | Use When |
|---------|-----------|-------------|-------|----------|
| In-Process Events | Minimal | None | Single JVM | Domain events, Observer pattern, no durability needed |
| Spring Events | Low | None | Single JVM | Decoupled beans, transaction-aware events |
| Spring AMQP (RabbitMQ) | Medium | Broker | Multi-service | Routing, work queues, RPC, reliable delivery |
| JMS / ActiveMQ | Medium | Broker | Multi-service | Jakarta EE standard, legacy integration |
| Apache Kafka | High | Kafka cluster | Multi-service | High-throughput streaming, event sourcing, audit logs |
| Redis Streams | Medium | Redis | Multi-consumer | Lightweight streaming, consumer groups without Kafka overhead |

## 1. In-Process Events

Zero external dependencies. Simple Observer pattern for DDD domain events within a single JVM.

```java
public sealed interface DomainEvent permits ComponentPublished, RatingAdded {
    Instant occurredAt();
}

public record ComponentPublished(UUID componentId, UUID authorId, Instant occurredAt) implements DomainEvent {
    public ComponentPublished(UUID componentId, UUID authorId) {
        this(componentId, authorId, Instant.now());
    }
}

public record RatingAdded(UUID componentId, int score, Instant occurredAt) implements DomainEvent {
    public RatingAdded(UUID componentId, int score) {
        this(componentId, score, Instant.now());
    }
}

public class EventBus {
    private final Map<Class<?>, List<Consumer<? extends DomainEvent>>> handlers = new HashMap<>();

    public <E extends DomainEvent> void subscribe(Class<E> type, Consumer<E> handler) {
        handlers.computeIfAbsent(type, _ -> new CopyOnWriteArrayList<>()).add(handler);
    }

    @SuppressWarnings("unchecked")
    public void publish(DomainEvent event) {
        for (var handler : handlers.getOrDefault(event.getClass(), List.of())) {
            ((Consumer<DomainEvent>) handler).accept(event);
        }
    }
}
```

**Limitations:** Events lost on crash, no retry, single JVM only, synchronous by default.

## 2. Spring Events

Built into Spring Framework. Synchronous by default with async and transactional options.

### Publishing

```java
@Service
public class ComponentService {
    private final ComponentRepository repository;
    private final ApplicationEventPublisher eventPublisher;

    public ComponentService(ComponentRepository repository, ApplicationEventPublisher eventPublisher) {
        this.repository = repository;
        this.eventPublisher = eventPublisher;
    }

    @Transactional
    public Component publish(CreateComponentRequest request) {
        var component = repository.save(Component.from(request));
        eventPublisher.publishEvent(new ComponentPublishedEvent(component.getId(), component.getAuthorId()));
        return component;
    }
}
```

### Consuming — `@EventListener`, `@Async`, `@TransactionalEventListener`

```java
@Component
public class ComponentEventHandlers {

    @EventListener  // Synchronous — same thread and transaction
    public void onComponentPublished(ComponentPublishedEvent event) {
        log.info("Component published: {}", event.componentId());
    }

    @Async @EventListener  // Async — separate thread pool (requires @EnableAsync)
    public void updateSearchIndex(ComponentPublishedEvent event) {
        searchService.index(event.componentId());
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void sendNotification(ComponentPublishedEvent event) {
        notificationService.notifyFollowers(event.authorId());
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_ROLLBACK)
    public void handlePublishFailure(ComponentPublishedEvent event) {
        log.error("Publish failed for component: {}", event.componentId());
    }
}
```

### Enable Async

```java
@Configuration
@EnableAsync
public class AsyncConfig {
    @Bean
    public TaskExecutor applicationEventExecutor() {
        var executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(4);
        executor.setMaxPoolSize(8);
        executor.setQueueCapacity(100);
        executor.setThreadNamePrefix("event-");
        executor.setRejectedExecutionHandler(new CallerRunsPolicy());
        executor.initialize();
        return executor;
    }
}
```

**Limitations:** Single JVM only, async events lost on crash, no replay.

## 3. Spring AMQP (RabbitMQ)

Reliable cross-service messaging with flexible routing. Supports work queues, pub/sub, and RPC.

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-amqp</artifactId>
</dependency>
```

### Configuration — `application.yml`

```yaml
spring:
  rabbitmq:
    host: localhost
    port: 5672
    username: guest
    password: guest
    listener:
      simple:
        acknowledge-mode: manual
        retry:
          enabled: true
          initial-interval: 1000
          max-attempts: 3
          multiplier: 2.0
```

### Exchange, Queue, and Binding Setup

```java
@Configuration
public class RabbitConfig {
    public static final String EXCHANGE = "marketplace.events";
    public static final String COMPONENT_QUEUE = "marketplace.component.indexer";
    public static final String NOTIFICATION_QUEUE = "marketplace.notifications";

    @Bean TopicExchange marketplaceExchange() {
        return new TopicExchange(EXCHANGE, true, false);
    }

    @Bean Queue componentQueue() {
        return QueueBuilder.durable(COMPONENT_QUEUE)
                .withArgument("x-dead-letter-exchange", EXCHANGE + ".dlx")
                .build();
    }

    @Bean Queue notificationQueue() {
        return QueueBuilder.durable(NOTIFICATION_QUEUE).build();
    }

    @Bean Binding componentBinding(Queue componentQueue, TopicExchange marketplaceExchange) {
        return BindingBuilder.bind(componentQueue).to(marketplaceExchange).with("component.#");
    }

    @Bean Binding notificationBinding(Queue notificationQueue, TopicExchange marketplaceExchange) {
        return BindingBuilder.bind(notificationQueue).to(marketplaceExchange).with("notification.#");
    }
}
```

### Producer

```java
@Service
public class RabbitEventPublisher {
    private final RabbitTemplate rabbitTemplate;

    public RabbitEventPublisher(RabbitTemplate rabbitTemplate) {
        this.rabbitTemplate = rabbitTemplate;
    }

    public void publishComponentEvent(UUID componentId, String action) {
        var payload = Map.of("componentId", componentId.toString(), "action", action);
        rabbitTemplate.convertAndSend(RabbitConfig.EXCHANGE, "component." + action, payload);
    }
}
```

### Consumer

```java
@Component
public class ComponentEventConsumer {
    @RabbitListener(queues = RabbitConfig.COMPONENT_QUEUE)
    public void handleComponentEvent(Map<String, String> event) {
        var componentId = UUID.fromString(event.get("componentId"));
        switch (event.get("action")) {
            case "published" -> searchService.index(componentId);
            case "deleted"   -> searchService.remove(componentId);
            case "updated"   -> searchService.reindex(componentId);
        }
    }
}
```

### Docker Compose

```yaml
services:
  rabbitmq:
    image: rabbitmq:4-management
    ports: ["5672:5672", "15672:15672"]
    environment:
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: guest
    volumes: [rabbitmq_data:/var/lib/rabbitmq]
volumes:
  rabbitmq_data:
```

## 4. JMS / ActiveMQ

Standard Jakarta Messaging. Use for Jakarta EE compliance or existing ActiveMQ infrastructure.

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-activemq</artifactId>
</dependency>
```

### Configuration — `application.yml`

```yaml
spring:
  activemq:
    broker-url: tcp://localhost:61616
    user: admin
    password: admin
  jms:
    listener:
      acknowledge-mode: client
      concurrency: 3-10
```

### Producer and Consumer

```java
@Service
public class JmsEventPublisher {
    private final JmsTemplate jmsTemplate;

    public JmsEventPublisher(JmsTemplate jmsTemplate) { this.jmsTemplate = jmsTemplate; }

    public void publishComponentEvent(ComponentPublishedEvent event) {
        jmsTemplate.convertAndSend("marketplace.components", event);
    }
}

@Component
public class JmsComponentConsumer {
    @JmsListener(destination = "marketplace.components", concurrency = "3-5")
    public void handleEvent(ComponentPublishedEvent event,
            @Header(name = "eventType", required = false) String eventType) {
        searchService.index(event.componentId());
    }
}
```

**Note:** Prefer Spring AMQP (RabbitMQ) for new projects. Use JMS only for Jakarta EE compliance or existing ActiveMQ infrastructure.

## 5. Apache Kafka

High-throughput distributed event streaming. Ordered, replayable event logs across multiple services.

```xml
<dependency>
    <groupId>org.springframework.kafka</groupId>
    <artifactId>spring-kafka</artifactId>
</dependency>
```

### Configuration — `application.yml`

```yaml
spring:
  kafka:
    bootstrap-servers: localhost:9092
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer
      acks: all
      retries: 3
    consumer:
      group-id: marketplace-service
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.springframework.kafka.support.serializer.JsonDeserializer
      auto-offset-reset: earliest
      enable-auto-commit: false
      properties:
        spring.json.trusted.packages: "com.example.marketplace.events"
    listener:
      ack-mode: manual
      concurrency: 3
```

### Producer

```java
@Service
public class KafkaEventPublisher {
    private final KafkaTemplate<String, Object> kafkaTemplate;

    public KafkaEventPublisher(KafkaTemplate<String, Object> kafkaTemplate) {
        this.kafkaTemplate = kafkaTemplate;
    }

    public void publishComponentEvent(ComponentPublishedEvent event) {
        kafkaTemplate.send("marketplace.components",
            event.componentId().toString(),  // key — ensures ordering per component
            event
        ).whenComplete((result, ex) -> {
            if (ex != null) log.error("Failed to publish for {}", event.componentId(), ex);
        });
    }
}
```

### Consumer

```java
@Component
public class KafkaComponentConsumer {

    @KafkaListener(topics = "marketplace.components", groupId = "search-indexer")
    public void handleComponentEvent(
            @Payload ComponentPublishedEvent event,
            @Header(KafkaHeaders.RECEIVED_KEY) String key,
            @Header(KafkaHeaders.OFFSET) long offset,
            Acknowledgment ack) {
        try {
            searchService.index(event.componentId());
            ack.acknowledge();
        } catch (Exception e) {
            log.error("Failed to process offset {}: {}", offset, e.getMessage());
            // Don't ack — message will be redelivered
        }
    }

    @KafkaListener(topics = "marketplace.downloads", groupId = "analytics")
    public void handleBatch(List<DownloadEvent> events, Acknowledgment ack) {
        analyticsService.recordBatch(events);
        ack.acknowledge();
    }
}
```

### Topic Design

```
marketplace.components      — component CRUD events (keyed by componentId)
marketplace.ratings          — rating events (keyed by componentId)
marketplace.downloads        — download tracking (keyed by componentId)
marketplace.authors          — author profile events (keyed by authorId)
marketplace.notifications    — email/push notification triggers
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

## 6. Redis Streams

Lightweight persistent streaming with consumer groups. Less operational overhead than Kafka, fits well when Redis is already in the stack.

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-redis</artifactId>
</dependency>
```

### Producer

```java
@Service
public class RedisStreamPublisher {
    private final StringRedisTemplate redisTemplate;

    public RedisStreamPublisher(StringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    public RecordId publish(String stream, Map<String, String> fields) {
        var record = StreamRecords.string(fields).withStreamKey(stream);
        return redisTemplate.opsForStream().add(record);
    }

    public void publishComponentEvent(UUID componentId, String action) {
        publish("marketplace:events", Map.of(
            "eventType", "component." + action,
            "componentId", componentId.toString(),
            "timestamp", Instant.now().toString()
        ));
    }
}
```

### Consumer with Consumer Groups

```java
@Component
public class RedisStreamConsumer implements StreamListener<String, MapRecord<String, String, String>> {
    private final StringRedisTemplate redisTemplate;

    @Override
    public void onMessage(MapRecord<String, String, String> message) {
        var fields = message.getValue();
        switch (fields.get("eventType")) {
            case "component.published" -> searchService.index(UUID.fromString(fields.get("componentId")));
            case "component.deleted"   -> searchService.remove(UUID.fromString(fields.get("componentId")));
        }
        redisTemplate.opsForStream().acknowledge("marketplace:events", "indexer-group", message.getId());
    }
}

@Configuration
public class RedisStreamConfig {
    @Bean
    public Subscription marketplaceStreamSubscription(
            StringRedisTemplate redisTemplate, RedisStreamConsumer consumer) {
        try { redisTemplate.opsForStream().createGroup("marketplace:events", "indexer-group"); }
        catch (Exception e) { /* Group already exists */ }

        var options = StreamMessageListenerContainer.StreamMessageListenerContainerOptions.builder()
                .pollTimeout(Duration.ofSeconds(2)).build();
        var container = StreamMessageListenerContainer.create(redisTemplate.getConnectionFactory(), options);
        var subscription = container.receive(
                Consumer.from("indexer-group", "worker-1"),
                StreamOffset.create("marketplace:events", ReadOffset.lastConsumed()),
                consumer);
        container.start();
        return subscription;
    }
}
```

## Testing Messaging

### Spring Events (unit test)

```java
@SpringBootTest
class ComponentEventTests {
    @Autowired private ApplicationEventPublisher publisher;
    @MockitoBean private SearchService searchService;

    @Test
    void publishedEventTriggersIndexing() {
        var event = new ComponentPublishedEvent(UUID.randomUUID(), UUID.randomUUID());
        publisher.publishEvent(event);
        verify(searchService).index(event.componentId());
    }
}
```

### RabbitMQ (Testcontainers)

```java
@SpringBootTest
@Testcontainers
class RabbitIntegrationTests {
    @Container
    static RabbitMQContainer rabbit = new RabbitMQContainer("rabbitmq:4-management");

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry registry) {
        registry.add("spring.rabbitmq.host", rabbit::getHost);
        registry.add("spring.rabbitmq.port", rabbit::getAmqpPort);
    }

    @Autowired private RabbitEventPublisher publisher;

    @Test
    void componentEventRoundTrip() {
        publisher.publishComponentEvent(UUID.randomUUID(), "published");
        Awaitility.await().atMost(Duration.ofSeconds(5))
                .untilAsserted(() -> verify(searchService).index(any()));
    }
}
```

### Kafka (Testcontainers)

```java
@SpringBootTest
@Testcontainers
class KafkaIntegrationTests {
    @Container
    static KafkaContainer kafka = new KafkaContainer(DockerImageName.parse("confluentinc/cp-kafka:7.6.0"));

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry registry) {
        registry.add("spring.kafka.bootstrap-servers", kafka::getBootstrapServers);
    }

    @Autowired private KafkaEventPublisher publisher;

    @Test
    void componentEventRoundTrip() {
        var event = new ComponentPublishedEvent(UUID.randomUUID(), UUID.randomUUID());
        publisher.publishComponentEvent(event);
        Awaitility.await().atMost(Duration.ofSeconds(10))
                .untilAsserted(() -> verify(searchService).index(event.componentId()));
    }
}
```

### JMS (Embedded ActiveMQ)

```java
@SpringBootTest
@TestPropertySource(properties = "spring.activemq.broker-url=vm://embedded?broker.persistent=false")
class JmsIntegrationTests {
    @Autowired private JmsEventPublisher publisher;

    @Test
    void jmsEventDelivered() {
        var event = new ComponentPublishedEvent(UUID.randomUUID(), UUID.randomUUID());
        publisher.publishComponentEvent(event);
        Awaitility.await().atMost(Duration.ofSeconds(5))
                .untilAsserted(() -> verify(searchService).index(event.componentId()));
    }
}
```

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| Publishing inside `@Transactional` without `@TransactionalEventListener` | Event fires even if transaction rolls back | Use `AFTER_COMMIT` phase |
| Missing dead-letter queue on RabbitMQ | Poison messages block the queue forever | Configure `x-dead-letter-exchange` on every queue |
| Auto-commit enabled in Kafka consumer | Messages lost if consumer crashes mid-processing | Set `enable-auto-commit: false`, ack manually |
| Synchronous `@EventListener` doing I/O | Blocks the publishing thread | Add `@Async` or move to a broker |
| JSON without schema evolution | Consumers break when fields change | Use Avro + Schema Registry, or add explicit versioning |
| Fan-out via multiple `@RabbitListener` on one queue | Only one consumer gets each message | Use fanout/topic exchange with separate queues per consumer |
| Kafka consumer with no idempotency | Duplicate processing on rebalance | Store processed offsets or use idempotency keys |

## Graduated Migration Path

```
Phase 1: Spring Events (in-process)
    +-- Good for: MVP, single-service, < 100 req/s
    +-- Upgrade trigger: need persistence or cross-service delivery

Phase 2: Spring AMQP (RabbitMQ)
    +-- Good for: work queues, routing, reliable delivery, < 10K msg/s
    +-- Upgrade trigger: need event replay, ordering guarantees, high throughput

Phase 3: Apache Kafka
    +-- Good for: event sourcing, audit logs, multi-service, > 10K msg/s
    +-- Enterprise scale, full event streaming

Alternative: Redis Streams
    +-- Good for: lightweight streaming when Redis is already in the stack
    +-- Consumer groups without Kafka operational overhead
    +-- Consider when: < 50K msg/s and Redis is already a dependency
```
