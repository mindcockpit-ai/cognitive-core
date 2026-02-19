---
name: csharp-messaging
description: "Messaging and middleware patterns for C# — Channels, MediatR, RabbitMQ/MassTransit, Azure Service Bus, Kafka, NServiceBus. Graduated complexity from simple to enterprise scale."
user-invocable: false
allowed-tools: Read, Grep, Glob
catalog_description: "Messaging patterns — Channels, MediatR, MassTransit, Azure Service Bus, Kafka."
---

# C# Messaging & Middleware Patterns

Graduated messaging patterns from in-process to enterprise distributed. Pick the right tool for your scale.

## Decision Matrix

| Pattern | Complexity | Persistence | Scale | Use When |
|---------|-----------|-------------|-------|----------|
| System.Threading.Channels | Minimal | None | Single process | In-process producer/consumer, backpressure |
| MediatR | Low | None | Single process | CQRS, domain events, decoupled handlers |
| RabbitMQ (MassTransit) | Medium | Broker | Multi-service | Reliable queuing, routing, work distribution |
| Azure Service Bus | Medium | Cloud | Multi-service | Azure-native, sessions, scheduled delivery |
| Kafka (Confluent) | High | Kafka cluster | Multi-service | High-throughput event streaming, audit logs |
| NServiceBus | High | Broker + DB | Multi-service | Enterprise sagas, long-running workflows |

## 1. System.Threading.Channels

Built into the BCL. Zero NuGet dependencies. Bounded channels provide backpressure; unbounded channels act as fast in-process queues.

```csharp
var channel = Channel.CreateBounded<WorkItem>(new BoundedChannelOptions(100)
{
    FullMode = BoundedChannelFullMode.Wait,
});

// Producer
async Task ProduceAsync(ChannelWriter<WorkItem> writer, CancellationToken ct)
{
    await foreach (var item in GetWorkItemsAsync(ct))
        await writer.WriteAsync(item, ct);
    writer.Complete();
}

// Consumer
async Task ConsumeAsync(ChannelReader<WorkItem> reader, CancellationToken ct)
{
    await foreach (var item in reader.ReadAllAsync(ct))
        await ProcessAsync(item);
}
```

### BackgroundService + Minimal API

```csharp
builder.Services.AddSingleton(Channel.CreateBounded<OrderEvent>(500));
builder.Services.AddHostedService<OrderEventProcessor>();

sealed class OrderEventProcessor(
    Channel<OrderEvent> channel, IServiceScopeFactory scopeFactory,
    ILogger<OrderEventProcessor> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        await foreach (var evt in channel.Reader.ReadAllAsync(ct))
        {
            using var scope = scopeFactory.CreateScope();
            var handler = scope.ServiceProvider.GetRequiredService<IOrderHandler>();
            try { await handler.HandleAsync(evt, ct); }
            catch (Exception ex) { logger.LogError(ex, "Failed {OrderId}", evt.OrderId); }
        }
    }
}

app.MapPost("/orders", async (OrderRequest req, Channel<OrderEvent> channel) =>
{
    var evt = new OrderEvent(Guid.NewGuid(), req.Product, req.Quantity);
    await channel.Writer.WriteAsync(evt);
    return Results.Accepted($"/orders/{evt.OrderId}", evt);
});
```

**Limitations:** Events lost on process restart, no retry, single process only.

## 2. MediatR

In-process mediator for CQRS and domain events. Decouples senders from handlers.

```xml
<PackageReference Include="MediatR" Version="12.*" />
```

### Request/Response

```csharp
public sealed record CreateOrderCommand(string Product, int Quantity) : IRequest<OrderResult>;
public sealed record OrderResult(Guid OrderId, string Status);

public sealed class CreateOrderHandler(AppDbContext db)
    : IRequestHandler<CreateOrderCommand, OrderResult>
{
    public async Task<OrderResult> Handle(CreateOrderCommand cmd, CancellationToken ct)
    {
        var order = new Order { Product = cmd.Product, Quantity = cmd.Quantity };
        db.Orders.Add(order);
        await db.SaveChangesAsync(ct);
        return new OrderResult(order.Id, "Created");
    }
}
```

