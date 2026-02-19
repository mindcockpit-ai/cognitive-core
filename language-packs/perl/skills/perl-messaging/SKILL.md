---
name: perl-messaging
description: "Messaging and middleware patterns for Perl — event loops, Minion, TheSchwartz, RabbitMQ, Redis pub/sub, Kafka. Graduated complexity from simple to enterprise scale."
user-invocable: false
allowed-tools: Read, Grep, Glob
catalog_description: "Messaging patterns — event loops, Minion, TheSchwartz, RabbitMQ, Redis, Kafka."
---

# Perl Messaging & Middleware Patterns

Graduated messaging patterns from in-process event loops to distributed streaming.

## Decision Matrix

| Pattern | Complexity | Persistence | Scale | Use When |
|---------|-----------|-------------|-------|----------|
| AnyEvent / IO::Async | Minimal | None | Single process | Timers, watchers, non-blocking I/O |
| Minion (Mojolicious) | Low | PostgreSQL/SQLite | Single service | Background jobs, retries, cron |
| TheSchwartz | Low | MySQL/PostgreSQL | Multi-worker | Reliable job queue, non-Mojo stacks |
| Net::AMQP::RabbitMQ | Medium | RabbitMQ broker | Multi-service | Routed messaging, fanout, topic exchange |
| Mojo::Redis | Medium | Redis | Multi-consumer | Real-time pub/sub, Streams |
| Net::Kafka | High | Kafka cluster | Multi-service | High-throughput streaming, audit logs |

## CPAN Modules

```bash
cpanm AnyEvent IO::Async             # Event loops
cpanm Minion Minion::Backend::Pg     # Mojo job queue (+ Pg backend)
cpanm TheSchwartz                    # Generic job queue
cpanm Net::AMQP::RabbitMQ            # RabbitMQ (XS)
cpanm Mojo::Redis                    # Async Redis for Mojo
cpanm Net::Kafka                     # Kafka (requires librdkafka)
```

## 1. Event Loop -- AnyEvent / IO::Async

Zero infrastructure. In-process event-driven patterns.

### AnyEvent -- Timer + I/O Watcher

```perl
use v5.38;
use warnings;
use AnyEvent;

my $cv = AnyEvent->condvar;
my $timer = AnyEvent->timer(after => 0, interval => 60,
    cb => sub { process_pending_jobs() });
my $watcher = AnyEvent->io(fh => $socket, poll => 'r',
    cb => sub { handle_incoming_message($socket) });
$cv->recv;
```

### IO::Async -- Worker Pool

```perl
use v5.38;
use warnings;
use IO::Async::Loop;
use IO::Async::Function;

my $loop = IO::Async::Loop->new;
my $worker = IO::Async::Function->new(
    code => sub ($payload) { process_heavy_task($payload) },
    max_workers => 4,
);
$loop->add($worker);
$worker->call(args => [$payload])->then(sub ($r) { say "Done: $r" })->get;
$loop->run;
```

### In-Process Event Bus

```perl
use v5.38;
use warnings;
package MyApp::EventBus {
    use Moo;
    has _handlers => (is => 'ro', default => sub { {} });

    sub subscribe ($self, $event_type, $handler) {
        push $self->_handlers->{$event_type}->@*, $handler;
    }
    sub publish ($self, $event_type, $payload) {
        $_->($payload) for ($self->_handlers->{$event_type} // [])->@*;
    }
}

my $bus = MyApp::EventBus->new;
$bus->subscribe('component.published' => sub ($d) {
    update_search_index($d->{component_id});
});
$bus->publish('component.published', { component_id => 42 });
```

**Limitations:** Events lost on crash, no retry, single process only.

## 2. Minion -- Mojolicious Job Queue

PostgreSQL/SQLite backend, automatic retries, admin UI, job dependencies.

### Setup, Tasks, and Enqueue

