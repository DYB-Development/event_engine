## EventEngine

> **DO NOT** explore the event_engine gem source code. This reference is the
> complete user-facing API. Use only what is documented here. EventEngine is a
> schema-first event pipeline: you define events with a DSL, compile them to a
> committed schema file, and emit them through the outbox to pluggable transports.

### Mental model

1. **Define** events as Ruby classes in `app/event_definitions/`.
2. **Dump** the schema (`bin/rails event_engine:schema:dump`) → `db/event_schema.rb`. Commit it.
3. **Boot** loads the committed schema and installs `EventEngine.<event_name>` helpers.
4. **Emit** by calling those helpers; events route by `event_level`.
5. **Publish** drains the outbox to the configured transport, with retries and dead-lettering.

The committed `db/event_schema.rb` — not the definition classes — is authoritative
at runtime. Definitions are only read at dump time.

---

### Defining events

Subclass `EventEngine::EventDefinition` and use the class-level DSL:

```ruby
class CowFed < EventEngine::EventDefinition
  input :cow                 # required input
  optional_input :farmer     # optional input

  event_name :cow_fed        # symbol, the event's identity
  event_type :domain         # :domain, :integration, etc.
  event_level 3              # 1-4, controls dispatch (see below); optional

  required_payload :weight, from: :cow, attr: :weight
  optional_payload :name,   from: :farmer, attr: :name
end
```

| DSL method | Purpose |
|---|---|
| `event_name(:symbol)` | The event's identity. Becomes the `EventEngine.<name>` helper. |
| `event_type(:symbol)` | Classification, e.g. `:domain` or `:integration`. |
| `event_level(1..4)` | Dispatch strategy (optional). See the level table. |
| `input(:name)` | A required input accepted by the emit helper. |
| `optional_input(:name)` | An optional input. |
| `required_payload(name, from:, attr: nil)` | Payload field. `from:` names the input; `attr:` is the method called on it (`nil` = pass the input through). |
| `optional_payload(name, from:, attr: nil)` | Same, but omitted from the payload when the source input is nil. |

Duplicate `input`/`optional_input` names raise `ArgumentError`.

**Event levels** control how an emitted event is dispatched:

| Level | Behavior |
|---|---|
| 1 | Subscribers invoked synchronously in the caller's stack. |
| 2 | Subscribers invoked in a background job. |
| 3 | Written to the outbox, then subscribers invoked when the outbox drains. |
| 4 | Outbox + broker transport delivery. |

---

### Emitting events

After boot, each defined event has a singleton helper on `EventEngine`. Pass the
declared inputs by keyword, plus optional emit-time metadata:

```ruby
EventEngine.cow_fed(
  cow: cow,                       # declared inputs, by name
  farmer: farmer,
  occurred_at: Time.current,      # optional, defaults to now
  metadata: { request_id: "abc" },# optional contextual hash
  idempotency_key: "…",           # optional, defaults to a UUID
  aggregate_type: "Cow",          # optional aggregate tracking
  aggregate_id: cow.id,
  aggregate_version: 1
)
```

- Missing a required input, or passing an unknown input, raises `ArgumentError`.
- Levels 1–2 return a non-persisted `Event`; levels 3+ return the persisted `OutboxEvent`.
- `idempotency_key` is unique-constrained; consumers dedupe on it.

---

### Subscribers

React to events in-process by subclassing `EventEngine::Subscriber`:

```ruby
class SendWelcomeEmail < EventEngine::Subscriber
  subscribes_to :user_registered

  def handle(event)
    # event.payload is symbol-keyed
    UserMailer.welcome(event.payload[:user_id]).deliver_later
  end
end
```

- `subscribes_to(:event_name)` registers the subscriber at load time.
- `handle(event)` is required; not overriding it raises `NotImplementedError`.
- Subscribers run at levels 1–3 and **must be idempotent** (they may be retried).

---

### Configuration

```ruby
EventEngine.configure do |config|
  config.delivery_adapter = :inline   # or :active_job
  config.transport        = EventEngine::Transports::InMemoryTransport.new
  config.batch_size       = 100
  config.max_attempts     = 5
  config.retention_period = 30.days   # nil = keep forever
end
```

| Option | Default | Purpose |
|---|---|---|
| `delivery_adapter` | `:inline` | `:inline` publishes in-process; `:active_job` enqueues. |
| `transport` | `NullTransport` | Broker; must respond to `#publish(event)`. |
| `batch_size` | `100` | Events per outbox publish batch. |
| `max_attempts` | `5` | Publish retries before dead-lettering. |
| `retention_period` | `nil` | Age after which published events are cleanable. |

Invalid config raises `InvalidConfigurationError` (e.g. `:active_job` with no real
transport, a transport without `#publish`, non-positive `batch_size`/`max_attempts`).

**Transports:** `InMemoryTransport` (dev/test), `Kafka` (production, topics
`events.{event_name}`), `NullTransport` (default; logs and discards). A custom
transport is any object with `#publish(event)` that raises on failure.

---

### Schema workflow

```bash
bin/rails event_engine:schema:dump    # compile definitions → db/event_schema.rb
bin/rails event_engine:schema_check   # CI: fail if definitions drifted from the file
```

- `schema:dump` compiles all `EventDefinition` subclasses and merges into the
  committed file: a new event is version 1; a changed event gets a new version
  (detected via payload fingerprint). **Always commit `db/event_schema.rb`.**
- `schema_check` belongs in CI to prevent drift between the DSL and the file.

---

### Outbox operations

For levels 3+ events flow through `event_engine_outbox_events` and are drained to
the transport. Failed deliveries retry up to `max_attempts`, then dead-letter.

```bash
bin/rails event_engine:dead_letters:list          # list dead-lettered events
bin/rails event_engine:dead_letters:retry[ID]     # retry one
bin/rails event_engine:dead_letters:retry:all     # retry all
bin/rails event_engine:outbox:cleanup             # delete old published events (needs retention_period)
```

`ActiveSupport::Notifications` are emitted for observability:
`event_engine.event_emitted`, `event_engine.event_published`,
`event_engine.event_dead_lettered`, `event_engine.publish_batch`.

---

### Installing / setup

```bash
bin/rails g event_engine:install
```

Installs the outbox migration, a stub `db/event_schema.rb`, and
`config/initializers/event_engine.rb`. Then: define events, run
`event_engine:schema:dump`, commit the schema, and configure a transport.

---

### Common scenarios

**Add a domain event end to end**
1. Create `app/event_definitions/order_placed.rb` subclassing `EventEngine::EventDefinition`.
2. Declare `input`s, `event_name`, `event_type`, `event_level`, and `*_payload` fields.
3. `bin/rails event_engine:schema:dump` and commit `db/event_schema.rb`.
4. Emit with `EventEngine.order_placed(...)` from your domain code.

**React to an event** — add a `EventEngine::Subscriber` with `subscribes_to` +
`handle`; keep it idempotent.

**Send to Kafka** — set `config.transport = EventEngine::Transports::Kafka.new(...)`
and `config.delivery_adapter = :active_job`; use `event_level 4`.

**Recover failures** — inspect with `dead_letters:list`, fix the cause, then
`dead_letters:retry:all`.