### Notifications (Domain Events)

```csharp
public sealed record OrderPlaced(Guid OrderId, string Product) : INotification;

// Multiple handlers run for one notification
public sealed class SendConfirmationEmail(IEmailService email)
    : INotificationHandler<OrderPlaced>
{
    public async Task Handle(OrderPlaced n, CancellationToken ct)
        => await email.SendAsync(n.OrderId, "Order confirmed", ct);
}
```

### Pipeline Behaviors + Registration

```csharp
public sealed class LoggingBehavior<TReq, TRes>(ILogger<LoggingBehavior<TReq, TRes>> logger)
    : IPipelineBehavior<TReq, TRes> where TReq : notnull
{
    public async Task<TRes> Handle(
        TReq request, RequestHandlerDelegate<TRes> next, CancellationToken ct)
    {
        logger.LogInformation("Handling {Request}", typeof(TReq).Name);
        var result = await next();
        return result;
    }
}

// Program.cs
builder.Services.AddMediatR(cfg =>
{
    cfg.RegisterServicesFromAssemblyContaining<Program>();
    cfg.AddBehavior(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>));
});

app.MapPost("/orders", async (CreateOrderCommand cmd, IMediator mediator) =>
{
    var result = await mediator.Send(cmd);
    return Results.Created($"/orders/{result.OrderId}", result);
});
```

**Limitations:** Single process, no retry or persistence. Combine with outbox for durability.

## 3. RabbitMQ — MassTransit

MassTransit is the standard abstraction over RabbitMQ in .NET. Use it instead of raw `RabbitMQ.Client`.

```xml
<PackageReference Include="MassTransit.RabbitMQ" Version="8.*" />
```

### Contracts, Consumer, Registration

```csharp
// Shared contracts project
namespace Contracts;
public sealed record OrderSubmitted(Guid OrderId, string Product, int Quantity, DateTime SubmittedAt);
public sealed record OrderProcessed(Guid OrderId, DateTime ProcessedAt);

// Consumer
public sealed class OrderSubmittedConsumer(AppDbContext db) : IConsumer<OrderSubmitted>
{
    public async Task Consume(ConsumeContext<OrderSubmitted> context)
    {
        var msg = context.Message;
        db.Orders.Add(new Order { Id = msg.OrderId, Product = msg.Product, Quantity = msg.Quantity });
        await db.SaveChangesAsync(context.CancellationToken);
        await context.Publish(new OrderProcessed(msg.OrderId, DateTime.UtcNow));
    }
}

// Program.cs
builder.Services.AddMassTransit(x =>
{
    x.AddConsumer<OrderSubmittedConsumer>();
    x.UsingRabbitMq((ctx, cfg) =>
    {
        cfg.Host("localhost", "/", h => { h.Username("guest"); h.Password("guest"); });
        cfg.UseMessageRetry(r => r.Intervals(
            TimeSpan.FromSeconds(1), TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(15)));
        cfg.ConfigureEndpoints(ctx);
    });
});

app.MapPost("/orders", async (OrderRequest req, IPublishEndpoint bus) =>
{
    await bus.Publish(new OrderSubmitted(Guid.NewGuid(), req.Product, req.Quantity, DateTime.UtcNow));
    return Results.Accepted();
});
```

### Docker Compose

```yaml
services:
  rabbitmq:
    image: rabbitmq:3-management
    ports: ["5672:5672", "15672:15672"]
    environment: { RABBITMQ_DEFAULT_USER: guest, RABBITMQ_DEFAULT_PASS: guest }
    volumes: [rabbitmq_data:/var/lib/rabbitmq]
volumes:
  rabbitmq_data:
```

## 4. Azure Service Bus

Managed cloud broker with sessions, dead-letter queues, and scheduled delivery.