```perl
# lib/MyApp.pm
use v5.38;
use warnings;
package MyApp {
    use Mojo::Base 'Mojolicious', -signatures;
    sub startup ($self) {
        $self->plugin(Minion => {Pg => 'postgresql://user:pass@localhost/myapp'});
        $self->minion->add_task(process_upload => sub ($job, $component_id) {
            $job->finish({status => 'ok', indexed => validate_and_index($component_id)});
        });
        $self->minion->add_task(send_notification => sub ($job, $user_id, $msg) {
            send_email(load_user($user_id)->{email}, $msg);
        });
    }
}

# Enqueue with priority and retry (in controller/service)
$self->minion->enqueue(process_upload => [$id], {
    priority => 5, attempts => 3, queue => 'default',
});
```

### Worker CLI

```bash
./script/my_app minion worker -j 4      # 4 concurrent jobs
./script/my_app minion job -S            # Stats
```

**Why Minion:** Native Mojo integration, admin UI, PostgreSQL reliability, zero-config SQLite for dev.

## 3. TheSchwartz -- Reliable Job Queue

Battle-tested (Six Apart/LiveJournal heritage). Good for non-Mojolicious stacks.

### Client, Worker, and Runner

```perl
use v5.38;
use warnings;
use TheSchwartz;

# Enqueue
my $client = TheSchwartz->new(databases => [{
    dsn => 'dbi:Pg:dbname=myapp', user => 'worker', pass => $ENV{DB_PASS},
}]);
$client->insert('MyApp::Worker::ProcessUpload', { component_id => 42 });

# Worker definition
package MyApp::Worker::ProcessUpload {
    use base 'TheSchwartz::Worker';
    sub work ($class, $job) {
        eval { validate_and_index($job->arg->{component_id}); $job->completed };
        $job->failed("Failed: $@") if $@;
    }
    sub max_retries { 3 }
    sub retry_delay { 60 }
    sub grab_for    { 300 }
}

# Runner (script/worker.pl)
$client->can_do('MyApp::Worker::ProcessUpload');
$client->work_until_done while 1;
```

**Pick TheSchwartz over Minion:** Non-Mojo stack, existing MySQL infra, simpler deployment.

## 4. Net::RabbitMQ -- AMQP Messaging

Topic-based routing, fanout, guaranteed delivery across services.

### Producer

```perl
use v5.38;
use warnings;
use Net::AMQP::RabbitMQ;
use JSON::XS qw(encode_json);

my $mq = Net::AMQP::RabbitMQ->new;
$mq->connect('localhost', { user => 'guest', password => 'guest' });
$mq->channel_open(1);
$mq->exchange_declare(1, 'marketplace', { exchange_type => 'topic', durable => 1 });
$mq->publish(1, 'component.published', encode_json({ component_id => 42 }),
    { exchange => 'marketplace' },
    { content_type => 'application/json', delivery_mode => 2 },
);
```

### Consumer with Ack/Nack

```perl
use v5.38;
use warnings;
use Net::AMQP::RabbitMQ;
use JSON::XS qw(decode_json);
use Try::Tiny;

sub consume_events ($queue, $handler) {
    my $mq = Net::AMQP::RabbitMQ->new;
    $mq->connect('localhost', { user => 'guest', password => 'guest' });
    $mq->channel_open(1);
    $mq->exchange_declare(1, 'marketplace', { exchange_type => 'topic', durable => 1 });
    $mq->queue_declare(1, $queue, { durable => 1 });
    $mq->queue_bind(1, $queue, 'marketplace', 'component.*');
    $mq->consume(1, $queue, { no_ack => 0 });
    while (1) {
        my $msg = $mq->recv(5000) or next;
        try {
            $handler->($msg->{routing_key}, decode_json($msg->{body}));
            $mq->ack(1, $msg->{delivery_tag});
        } catch {
            $mq->nack(1, $msg->{delivery_tag}, { requeue => 1 });
        };
    }
}
```

### Docker Compose -- RabbitMQ

