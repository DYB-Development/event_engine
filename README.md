# EventEngine

EventEngine is the schema-first **core** of the event pipeline:
- **Event definitions** in a Ruby DSL.
- **Schema generation** to a canonical `db/event_schema.rb`.
- **Generated helpers** that build a validated `Event` and **dispatch** it to
  registered handlers by level.

Durable delivery — the outbox, transports, dead-letter handling, and the
observability dashboard — lives in the companion gem
[`event_engine-delivery`](https://github.com/tylercschneider/event_engine-delivery),
which registers its pipeline as a handler. Add it when you need durable delivery.

This README is optimized for humans and automated assistants. Some sections below
still describe delivery behavior that now lives in `event_engine-delivery`; a fuller
split of this document is in progress.

---

## Quick start (new Rails app)

1. **Add the gem** to your application:

   ```ruby
   # Gemfile
   gem "event_engine"
   ```

2. **Bundle install**:

   ```bash
   bundle install
   ```

3. **Run migrations** to create the outbox table:

   ```bash
   bin/rails db:migrate
   ```

4. **Define events** with the DSL (examples below).

5. **Generate the schema file**:

   ```bash
   bin/rails event_engine:schema:dump
   ```

6. **Commit `db/event_schema.rb`** (required in production).

7. **Configure the transport and delivery adapter** (see Configuration).

---

## Core concepts

### 1) Event Definitions → Schema
Event definitions describe:
- event name/type
- input objects
- payload fields and type casting

These definitions are compiled into a canonical schema file (`db/event_schema.rb`).
The schema file is authoritative in production.

### 2) Event Emission
At boot, EventEngine loads the schema file and installs helper methods for
each event. Example: if you define `event_name :cow_fed`, then
`EventEngine.cow_fed(...)` becomes available.

### 3) Outbox + Publisher
Events are written to `event_engine_outbox_events`. A publisher reads
unpublished events and sends them through the configured transport.

---

## Defining events

Create event definitions (typically in `app/events` or `app/event_definitions`).

```ruby
class CowFed < EventEngine::EventDefinition
  input :cow
  optional_input :farmer

  event_name :cow_fed
  event_type :domain

  entity_class :class_name, from: :cow, type: :string
  entity_id :id, from: :cow, type: :int
  entity_version :version, from: :cow, type: :int

  required_payload :weight, from: :cow, type: :float
  optional_payload :name, from: :farmer, type: :string
end
```

> Tip: ensure your definition classes are eager loaded in Rails.

---

## Generating the schema

Generate the schema after adding or modifying definitions:

```bash
bin/rails event_engine:schema:dump
```

This creates/updates `db/event_schema.rb`. Commit it to source control.

---

## Emitting events

Once the schema is loaded (boot time), helpers are installed:

```ruby
EventEngine.cow_fed(
  cow: cow,
  farmer: farmer,
  occurred_at: Time.current,
  metadata: { request_id: "abc123" }
)
```

You can optionally set:
- `event_version:` (to force a specific schema version)
- `occurred_at:`
- `metadata:`

---

## Per-event levels

Each event can declare an `event_level` (1–5) describing where it sits on the
event-system maturity ladder. The level decides how the event is delivered —
**producer code never changes**, so moving an event up a level is a one-line
edit to its definition.

```ruby
class AppStarted < EventEngine::EventDefinition
  event_name :app_started
  event_type :system
  event_level 1
end
```

| Level | Outbox? | What happens | You configure |
|---|---|---|---|
| **1** | No | subscribers run synchronously, in the caller's stack | nothing |
| **2** | No | subscribers run in a background job (ActiveJob) | a job backend |
| **3** | Yes | subscribers run when the outbox is drained (durable) | the outbox migration |
| **4** | Yes | the event is published to a broker transport (e.g. Kafka) | the outbox migration + a transport |
| **5** | — | not supported (event sourcing) — raises | — |

Levels 1–3 invoke in-process **subscribers** with increasing durability. Level 4
leaves the process to a broker, where consumers are separate services. Events
with no `event_level` keep the original behavior: written to the outbox and
published to the configured transport.

> Only levels 3+ use the outbox, so an app using only levels 1–2 does not need
> the outbox migration.

### Subscribers

A subscriber is a class that reacts to an event in-process (levels 1–3). Declare
the event it handles with `subscribes_to`; it self-registers at load time.

```ruby
class SendWelcomeEmail < EventEngine::Subscriber
  subscribes_to :user_registered

  def handle(event)
    # event is an EventEngine::Event with a symbol-keyed payload at every level
    UserMailer.welcome(event.payload[:user_id]).deliver_later
  end
end
```

The same subscriber works at any in-process level — upgrading `event_level` from
1 to 3 does not touch this code. Subscribers should be idempotent (they may be
re-invoked on retries at level 3+).

### Level 4 transport

A level-4 event needs a transport configured (see [Configuration](#configuration)).
If one is missing, EventEngine logs a warning at boot and raises
`EventEngine::OutboxRouter::MissingTransportError` when the event is actually
published — so a misconfiguration surfaces loudly rather than silently dropping
events. The default `NullTransport` counts as "no transport" for this check.

---

## Configuration

Add an initializer such as `config/initializers/event_engine.rb`:

```ruby
EventEngine.configure do |config|
  config.delivery_adapter = :inline # or :active_job

  # For development/testing:
  config.transport = EventEngine::Transports::InMemoryTransport.new

  # For Kafka (example):
  # client = Kafka.new(seed_brokers: ["kafka://localhost:9092"])
  # producer = EventEngine::KafkaProducer.new(client: client)
  # config.transport = EventEngine::Transports::Kafka.new(producer: producer)

  config.batch_size = 100
  config.max_attempts = 5
end
```

### Delivery modes
- `:inline` (default): publish immediately after writing to outbox.
- `:active_job`: enqueue `EventEngine::PublishOutboxEventsJob`.
- `:manual`: do not deliver automatically. The outbox is drained only by an
  explicit `OutboxPublisher` call — e.g. a scheduled job, a rake task, or an
  operator action. Useful when you want full control over when events are
  published.

---

## Outbox publishing

If you use `:active_job`, ensure your background job infrastructure is running.
Publishing also requires `config.transport` to be set; otherwise the job will
raise an error.

---

## Transport interface

A transport is any object that responds to `publish(event)`. EventEngine ships
with two transports:

- `EventEngine::Transports::InMemoryTransport` — stores events in memory (dev/test)
- `EventEngine::Transports::Kafka` — publishes to Kafka via an injected producer

### Writing a custom transport

```ruby
class MyTransport
  def publish(event)
    # event is an EventEngine::OutboxEvent with these attributes:
    #   event.event_name      # e.g. "cow.fed"
    #   event.event_type      # e.g. "domain"
    #   event.event_version   # e.g. 1
    #   event.idempotency_key # unique key for deduplication (may be nil)
    #   event.payload         # Hash of event data
    #   event.metadata        # Hash of contextual data (request_id, etc.)
    #   event.occurred_at     # Time the event occurred

    # Publish to your messaging system here
    # Raise an exception on failure (will be retried up to max_attempts)
  end
end
```

Configure your transport in the initializer:

```ruby
EventEngine.configure do |config|
  config.transport = MyTransport.new
end
```

### Kafka transport

EventEngine does **not** manage Kafka — you bring your own client. The Kafka
transport wraps your producer:

```ruby
# Using the ruby-kafka gem as an example
kafka_client = Kafka.new(seed_brokers: ENV["KAFKA_BROKERS"])
producer = EventEngine::KafkaProducer.new(client: kafka_client)

EventEngine.configure do |config|
  config.transport = EventEngine::Transports::Kafka.new(producer: producer)
end
```

The Kafka transport publishes to topics named `events.{event_name}` with a JSON
payload containing all event attributes. Customize topic naming or partition
keys in your producer implementation.

---

## Idempotency

Every outbox event is assigned an `idempotency_key` — a UUID generated
automatically when the event is emitted. This key is stored in the outbox table
(with a unique constraint) and passed through to transports for downstream
consumers.

### How it works

1. **Auto-generated by default** — Every event gets a unique UUID:

   ```ruby
   event = EventEngine.cow_fed(cow: cow)
   event.idempotency_key # => "550e8400-e29b-41d4-a716-446655440000"
   ```

2. **Override when needed** — Provide your own key for domain-specific deduplication:

   ```ruby
   EventEngine.cow_fed(
     cow: cow,
     idempotency_key: "cow-#{cow.id}-fed-#{Date.current}"
   )
   ```

3. **Outbox enforces uniqueness** — Duplicate keys are rejected at the database
   level, preventing the same logical event from being written twice.

4. **Transports pass it downstream** — The key is included in the published
   payload so consumers can deduplicate on their end.

### Consumer responsibility

EventEngine stores and transmits the idempotency key, but does **not** enforce
idempotent processing. Consumers must implement their own deduplication logic
using the key (e.g., checking a processed-events table before handling).

### When to override the idempotency key

Override the auto-generated UUID when you need domain-specific deduplication:

- Prevent duplicate events for the same business operation (e.g., one feed event per cow per day)
- Ensure retries of user actions don't create duplicate events
- Correlate events across systems using a shared identifier

---

## Instrumentation

EventEngine publishes `ActiveSupport::Notifications` for observability. Subscribe
to these events to integrate with APM tools, custom dashboards, or logging.

### Available notifications

| Notification | When | Payload |
|--------------|------|---------|
| `event_engine.event_emitted` | Event written to outbox | `event_name`, `event_version`, `event_id`, `idempotency_key` |
| `event_engine.event_published` | Event sent to transport | `event_name`, `event_version`, `event_id` |
| `event_engine.event_dead_lettered` | Event exceeds max attempts | `event_name`, `event_version`, `event_id`, `attempts`, `error_message`, `error_class` |
| `event_engine.publish_batch` | Batch processing complete | `count` |

### Example subscriber

```ruby
ActiveSupport::Notifications.subscribe("event_engine.event_emitted") do |name, start, finish, id, payload|
  Rails.logger.info("[EventEngine] Emitted #{payload[:event_name]} (id=#{payload[:event_id]})")
end

ActiveSupport::Notifications.subscribe("event_engine.event_dead_lettered") do |name, start, finish, id, payload|
  Alerting.notify("Event dead-lettered: #{payload[:event_name]} after #{payload[:attempts]} attempts")
end
```

---

## Dead letter recovery

Events that fail publishing after `max_attempts` are dead-lettered. Use rake
tasks to inspect and retry them.

### List dead-lettered events

```bash
bin/rails event_engine:dead_letters:list
```

### Retry a single event

```bash
bin/rails event_engine:dead_letters:retry[123]
```

### Retry all dead-lettered events

```bash
bin/rails event_engine:dead_letters:retry:all
```

### Programmatic retry

```ruby
event = EventEngine::OutboxEvent.dead_lettered.find(123)
event.retry!  # Resets attempts to 0, clears dead_lettered_at
```

---

## Outbox cleanup

Published events accumulate in the outbox table. Configure automatic cleanup
to remove old events while preserving unpublished and dead-lettered events.

### Configuration

```ruby
EventEngine.configure do |config|
  config.retention_period = 30.days  # nil to disable cleanup
end
```

### Manual cleanup

```bash
bin/rails event_engine:outbox:cleanup
```

### Automated cleanup

Schedule `OutboxCleanupJob` with your preferred scheduler:

```ruby
# Using sidekiq-scheduler
Sidekiq::Cron::Job.create(
  name: "EventEngine cleanup",
  cron: "0 3 * * *",  # Daily at 3am
  class: "EventEngine::OutboxCleanupJob"
)
```

The job silently skips cleanup if `retention_period` is not configured.

---

## Dashboard

EventEngine includes an optional observability dashboard for monitoring your
event pipeline.

### Setup

1. Configure authentication in your initializer:

```ruby
EventEngine.configure do |config|
  config.dashboard_auth = ->(controller) {
    # Return true to allow access, false to deny
    controller.current_user&.admin?
  }
end
```

2. Mount the engine in your routes (if not already mounted):

```ruby
# config/routes.rb
mount EventEngine::Engine => "/event_engine"
```

3. Access the dashboard at `/event_engine/dashboard`

### Features

- **Overview** — Total events, published, unpublished, and dead-lettered counts
- **Events list** — Browse all events with pagination and status
- **Event details** — Inspect payload and metadata
- **Dead letters** — View and retry failed events

### Security

The dashboard is protected by `dashboard_auth`. If not configured or if the
callable returns false, the dashboard returns 403 Forbidden. Implement your
own authorization logic based on your app's requirements.

---

## EventEngine Cloud

EventEngine includes an optional Cloud Reporter that sends lightweight event
metadata to [EventEngine Cloud](https://eventengine.dev) for real-time
observability, alerting, and schema intelligence.

### What gets reported

Only metadata is sent — **never** event payloads or business data:
- Event name, type, version, and status (emitted / published / dead-lettered)
- Timestamps and publish latency
- Attempt counts and error classes (for dead letters)
- Schema fingerprints (via periodic heartbeat)

### Setup

Add your Cloud API key to the initializer:

```ruby
EventEngine.configure do |config|
  config.cloud_api_key = ENV["EVENT_ENGINE_CLOUD_KEY"]
end
```

That's it. The reporter starts automatically at boot and you'll see:

```
[EventEngine] Cloud Reporter started — reporting to https://api.eventengine.dev/v1/ingest
```

When no API key is configured, the reporter does nothing — zero overhead.

### Configuration options

| Option | Default | Description |
|--------|---------|-------------|
| `cloud_api_key` | `nil` | Your Cloud API key. Reporter is inactive when nil. |
| `cloud_endpoint` | `https://api.eventengine.dev/v1/ingest` | Cloud API endpoint |
| `cloud_batch_size` | `50` | Max entries per batch before auto-flush |
| `cloud_flush_interval` | `10` | Seconds between scheduled flushes |
| `cloud_environment` | `nil` | Environment label (defaults to `Rails.env` in SaaS) |
| `cloud_app_name` | `nil` | App name label (defaults to app module name in SaaS) |

### Failure isolation

The reporter is designed to be invisible to your application:
- All network calls are fire-and-forget with a 5-second timeout
- Errors are logged but never raised — reporter failures cannot affect your app
- Uses `Net::HTTP` from stdlib — no additional gem dependencies
- Hooks into existing `ActiveSupport::Notifications` — no monkey-patching

---

## Troubleshooting & common errors

### Missing schema in production
On boot, EventEngine expects `db/event_schema.rb`. If missing outside
development/test, it raises and tells you to run the schema dump task.

### Unknown event or version
If you emit an event name/version not present in the schema, it raises
`EventEngine::SchemaRegistry::UnknownEventError`.

### Transport not configured
When using `:active_job`, the publisher raises if no transport is configured.

---

## Tasks / Issues to address

1. **Schema task naming mismatch**
   - Engine boot error message references `event_engine:schema_dump`
     but the schema writer header references `event_engine:schema:dump`.
   - Ensure the task is named consistently and update error text.

2. **README or docs for migrations**
   - There is no documented migration generator for the outbox table.
   - Consider adding a generator or documenting the required migration.

3. **Transport default safety**
   - Default `transport` is `nil`. If `delivery_adapter` is `:active_job`
     without transport set, the job raises. Consider a clearer failure path
     or default test transport in development.

4. **Definition loading clarity**
   - Ensure definition files are eager-loaded or documented for autoload paths.

---

## Contributing

1. Fork and create a feature branch.
2. Add tests for behavior changes.
3. Submit a PR.

---

## License
The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