```xml
<PackageReference Include="Azure.Messaging.ServiceBus" Version="7.*" />
```

### Send + Receive

```csharp
// Program.cs — register singleton client
builder.Services.AddSingleton(
    new ServiceBusClient(builder.Configuration["AzureServiceBus:ConnectionString"]));

// Send
app.MapPost("/orders", async (OrderRequest req, ServiceBusClient client) =>
{
    await using var sender = client.CreateSender("orders");
    var message = new ServiceBusMessage(JsonSerializer.Serialize(
        new OrderSubmitted(Guid.NewGuid(), req.Product, req.Quantity, DateTime.UtcNow)))
    {
        ContentType = "application/json",
        Subject = "OrderSubmitted",
        SessionId = req.CustomerId,  // Session affinity
    };
    await sender.SendMessageAsync(message);
    return Results.Accepted();
});

// Receive — hosted service
sealed class OrderProcessor(
    ServiceBusClient client, ILogger<OrderProcessor> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        var processor = client.CreateProcessor("orders",
            new ServiceBusProcessorOptions { AutoCompleteMessages = false, MaxConcurrentCalls = 10 });
        processor.ProcessMessageAsync += async args =>
        {
            var order = JsonSerializer.Deserialize<OrderSubmitted>(args.Message.Body);
            logger.LogInformation("Processing {OrderId}", order!.OrderId);
            await args.CompleteMessageAsync(args.Message, ct);
        };
        processor.ProcessErrorAsync += args =>
        { logger.LogError(args.Exception, "Error on {Entity}", args.EntityPath); return Task.CompletedTask; };
        await processor.StartProcessingAsync(ct);
        await Task.Delay(Timeout.Infinite, ct);
    }
}
```

### MassTransit Transport Swap

Same consumer code, different transport -- swap `UsingRabbitMq` for `UsingAzureServiceBus`:

```csharp
builder.Services.AddMassTransit(x =>
{
    x.AddConsumer<OrderSubmittedConsumer>();
    x.UsingAzureServiceBus((ctx, cfg) =>
    {
        cfg.Host(builder.Configuration["AzureServiceBus:ConnectionString"]);
        cfg.ConfigureEndpoints(ctx);
    });
});
```

```xml
<PackageReference Include="MassTransit.Azure.ServiceBus.Core" Version="8.*" />
```

## 5. Kafka — Confluent.Kafka

High-throughput ordered event streaming with log-style persistence and replay.

```xml
<PackageReference Include="Confluent.Kafka" Version="2.*" />
```

### Producer + Consumer

```csharp
// Producer — register as singleton, dispose on shutdown
sealed class KafkaProducer(string bootstrapServers) : IAsyncDisposable
{
    private readonly IProducer<string, string> _producer =
        new ProducerBuilder<string, string>(new ProducerConfig
        {
            BootstrapServers = bootstrapServers, Acks = Acks.All, EnableIdempotence = true,
        }).Build();

    public async Task PublishAsync<T>(string topic, string key, T message) =>
        await _producer.ProduceAsync(topic, new Message<string, string>
            { Key = key, Value = JsonSerializer.Serialize(message) });

    public ValueTask DisposeAsync() { _producer.Dispose(); return ValueTask.CompletedTask; }
}

// Consumer — BackgroundService
sealed class KafkaConsumerWorker(
    IConfiguration config, ILogger<KafkaConsumerWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        using var consumer = new ConsumerBuilder<string, string>(new ConsumerConfig
        {
            BootstrapServers = config["Kafka:BootstrapServers"],
            GroupId = "order-processor",
            AutoOffsetReset = AutoOffsetReset.Earliest,
            EnableAutoCommit = false,
        }).Build();

        consumer.Subscribe(["orders.submitted", "orders.cancelled"]);
        while (!ct.IsCancellationRequested)
        {
            var result = consumer.Consume(ct);
            try
            {
                var order = JsonSerializer.Deserialize<OrderSubmitted>(result.Message.Value);
                logger.LogInformation("Processing {OrderId}", order!.OrderId);
                consumer.Commit(result);
            }
            catch (Exception ex) { logger.LogError(ex, "Offset {Offset}", result.Offset); }
        }
    }
}
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
volumes:
  kafka_data:
```

