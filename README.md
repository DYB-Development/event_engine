# EventEngine

EventEngine is the schema-first **core** of an event pipeline for Rails:

- **Define** events with a small Ruby DSL.
- **Compile** them into a canonical, committed schema file (`db/event_schema.rb`).
- **Emit** them through generated helpers (`EventEngine.cow_fed(...)`) that build a
  validated `Event` and **dispatch** it to registered handlers by *level*.

The core gem does **not** deliver events anywhere on its own. It builds the event
and hands it to whatever handlers are registered. Durable delivery and durable
storage live in companion gems that register themselves as handlers:

| Gem | Responsibility | Add it when |
|---|---|---|
| **`event_engine`** (this gem) | Define, compile, emit, dispatch | Always — it's the core |
| [`event_engine-delivery`](https://github.com/tylercschneider/event_engine-delivery) | Transactional outbox, retries, dead-letters, transports (Kafka), dashboard, cloud reporter | You need to deliver events reliably (in-process or to a broker) |
| [`event_engine-store`](https://github.com/tylercschneider/event_engine-store) | Durable, append-only event log + event-sourcing replay & projections | You need a permanent record of every event / event sourcing |

You can run the core gem **by itself** with your own handlers — see
[The handler extension point](#the-handler-extension-point).

> This README documents the core gem **only**. Outbox, transports, dead-letters,
> the dashboard, and the cloud reporter are documented in `event_engine-delivery`.
> The event log, replay, and projections are documented in `event_engine-store`.

---

## Table of contents

- [Quick start](#quick-start)
- [Mental model](#mental-model)
- [Defining events](#defining-events)
  - [The DSL reference](#the-dsl-reference)
  - [How payload fields are extracted](#how-payload-fields-are-extracted)
  - [There is no `type:` casting](#there-is-no-type-casting)
  - [Lifecycle event families](#lifecycle-event-families)
- [Generating the schema](#generating-the-schema)
  - [How versioning works](#how-versioning-works)
  - [Drift checking in CI](#drift-checking-in-ci)
- [Emitting events](#emitting-events)
- [Subscribers](#subscribers)
- [Event levels](#event-levels)
- [The handler extension point](#the-handler-extension-point)
- [Configuration](#configuration)
- [Rake tasks](#rake-tasks)
- [Installation generator](#installation-generator)
- [For AI assistants](#for-ai-assistants)
- [Contributing](#contributing)
- [License](#license)

---

## Quick start

```ruby
# Gemfile
gem "event_engine"
```

```bash
bundle install
```

1. **Define an event** in `app/event_definitions/cow_fed.rb` (see [Defining events](#defining-events)).
2. **Dump the schema**:
   ```bash
   bin/rails event_engine:schema:dump
   ```
3. **Commit `db/event_schema.rb`** — it is authoritative at runtime.
4. **Register at least one handler** so emitted events do something. Either add a
   companion gem (`event_engine-delivery` / `event_engine-store`) or write your own
   (see [The handler extension point](#the-handler-extension-point)).
5. **Emit** from your app code:
   ```ruby
   EventEngine.cow_fed(cow: cow)
   ```

> With **no** handler registered, the core gem builds and dispatches the event but
> nothing observes it. That's expected — core is the dispatch layer; handlers are
> what *do* something with events.

---

## Mental model

```
EventDefinition (Ruby DSL)
        │  bin/rails event_engine:schema:dump
        ▼
db/event_schema.rb   ◄── authoritative at runtime; commit it
        │  Rails boot (Engine initializer)
        ▼
SchemaRegistry  ──► installs EventEngine.<event_name> helpers
        │  you call EventEngine.cow_fed(cow: cow)
        ▼
EventBuilder builds a validated EventEngine::Event
        │  EventEngine.dispatch(event)
        ▼
HandlerRegistry ──► every registered handler whose `levels:` match event_level
                     (event_engine-delivery, event_engine-store, or your own)
```

Two things are worth internalizing:

1. **The committed schema file — not your definition classes — is the source of
   truth at runtime.** Definition classes are read only at *dump* time. In
   production a missing `db/event_schema.rb` raises at boot.
2. **Emitting and handling are decoupled.** `EventEngine.dispatch` just fans the
   event out to handlers by level. The core gem ships *no* handlers.

---

## Defining events

Put definitions where Rails eager-loads them — conventionally
`app/event_definitions/`. Subclass `EventEngine::EventDefinition`:

```ruby
# app/event_definitions/cow_fed.rb
class CowFed < EventEngine::EventDefinition
  input :cow                 # required input to the emit helper
  optional_input :farmer     # optional input

  event_name :cow_fed        # the event's identity → EventEngine.cow_fed
  event_type :domain         # free-form classification (:domain, :integration, …)
  event_level 3              # how it's dispatched (optional; see Event levels)

  required_payload :weight,      from: :cow,    attr: :weight
  optional_payload :farmer_name, from: :farmer, attr: :name
end
```

### The DSL reference

All methods below are **class-level** macros on an `EventDefinition` subclass.

| Macro | Signature | What it does |
|---|---|---|
| `event_name` | `event_name(:symbol)` | The event's identity. Becomes the `EventEngine.<name>` helper. **Required.** |
| `event_type` | `event_type(:symbol)` | Free-form classification, e.g. `:domain`, `:integration`, `:system`. **Required.** |
| `event_level` | `event_level(Integer)` | Dispatch level `1..4` (see [Event levels](#event-levels)). Optional. |
| `input` | `input(:name)` | Declares a **required** input keyword the emit helper accepts. Duplicate names raise `ArgumentError`. |
| `optional_input` | `optional_input(:name)` | Declares an **optional** input keyword. |
| `required_payload` | `required_payload(name, from:, attr: nil)` | A payload field that must be present. `from:` names the input it reads; `attr:` is the method called on that input. |
| `optional_payload` | `optional_payload(name, from:, attr: nil)` | Same, but **omitted from the payload** when the source input is `nil`. |

A handful of payload field names are **reserved** (they collide with event
envelope/outbox columns) and rejected at dump time:

```
event_name event_type event_version occurred_at created_at updated_at
published_at metadata idempotency_key attempts dead_lettered_at
aggregate_type aggregate_id aggregate_version
```

### How payload fields are extracted

When you emit, `EventBuilder` walks each declared payload field and pulls a value
out of the inputs you passed:

- `from:` selects **which input** to read.
- `attr:` is the **method called on that input**. If `attr:` is `nil`, the input
  itself is used (passthrough).
- For an `optional_payload`, if the `from:` input is `nil` the field is simply left
  out of the payload (no key, not a `nil` value).

```ruby
required_payload :weight, from: :cow, attr: :weight
# → payload[:weight] = cow.weight

optional_payload :raw_cow, from: :cow
# → payload[:raw_cow] = cow            (passthrough; attr omitted)

optional_payload :farmer_name, from: :farmer, attr: :name
# → only present if `farmer:` was passed and non-nil
```

The resulting `event.payload` is a **symbol-keyed Hash**.

### There is no `type:` casting

The complete payload DSL is `required_payload` / `optional_payload` with `from:` and
`attr:` only — there is no `type:` option and no type casting, and no
`entity_class` / `entity_id` / `entity_version` macros.

Whatever value `attr:` returns is stored as-is. If you need a value coerced to a
specific type, do it on the source object's method (e.g. have `cow.weight` return a
`Float`) or expose a purpose-built reader and point `attr:` at it.

### Lifecycle event families

Related events that describe one capability — `export_csv_started`,
`export_csv_completed`, `export_csv_failed` — share inputs and payload fields. Writing
them as three independent `EventDefinition`s lets their names and shared fields drift.
Subclass `EventEngine::LifecycleDefinition` to stamp the whole family from one template:

```ruby
# app/event_definitions/export_csv_events.rb
class ExportCsvEvents < EventEngine::LifecycleDefinition
  subject :export_csv                      # validated against the SubjectRegistry
  event_type :product

  input :export
  required_payload :format, from: :export, attr: :format

  lifecycle :started, :completed, :failed  # → export_csv_started / _completed / _failed

  on :failed do
    input :error
    required_payload :error_class, from: :error, attr: :class
  end
end
```

This generates three real `EventDefinition`s named `subject_verb` (flat snake_case, so
each yields a working `EventEngine.export_csv_completed(...)` helper). Shared declarations
apply to every verb; an `on :verb` block layers additional inputs/payloads onto that verb
only. The generated events behave exactly like hand-written ones everywhere — schema dump,
registry, helpers, metadata enricher, catalog, and compatibility checks all apply unchanged.

| Macro | Signature | What it does |
|---|---|---|
| `subject` | `subject(:symbol)` | The family's subject, carried onto every generated event. Must be registered. |
| `event_type` | `event_type(:symbol)` | Shared across every verb. |
| `process_type` | `process_type(:symbol)` | Shared across every verb. Optional. |
| `lifecycle` | `lifecycle(*verbs)` | Generates one event per verb, named `:"#{subject}_#{verb}"`. |
| `on` | `on(:verb) { … }` | Layers verb-specific `input` / `required_payload` / `optional_payload` onto that verb only. Add-only. |

Shared `input` / `optional_input` / `required_payload` / `optional_payload` are declared
exactly as on a plain `EventDefinition` and apply to every verb.

---

## Generating the schema

After adding or changing definitions:

```bash
bin/rails event_engine:schema:dump   # compile definitions → db/event_schema.rb
```

This compiles every `EventDefinition` subclass, merges with the existing committed
file, and rewrites `db/event_schema.rb`. **Commit the result.** The generated file
looks like:

```ruby
# This file is authoritative in production.
# It is generated from EventDefinitions via:
#
#   bin/rails event_engine:schema:dump
#
# Do not edit manually.

EventEngine::EventSchema.define do |schema|
  schema.register(
    EventEngine::EventDefinition::Schema.new(
      event_name: :cow_fed,
      event_version: 1,
      event_type: :domain,
      event_level: 3,
      required_inputs: [:cow],
      optional_inputs: [:farmer],
      payload_fields: [
        { name: :weight, required: true, from: :cow, attr: :weight }
      ]
    )
  )
end
```

### How versioning works

The dumper is **append-only and additive** — it never edits an existing version in
place:

- A brand-new event is written as **version 1**.
- When you change an existing event, the merger compares a **SHA256 fingerprint**
  of its `event_name`, `event_type`, inputs, and payload fields against the latest
  version in the file. If they differ, it writes a **new version** (`N + 1`); if
  they match, nothing changes.
- Version numbers are **monotonic** — reverting a change to a previous shape still
  produces a *new* higher version, never reuses an old number.

> **`event_level` is intentionally excluded from the fingerprint.** Changing only an
> event's level does **not** bump its version — level is treated as operational
> routing metadata, not part of the event contract. This is what lets you "promote"
> an event up the level ladder as a one-line change with no schema churn.

### Drift checking in CI

```bash
bin/rails event_engine:schema:verify
```

This fails if your definitions have drifted from the committed `db/event_schema.rb`
(i.e. someone changed a definition but forgot to dump), printing a readable diff of
what changed. Add it to CI to keep the file honest. The older `event_engine:schema`
and `event_engine:schema_check` tasks perform the same check without the diff.

---

## Emitting events

At boot the engine loads `db/event_schema.rb` and installs a singleton helper on
`EventEngine` for each event. Pass declared inputs by keyword, plus optional
emit-time envelope fields:

```ruby
EventEngine.cow_fed(
  cow: cow,                        # declared inputs, by name
  farmer: farmer,

  occurred_at: Time.current,       # optional; defaults to Time.current
  metadata: { request_id: "abc" }, # optional contextual hash
  idempotency_key: "cow-#{cow.id}-#{Date.current}", # optional; defaults to a UUID
  aggregate_type: "Cow",           # optional aggregate tracking
  aggregate_id: cow.id,
  aggregate_version: 1
)
```

- Missing a required input, or passing an unknown input, raises `ArgumentError`.
- `event_version:` may be passed to pin a specific schema version (defaults to latest).
- The return value is **whatever the handlers return** — there's no canonical return
  in core. (`event_engine-delivery`, for example, returns the persisted outbox record
  for levels 3+.)

The built `EventEngine::Event` exposes: `event_name`, `event_type`, `event_version`,
`event_level`, `payload` (symbol-keyed), `metadata`, `occurred_at`,
`idempotency_key`, `aggregate_type`, `aggregate_id`, `aggregate_version`.

---

## Subscribers

A **subscriber** reacts to an event in-process. Subclass `EventEngine::Subscriber`,
declare what it handles, and implement `handle`:

```ruby
# app/subscribers/send_welcome_email.rb
class SendWelcomeEmail < EventEngine::Subscriber
  subscribes_to :user_registered

  def handle(event)
    # event.payload is symbol-keyed
    UserMailer.welcome(event.payload[:user_id]).deliver_later
  end
end
```

- `subscribes_to(:event_name)` registers the subscriber at load time.
- `handle(event)` is required; the base raises `NotImplementedError` otherwise.

> **Who actually calls subscribers?** The core gem only *registers* subscribers in
> `EventEngine::SubscriberRegistry` — it does not invoke them. Invocation is done by
> a handler. `event_engine-delivery` invokes subscribers for levels 1–3 (see its
> docs). If you run core standalone, your own handler decides when/whether to call
> `EventEngine::SubscriberRegistry.subscribers_for(event.event_name)`.

Keep subscribers **idempotent** — at levels 3+ they may be retried.

---

## Event levels

`event_level` is a hint that tells the *delivery* layer how hard to work to get an
event where it's going. **Your producer code never changes when you move an event up
a level — it's a one-line edit to the definition.**

| Level | Durable? | Where it goes | Adopt when | Watch out for |
|---|---|---|---|---|
| **1 sync** | no | in-app subscribers, synchronously in the caller's stack | a cheap in-process reaction that must happen now | a slow/failing subscriber blocks the caller; nothing persists, so it's lost on a crash |
| **2 job** | no | in-app subscribers, via a background job | the reaction can be deferred | still not durable; needs an ActiveJob backend; failures don't surface to the caller |
| **3 outbox** | **yes** | in-app subscribers, when the outbox drains | the reaction must survive a crash and be atomic with your DB write | more moving parts; delivery is eventual |
| **4 outbox + broker** | **yes** | **outside the app**, to a transport (Kafka, …) | an independent service consumes it on its own cycle | it's a cross-service contract — schema/version discipline matters; needs a real transport |

Guiding principle: **adopt the lowest level that solves your real problem; move up
only when the problem demands it.** Signals to move up:

- A level-1 subscriber is slow / on the request hot path → **1 → 2**.
- Work is lost across crashes/restarts/deploys → **2 → 3**.
- An independent service must consume the event → **3 → 4**.

> **The level table describes behavior implemented by `event_engine-delivery`.** The
> core gem only stamps `event_level` onto the event and dispatches it. Levels 1–4
> *mean* something only once a handler that interprets them is registered. Level 5
> (event sourcing) is reserved but unsupported by the delivery layer.

> **Caveat:** if you omit `event_level`, the event's level is `nil`. Handlers decide
> how to treat `nil` — `event_engine-delivery`, for instance, routes `nil` through
> its outbox path (the `else` branch). Set a level explicitly to be unambiguous.

---

## The handler extension point

This is the seam every companion gem (and you) plug into. A **handler** is any
object that responds to `call(event)`. Register it with the levels it cares about:

```ruby
EventEngine.register_handler(handler, levels: :all)   # every event
EventEngine.register_handler(handler, levels: 1..4)   # a Range
EventEngine.register_handler(handler, levels: [1, 3]) # an explicit list
```

On `EventEngine.dispatch(event)`, every handler whose `levels:` include
`event.event_level` (or `:all`) gets `call(event)`, in registration order.

A minimal standalone handler — no companion gem required:

```ruby
# config/initializers/event_engine.rb
class LogEverythingHandler
  def call(event)
    Rails.logger.info("[event] #{event.event_name} v#{event.event_version} #{event.payload.inspect}")
    event
  end
end

Rails.application.config.after_initialize do
  EventEngine.register_handler(LogEverythingHandler.new, levels: :all)
end
```

This is exactly how the companion gems hook in:

- **`event_engine-delivery`** registers a handler at `levels: :all` that routes by
  level (sync subscribers / background job / outbox / broker).
- **`event_engine-store`** registers two handlers at `levels: :all` (a recorder and a
  projection dispatcher).

Other primitives on the `EventEngine` module:

- `EventEngine.dispatch(event)` — fan an `Event` out to handlers (helpers call this).
- `EventEngine.reset_handlers!` — clear all handlers (useful in tests, or to fully
  take over routing).

> Handlers run **in-process, in order, synchronously** within `dispatch`. If a
> handler raises, later handlers don't run and the exception propagates to the
> caller. Order matters: register `event_engine-store` before/after `delivery`
> deliberately if both are present.

---

## Configuration

The **core** gem's configuration is intentionally tiny — just a logger:

```ruby
# config/initializers/event_engine.rb
EventEngine.configure do |config|
  config.logger = Rails.logger   # the only core option
end
```

| Option | Default | Purpose |
|---|---|---|
| `logger` | `Rails.logger` (or `Logger.new($stdout)` outside Rails) | Where core logs |

> Delivery options (`delivery_adapter`, `transport`, `batch_size`, …) belong to
> `event_engine-delivery` and are set via `EventEngine::Delivery.configure` — see that
> gem's README.

---

## Rake tasks

| Task | Purpose |
|---|---|
| `event_engine:schema:dump` | Compile definitions → `db/event_schema.rb` (commit it) |
| `event_engine:schema:verify` | Fail with a readable diff if definitions have drifted (use in CI) |
| `event_engine:schema` | Same drift check, no diff |
| `event_engine:schema_check` | Same drift check, no diff (alternate name) |

(`event_engine-delivery` adds `dead_letters:*` and `outbox:cleanup` tasks.)

---

## Installation generator

```bash
bin/rails g event_engine:install
```

It creates `config/initializers/event_engine.rb`, a stub `db/event_schema.rb`, and
installs Claude Code subagent files under `.claude/agents/` (see
[For AI assistants](#for-ai-assistants)).

The core gem itself ships no migrations. If you need the outbox or the event log,
install the companion gem you need and run its migrations directly (see
`event_engine-delivery` / `event_engine-store`).

---

## For AI assistants

A condensed, authoritative API reference ships inside the gem at
`lib/event_engine/reference/guide.md` and is installed into consuming apps as Claude
Code subagents (`.claude/agents/`). When working in a host app, prefer that
reference and this README over reading gem internals.

---

## Contributing

1. Fork and create a feature branch.
2. Add tests for behavior changes (Minitest; see `test/`).
3. Run the suite: `bundle exec rake test`.
4. Open a PR.

---

## License

Available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