```yaml
services:
  rabbitmq:
    image: rabbitmq:3.13-management
    ports: ["5672:5672", "15672:15672"]
    environment: { RABBITMQ_DEFAULT_USER: guest, RABBITMQ_DEFAULT_PASS: guest }
    volumes: [rabbitmq_data:/var/lib/rabbitmq]
volumes:
  rabbitmq_data:
```

## 5. Redis Pub/Sub and Streams (Mojo::Redis)

Ephemeral pub/sub for real-time, Streams for persistent consumer groups.

### Pub/Sub

```perl
use v5.38;
use warnings;
use Mojo::Redis;

my $redis = Mojo::Redis->new('redis://localhost:6379');
$redis->pubsub->notify('component:events' => encode_json($payload));  # publish
$redis->pubsub->listen('component:*' => sub ($pubsub, $msg, $ch) {   # subscribe
    handle_event(decode_json($msg));
});
Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
```

### Redis Streams -- Consumer Groups

```perl
use v5.38;
use warnings;
use Mojo::Redis;
use JSON::XS qw(encode_json decode_json);

my $db = Mojo::Redis->new('redis://localhost:6379')->db;

# Producer
$db->xadd_p('events', '*', event_type => 'component.published',
    payload => encode_json({ component_id => 42 }))->wait;

# Consumer group setup + consumer loop
$db->xgroup_p('CREATE', 'events', 'indexer-group', '0', 'MKSTREAM')
    ->catch(sub {})->wait;

Mojo::IOLoop->recurring(1 => sub {
    $db->xreadgroup_p('GROUP', 'indexer-group', 'worker-1',
        'COUNT', 10, 'BLOCK', 2000, 'STREAMS', 'events', '>',
    )->then(sub ($result) {
        return unless $result && $result->[0];
        for my $entry ($result->[0][1]->@*) {
            my ($id, $fields) = @$entry;
            my %d = @$fields;
            handle_event($d{event_type}, decode_json($d{payload}));
            $db->xack_p('events', 'indexer-group', $id);
        }
    })->catch(sub ($err) { warn "Stream error: $err" })->wait;
});
Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
```

**Streams over pub/sub:** When you need persistence, replay, or independent consumer groups.

## 6. Kafka (Net::Kafka)

High-throughput distributed streaming. Requires `librdkafka` (`brew install librdkafka` on macOS).

### Producer

```perl
use v5.38;
use warnings;
use Net::Kafka::Producer;
use JSON::XS qw(encode_json);

my $producer = Net::Kafka::Producer->new(
    'metadata.broker.list' => 'localhost:9092',
    'queue.buffering.max.ms' => 100,
);
$producer->produce(
    topic => 'marketplace.components', key => "component-42",
    payload => encode_json({ event_type => 'published', component_id => 42 }),
);
$producer->flush(5000);
```

### Consumer

```perl
use v5.38;
use warnings;
use Net::Kafka::Consumer;
use JSON::XS qw(decode_json);
use Try::Tiny;

my $consumer = Net::Kafka::Consumer->new(
    'metadata.broker.list' => 'localhost:9092',
    'group.id'             => 'search-indexer',
    'auto.offset.reset'    => 'earliest',
    'enable.auto.commit'   => 'false',
);
$consumer->subscribe(['marketplace.components', 'marketplace.ratings']);
while (1) {
    my $msg = $consumer->poll(1000) or next;
    next if $msg->err;
    try {
        handle_event($msg->topic, decode_json($msg->payload));
        $consumer->commit_message($msg);
    } catch { warn "Processing failed: $_" };
}
```

### Docker Compose -- Kafka (KRaft, no Zookeeper)

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

## Testing Patterns (Test2::Suite)

### Unit -- EventBus

```perl
use v5.38;
use warnings;
use Test2::V0;
use MyApp::EventBus;

subtest 'dispatches to subscribers' => sub {
    my $bus = MyApp::EventBus->new;
    my @received;
    $bus->subscribe('component.published' => sub ($d) { push @received, $d });
    $bus->publish('component.published', { component_id => 42 });
    is scalar @received, 1, 'handler called';
    is $received[0]->{component_id}, 42, 'payload correct';
};
done_testing;
```