## 6. NServiceBus

Enterprise service bus with sagas, automatic retries, outbox, and strict ordering. Best for long-running business processes.

```xml
<PackageReference Include="NServiceBus" Version="9.*" />
<PackageReference Include="NServiceBus.Extensions.Hosting" Version="3.*" />
<PackageReference Include="NServiceBus.Transport.RabbitMQ" Version="9.*" />
```

### Endpoint Configuration

```csharp
builder.Host.UseNServiceBus(ctx =>
{
    var transport = new RabbitMQTransport(
        RoutingTopology.Conventional(QueueType.Quorum), "host=localhost");
    var config = new EndpointConfiguration("OrderService");
    config.UseTransport(transport);
    config.EnableInstallers();
    var recovery = config.Recoverability();
    recovery.Immediate(i => i.NumberOfRetries(2));
    recovery.Delayed(d => d.NumberOfRetries(3).TimeIncrease(TimeSpan.FromSeconds(10)));
    config.EnableOutbox();
    return config;
});
```

### Saga (Long-Running Workflow)

```csharp
// Messages
public sealed record StartOrderProcess(Guid OrderId, string Product) : ICommand;
public sealed record PaymentReceived(Guid OrderId) : IEvent;
public sealed record OrderShipped(Guid OrderId) : IEvent;
public sealed record OrderCompleted(Guid OrderId) : IEvent;
public sealed record OrderCancelled(Guid OrderId, string Reason) : IEvent;
public sealed record OrderTimeout;

// Saga state
public sealed class OrderSagaData : ContainSagaData
{
    public Guid OrderId { get; set; }
    public bool PaymentCompleted { get; set; }
    public bool Shipped { get; set; }
}

// Saga — coordinates payment + shipping, times out after 24h
public sealed class OrderSaga : Saga<OrderSagaData>,
    IAmStartedBy<StartOrderProcess>, IHandleMessages<PaymentReceived>,
    IHandleMessages<OrderShipped>, IHandleTimeouts<OrderTimeout>
{
    protected override void ConfigureHowToFindSaga(SagaPropertyMapper<OrderSagaData> mapper)
        => mapper.MapSaga(s => s.OrderId)
            .ToMessage<StartOrderProcess>(m => m.OrderId)
            .ToMessage<PaymentReceived>(m => m.OrderId)
            .ToMessage<OrderShipped>(m => m.OrderId);

    public async Task Handle(StartOrderProcess msg, IMessageHandlerContext ctx)
    {
        Data.OrderId = msg.OrderId;
        await RequestTimeout<OrderTimeout>(ctx, TimeSpan.FromHours(24));
    }

    public Task Handle(PaymentReceived msg, IMessageHandlerContext ctx)
    { Data.PaymentCompleted = true; return TryComplete(ctx); }

    public Task Handle(OrderShipped msg, IMessageHandlerContext ctx)
    { Data.Shipped = true; return TryComplete(ctx); }

    public Task Timeout(OrderTimeout state, IMessageHandlerContext ctx)
    { MarkAsComplete(); return ctx.Publish(new OrderCancelled(Data.OrderId, "Timed out")); }

    private Task TryComplete(IMessageHandlerContext ctx)
    {
        if (!Data.PaymentCompleted || !Data.Shipped) return Task.CompletedTask;
        MarkAsComplete();
        return ctx.Publish(new OrderCompleted(Data.OrderId));
    }
}
```

### Sending from Minimal API

```csharp
app.MapPost("/orders", async (OrderRequest req, IMessageSession session) =>
{
    var orderId = Guid.NewGuid();
    await session.Send(new StartOrderProcess(orderId, req.Product));
    return Results.Accepted($"/orders/{orderId}", new { orderId });
});
```

