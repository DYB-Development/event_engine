## EventEngine (core)

> This reference covers the **core** `event_engine` gem: defining events, the
> committed schema, emitting, subscribers, levels, and the handler extension point.
> Durable delivery (outbox, transports, dead-letters, dashboard, cloud reporter)
> lives in **`event_engine-delivery`**; the durable event log, replay, and
> projections live in **`event_engine-store`**. When those gems are present, see
> their READMEs for their APIs. Prefer this reference over reading gem source.

### Mental model

1. **Define** events as Ruby classes in `app/event_definitions/`.
2. **Dump** the schema (`bin/rails event_engine:schema:dump`) → `db/event_schema.rb`. Commit it.
3. **Boot** loads the committed schema and installs `EventEngine.<event_name>` helpers.
4. **Emit** by calling those helpers; each built event carries its `event_level`.
5. **Dispatch** fans the event out to every registered handler whose `levels:` match.

The committed `db/event_schema.rb` — not the definition classes — is authoritative
at runtime. Definitions are only read at dump time. **Core ships no handlers**; it
only builds and dispatches events. Companion gems (or your own code) register
handlers that actually *do* something with events.

---

### Defining events

Subclass `EventEngine::EventDefinition` and use the class-level DSL:

```ruby
class CowFed < EventEngine::EventDefinition
  input :cow                 # required input
  optional_input :farmer     # optional input

  event_name :cow_fed        # symbol, the event's identity (required)
  event_type :domain         # :domain, :integration, etc. (required)
  event_level 3              # 1-4, controls dispatch (optional)

  required_payload :weight,      from: :cow,    attr: :weight
  optional_payload :farmer_name, from: :farmer, attr: :name
end
```

| DSL method | Purpose |
|---|---|
| `event_name(:symbol)` | The event's identity. Becomes `EventEngine.<name>`. Required. |
| `event_type(:symbol)` | Classification, e.g. `:domain` or `:integration`. Required. |
| `event_level(1..4)` | Dispatch strategy (optional). See the level table. |
| `input(:name)` | A required input accepted by the emit helper. |
| `optional_input(:name)` | An optional input. |
| `required_payload(name, from:, attr: nil)` | Payload field. `from:` names the input; `attr:` is the method called on it (`nil` = pass the input through). |
| `optional_payload(name, from:, attr: nil)` | Same, but omitted from the payload when the source input is nil. |

- Duplicate `input`/`optional_input` names raise `ArgumentError`.
- **There is no `type:` option and no type casting.** There is also no
  `entity_class`/`entity_id`/`entity_version` macro. The only payload macros are
  `required_payload` and `optional_payload` with `from:` and `attr:`. Whatever
  `attr:` returns is stored as-is — coerce types at the source method.
- Reserved payload names (rejected at dump): `event_name event_type event_version
  occurred_at created_at updated_at published_at metadata idempotency_key attempts
  dead_lettered_at aggregate_type aggregate_id aggregate_version`.

**Choosing an event level.** `event_level` controls how an emitted event is
dispatched *by the delivery layer*. Adopt the lowest level that solves your actual
problem, and move up only when the problem demands it.

| Level | Durable? | Where it goes | Adopt when | Be cautious because |
|---|---|---|---|---|
| **1 sync** | no | in-app subscribers, synchronously in the caller's stack | a cheap in-process reaction that must happen right now | a slow or failing subscriber blocks the emitting action; nothing persists, so it is lost on a crash |
| **2 job** | no | in-app subscribers, via a background job | the reaction can be deferred and shouldn't make the caller wait | still not durable; requires an ActiveJob backend; subscriber failures don't surface to the caller |
| **3 outbox** | **yes** | in-app subscribers, when the outbox drains | the reaction must not be lost and must be atomic with your DB write — but stays in the app | more moving parts; delivery is eventual, not immediate |
| **4 outbox + broker** | **yes** | **outside the app**, to the configured transport (Kafka, etc.) | an independent service needs to consume the event on its own deploy cycle | it becomes a cross-service contract, so schema/version discipline matters; requires a real transport |

Levels 1–4 are interpreted by **`event_engine-delivery`**. Core only stamps the
level onto the event. Level 5 (event sourcing) is reserved but unsupported by the
delivery layer (`UnsupportedLevelError`). An omitted level is `nil`; the delivery
layer routes `nil` through its outbox path — set a level explicitly to be clear.

**Signals to move up a level** — let the problem, not a guess, drive the upgrade:

- A synchronous (level 1) subscriber is slow or on the request hot path → **1 → 2**: defer it to a background job so the caller stops waiting.
- Work is being lost across crashes, restarts, or deploys → **2 → 3**: capture in the outbox so the reaction survives and is atomic with your write.
- An independent service needs to consume the event on its own deploy cycle → **3 → 4**: publish it to the external broker.