### Unit -- Minion Tasks

```perl
use v5.38;
use warnings;
use Test2::V0;
use Test::Mojo;
use MyApp;

my $minion = Test::Mojo->new('MyApp')->app->minion;
$minion->enqueue(process_upload => [42]);
my $worker = $minion->worker->register;
my $job = $worker->dequeue(5);
ok $job, 'job dequeued';
$job->perform;
is $job->info->{state}, 'finished', 'job finished';
$worker->unregister;
done_testing;
```

### Integration -- RabbitMQ (env-gated)

```perl
use v5.38;
use warnings;
use Test2::V0;
use Net::AMQP::RabbitMQ;
use JSON::XS qw(encode_json decode_json);
skip_all 'Set RABBITMQ_HOST for integration tests' unless $ENV{RABBITMQ_HOST};

my $mq = Net::AMQP::RabbitMQ->new;
$mq->connect($ENV{RABBITMQ_HOST}, { user => 'guest', password => 'guest' });
$mq->channel_open(1);
my $q = "test-queue-$$";
$mq->queue_declare(1, $q, { auto_delete => 1 });
$mq->publish(1, $q, encode_json({ action => 'test', id => 1 }));
$mq->consume(1, $q, { no_ack => 1 });
ok $mq->recv(3000), 'roundtrip message received';
$mq->disconnect;
done_testing;
```

## Graduated Migration Path

| Phase | Modules | Scale | Upgrade Trigger |
|-------|---------|-------|-----------------|
| 1. In-process | AnyEvent / IO::Async | <100 req/s | Need persistence or retry |
| 2. DB queue | Minion / TheSchwartz | <1K jobs/s | Need cross-service messaging |
| 3. Broker | Net::AMQP::RabbitMQ / Mojo::Redis | <10K msg/s | Need high throughput, replay |
| 4. Streaming | Net::Kafka | >10K msg/s | Enterprise event streaming |

## Anti-Patterns

### Blocking the Event Loop

```perl
# WRONG -- blocks everything
AnyEvent->timer(after => 0, cb => sub {
    $dbh->selectall_arrayref($slow_query);  # Blocks!
});
# RIGHT -- offload to worker
IO::Async::Function->new(code => sub { $dbh->selectall_arrayref($slow_query) });
```

### Ack Before Processing

```perl
# WRONG -- message lost if processing fails
$mq->ack(1, $msg->{delivery_tag});
process($msg);
# RIGHT
try { process($msg); $mq->ack(1, $msg->{delivery_tag}) }
catch { $mq->nack(1, $msg->{delivery_tag}, { requeue => 0 }) };
```

### Unbounded Job Queues

```perl
# WRONG -- millions enqueued, no backpressure
$minion->enqueue(process_item => [$_]) for @huge_list;
# RIGHT -- batch and throttle
while (my @batch = splice @huge_list, 0, 100) {
    $minion->enqueue(process_batch => [\@batch]);
    sleep 1 if $minion->stats->{inactive_jobs} > 10_000;
}
```

### Missing Idempotency

```perl
# WRONG -- duplicates on retry
sub handle_upload ($id) { insert_into_index($id) }
# RIGHT -- upsert is safe on retry
sub handle_upload ($id) { upsert_index($id) }
```

### No Schema Validation

```perl
# WRONG -- silent undef on schema drift
process(decode_json($msg->payload)->{component_id});
# RIGHT -- validate with Type::Tiny
use Types::Standard qw(Dict Int Str);
Dict[component_id => Int, event_type => Str]->assert_valid(decode_json($msg->payload));
```

### Kafka Auto-Commit

```perl
# WRONG -- auto-commit loses messages on crash
Net::Kafka::Consumer->new('enable.auto.commit' => 'true');
# RIGHT -- manual commit after successful processing
Net::Kafka::Consumer->new('enable.auto.commit' => 'false');
$consumer->commit_message($msg);  # after handler succeeds
```