## Testing Patterns

### Channels + MediatR (unit test handler directly)

```csharp
[Fact]
public async Task Channel_delivers_in_order()
{
    var channel = Channel.CreateUnbounded<int>();
    await channel.Writer.WriteAsync(1);
    await channel.Writer.WriteAsync(2);
    channel.Writer.Complete();
    var results = new List<int>();
    await foreach (var item in channel.Reader.ReadAllAsync()) results.Add(item);
    Assert.Equal([1, 2], results);
}

[Fact]
public async Task CreateOrderCommand_persists_order()
{
    var db = new AppDbContext(CreateInMemoryOptions());
    var handler = new CreateOrderHandler(db);
    var result = await handler.Handle(new CreateOrderCommand("Widget", 5), CancellationToken.None);
    Assert.Equal("Created", result.Status);
    Assert.Single(db.Orders);
}
```

### MassTransit (built-in test harness)

```csharp
[Fact]
public async Task Consumer_publishes_processed_event()
{
    await using var provider = new ServiceCollection()
        .AddDbContext<AppDbContext>(o => o.UseInMemoryDatabase("test"))
        .AddMassTransitTestHarness(x => x.AddConsumer<OrderSubmittedConsumer>())
        .BuildServiceProvider(true);

    var harness = provider.GetRequiredService<ITestHarness>();
    await harness.Start();
    await harness.Bus.Publish(new OrderSubmitted(Guid.NewGuid(), "Widget", 3, DateTime.UtcNow));
    Assert.True(await harness.Consumed.Any<OrderSubmitted>());
    Assert.True(await harness.Published.Any<OrderProcessed>());
}
```

### NServiceBus (TestableSaga)

```csharp
[Fact]
public async Task Saga_completes_on_payment_and_shipping()
{
    var saga = new TestableSaga<OrderSaga, OrderSagaData>();
    var id = Guid.NewGuid();
    await saga.Handle(new StartOrderProcess(id, "Widget"));
    await saga.Handle(new PaymentReceived(id));
    var ship = await saga.Handle(new OrderShipped(id));
    Assert.True(saga.Completed);
    Assert.Contains(ship.PublishedMessages, m => m.Message is OrderCompleted);
}
```

## Graduated Migration Path

```
Phase 1: Channels + MediatR → MVP, single service, < 500 req/s
    Upgrade trigger: need cross-service messaging or durability

Phase 2: MassTransit + RabbitMQ → multi-service, < 10K msg/s
    Upgrade trigger: need cloud-managed broker or high throughput

Phase 3: Azure Service Bus / Kafka → cloud-managed or streaming
    Upgrade trigger: need long-running sagas, strict ordering

Phase 4: NServiceBus → enterprise sagas, outbox, exactly-once
    Licensed product — evaluate ROI vs building your own
```

## Anti-Patterns

**Synchronous over async.** Never call `.Result` or `.Wait()` on messaging operations. Causes thread pool starvation. Always `await`.

**Fat messages.** Send identifiers, not entire entities. Let consumers fetch current state. Large payloads increase broker memory pressure and break on schema changes.

**Missing idempotency.** Brokers deliver at-least-once. Every consumer must handle duplicates via `MessageId` deduplication or idempotent DB operations.

**No dead-letter handling.** Poison messages must go somewhere. Configure dead-letter queues (RabbitMQ, Azure Service Bus) or dead-letter topics (Kafka). Monitor them.

**Tight coupling to transport.** Use MassTransit or NServiceBus as abstraction. Keep transport config in one place; reference the abstraction everywhere else.

**Ignoring backpressure.** Unbounded queues grow until OOM. Use bounded channels, prefetch limits, and concurrency settings. Monitor queue depth.

**Skipping the outbox.** Publishing after DB save is not atomic. Use transactional outbox (MassTransit and NServiceBus have built-in support) for data/event consistency.