Keep subscribers idempotent so moving an event up a level later requires no rewrite.

---

### Emitting events

After boot, each defined event has a singleton helper on `EventEngine`. Pass the
declared inputs by keyword, plus optional emit-time envelope fields:

```ruby
EventEngine.cow_fed(
  cow: cow,                        # declared inputs, by name
  farmer: farmer,
  occurred_at: Time.current,       # optional, defaults to now
  metadata: { request_id: "abc" }, # optional contextual hash
  idempotency_key: "…",            # optional, defaults to a UUID
  aggregate_type: "Cow",           # optional aggregate tracking
  aggregate_id: cow.id,
  aggregate_version: 1
)
```

- Missing a required input, or passing an unknown input, raises `ArgumentError`.
- `event_version:` pins a specific schema version (defaults to the latest).
- The return value is whatever the registered handlers return — core has no
  canonical return. (`event_engine-delivery` returns the persisted `OutboxEvent` for
  levels 3+; levels 1–2 return the non-persisted `Event`.)
- `event.payload` is symbol-keyed.

---

### Subscribers

React to events in-process by subclassing `EventEngine::Subscribers::Base`
(provided by the `event_engine-subscribers` gem):

```ruby
class SendWelcomeEmail < EventEngine::Subscribers::Base
  subscribes_to :user_registered

  def handle(event)
    UserMailer.welcome(event.payload[:user_id]).deliver_later
  end
end
```

- `subscribes_to(:event_name)` registers the subscriber at load time.
- `handle(event)` is required; not overriding it raises `NotImplementedError`.
- Subscribers live in the **`event_engine-subscribers`** gem; **`event_engine-delivery`
  invokes them** for levels 1–3. Keep them idempotent (they may be retried at level 3+).

---

### The handler extension point

A handler is any object with `call(event)`. This is how delivery, store, and your
own code observe events.

```ruby
EventEngine.register_handler(handler, levels: :all)   # every event
EventEngine.register_handler(handler, levels: 1..4)   # a Range
EventEngine.register_handler(handler, levels: [1, 3]) # explicit list

EventEngine.dispatch(event)        # fan an Event out (emit helpers call this)
EventEngine.reset_handlers!        # clear all handlers (tests / full takeover)
```

Handlers run synchronously, in registration order, inside `dispatch`. If one raises,
later handlers don't run and the error propagates. `event_engine-delivery` and
`event_engine-store` each register handlers at `levels: :all` at Rails boot.

---

### Configuration (core)

Core configuration is just a logger:

```ruby
EventEngine.configure do |config|
  config.logger = Rails.logger
end
```

**Delivery options are configured separately**, on `EventEngine::Delivery.configure`
(`delivery_adapter`, `transport`, `batch_size`, `max_attempts`, `retention_period`,
`dashboard_auth`, `cloud_*`). See the `event_engine-delivery` README.

---

### Schema workflow

```bash
bin/rails event_engine:schema:dump    # compile definitions → db/event_schema.rb
bin/rails event_engine:schema_check   # CI: fail if definitions drifted from the file
```

- `schema:dump` compiles all `EventDefinition` subclasses and merges into the
  committed file: a new event is version 1; a changed event gets a new version
  (detected via a payload/identity fingerprint). `event_level` is **not** part of the
  fingerprint, so changing only the level does not bump the version. **Always commit
  `db/event_schema.rb`.**
- `schema_check` belongs in CI to prevent drift between the DSL and the file.

---

### Installing / setup

```bash
bin/rails g event_engine:install
```

Creates `config/initializers/event_engine.rb`, a stub `db/event_schema.rb`, and
Claude Code subagents under `.claude/agents/`. (Core ships no migrations; the outbox
migration is provided by `event_engine-delivery`, the event-log migration by
`event_engine-store`.) Then: define events, run `event_engine:schema:dump`, commit
the schema, and register a handler (add a companion gem or write your own).

---

### Common scenarios

**Add a domain event end to end**
1. Create `app/event_definitions/order_placed.rb` subclassing `EventEngine::EventDefinition`.
2. Declare `input`s, `event_name`, `event_type`, `event_level`, and `*_payload` fields.
3. `bin/rails event_engine:schema:dump` and commit `db/event_schema.rb`.
4. Emit with `EventEngine.order_placed(...)` from your domain code.
5. Ensure a handler is registered (delivery/store gem, or your own).

**React to an event** — add an `EventEngine::Subscriber` with `subscribes_to` +
`handle`; keep it idempotent. (Requires `event_engine-delivery` to invoke it.)

**Deliver reliably / to Kafka** — add `event_engine-delivery` and configure it via
`EventEngine::Delivery.configure`. See that gem's README.

**Keep a permanent event log / event sourcing** — add `event_engine-store`. See that
gem's README.
