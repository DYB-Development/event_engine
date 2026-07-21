# EventEngine

The **Rails host runtime** of the [EventEngine](https://github.com/DYB-Development) pipeline.

EventEngine is a schema-first event pipeline. Domain events are **declared** and
**compiled** into a committed contract by domain-pack gems (built on
[`event_engine-event_definition`](https://github.com/DYB-Development/event_engine-event_definition)).
This gem is the **runtime** a Rails app installs: it holds the schema registry,
**builds** a validated `EventEngine::Event` from the inputs a pack hands it, and
**dispatches** each event to the handlers that are registered.

This gem does **not** author events (that is `event_engine-event_definition` + your
domain packs) and does **not** deliver them (that is the handler gems below). It is
the middle of the pipe: inputs in, built event out, fanned to handlers.

> **Status.** The authoring layer has been fully extracted out of this gem. The
> *passive* wiring that makes packs work with **no per-pack host config** — the
> publisher adapter and pack self-registration described in
> [How it fits together](#how-it-fits-together) — is the intended end state but is
> **not wired yet**. Until it lands, drive the runtime directly with
> [`EventEngine.emit`](#emitting-events). See [Not wired yet (TBD)](#not-wired-yet-tbd).

---

## Where this gem sits

| Gem | Responsibility | Add it when |
|---|---|---|
| [`event_engine-event_definition`](https://github.com/DYB-Development/event_engine-event_definition) | The DSL, schema value objects, and the build step that turns definitions into a committed helper file + `schema.json`. No Rails. | A gem or app **declares** events |
| **`event_engine`** (this gem) | Registry, build a validated event, dispatch to handlers by `process_type` | Always — it's the host runtime |
| `event_engine-delivery` | Transactional outbox, retries, dead-letters, transports (Kafka), dashboard | You need durable/broker delivery |
| `event_engine-store` | Durable append-only event log + replay & projections | You need a permanent record / event sourcing |
| `event_engine-subscribers`, `-telemetry`, `-sourced` | Handler gems for inline/background subscribers, telemetry, and event sourcing | You want that processing style |

Domain packs (e.g. `event_engine-marketing_events`, `-sales_events`, `-user_events`)
declare events against `event_engine-event_definition` and each ships its own
committed `schema.json` and helper module.

---

## How it fits together

A pack's generated helper does **not** emit. It forwards the raw inputs through a
**publisher port**; this gem is what turns those inputs into a real event and
dispatches it.

```
pack helper  (event_engine-event_definition)
    MarketingEvents.lead_created(lead: lead, …envelope)
          │  calls the publisher PORT (not emit):
          ▼
    EventEngine::Definition.publisher.publish(:lead_created, domain: :marketing,
                                               inputs: { lead: lead }, …envelope)
          │  default publisher raises until one is wired
          ▼
    event_engine's publisher adapter          ◄── TBD: event_engine assigns itself here
          │  EventEngine.emit(:lead_created, inputs: { lead: lead }, domain: :marketing, …)
          ▼
    EventBuilder builds the payload from each field's from:/attr:  ◄── schema from the registry
          │  EventEngine.dispatch(event)
          ▼
    handlers whose process_types match event.process_type
          (event_engine-delivery / -store / -subscribers / your own)
```

**`EventEngine.emit` is the official emit, and it lives here** — not in the pack. The
pack passes *inputs* (the whole objects you already have); this gem reads them via
the schema's `from:`/`attr:` mapping to build the flat `payload`, stamps the
envelope, and dispatches.

### The intended passive wiring (TBD)

The goal is that a host installs the gems and configures **nothing per pack**. Two
halves self-wire at boot:

1. **Emit routing** — `event_engine` registers itself as
   `EventEngine::Definition.publisher`, so every pack's helper routes into
   `EventEngine.emit` automatically. **TBD** — today the default publisher raises
   `PublisherNotConfigured`.
2. **Schema loading** — each pack's Rails engine calls
   `EventEngine.register_slice!(schema_path: Pack.schema_path)` at boot, so its
   events are resolvable in the registry. `register_slice!` exists and is additive;
   **packs doing this is TBD** (and the packs aren't set up yet).

---

## Using it today

Until the passive halves land, drive the runtime directly.

```ruby
# Gemfile
gem "event_engine"
```

```bash
bundle install
```

### 1. Get the schema into the registry

At boot the engine loads a committed **`db/event_schema.json`** and reconstructs the
registry from it (no Ruby is evaluated from a schema file; missing in production
raises). Put the schema there by either:

- committing `db/event_schema.json` directly, or
- registering a pack's slice at boot (additive — each slice merges in):

  ```ruby
  # in a pack's Rails engine
  initializer "marketing_events.register_events" do
    config.after_initialize do
      EventEngine.register_slice!(schema_path: MarketingEvents.schema_path)
    end
  end
  ```

### 2. Register a handler

Add a handler gem (`event_engine-delivery`, `-store`, `-subscribers`, …) **or** your
own — anything responding to `#call(event)`:

```ruby
# config/initializers/event_engine.rb
EventEngine.register_handler(
  ->(event) { Rails.logger.info("[event] #{event.event_name} #{event.payload.inspect}") },
  process_types: :all
)
```

With no handler, the event is still built and dispatched — just to no one.

### 3. Emit

```ruby
EventEngine.emit(:cow_fed, inputs: { cow: cow }, domain: :sales)
```

---

## Emitting events

`EventEngine.emit` is the always-available entry point (and the target the publisher
adapter will forward to). It looks the event up in the registry, builds its payload
from the inputs, stamps the envelope, dispatches, and returns the built
`EventEngine::Event`.

```ruby
event = EventEngine.emit(
  :cow_fed,
  inputs: { cow: cow, farmer: farmer },  # the declared inputs, by name

  domain: :sales,                        # scopes lookup when a name exists in >1 domain
  event_version: 2,                      # optional; defaults to the latest version
  occurred_at: Time.current,             # optional; defaults to Time.current
  metadata: { source: "import" },        # optional; merged over metadata_defaults
  idempotency_key: "cow-#{cow.id}",      # optional; defaults to a UUID
  aggregate_type: "Cow",                 # optional aggregate envelope fields
  aggregate_id: cow.id,
  aggregate_version: 3
)

event.payload        # => { weight: 500 }   (symbol-keyed, built from inputs)
event.process_type   # => :durable          (from the schema)
```

Input validation (missing required input, unknown input) raises `ArgumentError` at
build time.

### Named helpers (`MarketingEvents.lead_created`)

The ergonomic per-event helpers live in the **domain packs**, generated by
`event_engine-event_definition`. This runtime does not generate them; at boot it will
`load db/event_engine_helpers.rb` **if a pack has committed one**, but it never
creates that file. Once the [publisher adapter](#the-intended-passive-wiring-tbd)
is wired, calling a pack helper routes through `EventEngine.emit` for you; until then,
call `EventEngine.emit` directly.

---

## Dispatch and `process_type`

`EventEngine.dispatch(event)` calls every registered handler whose `process_types`
match the event's own `process_type` (or that registered with `:all`). The
`process_type` is part of the committed schema, not chosen at emit time.

| `process_type` | Handled by (category) |
|---|---|
| `inline`, `background` | subscribers |
| `durable`, `broker` | delivery |
| `telemetry` | telemetry |
| `sourced` | sourcing |

### Registering a handler

```ruby
EventEngine.register_handler(MyHandler.new, process_types: %i[durable broker])
EventEngine.register_handler(->(event) { … }, process_types: :all)
```

`process_types:` is either `:all` or a list of `process_type` symbols. Companion gems
register themselves this way from their own railties.

---

## Configuration

Set via `EventEngine.configure { |config| … }`. All fields are optional.

| Field | Default | Accepts | What it does |
|---|---|---|---|
| `schema_path` | `"db/event_schema.json"` | String / path | The committed catalog the engine loads at boot, and the file the catalog task writes. |
| `metadata_defaults` | `nil` | A callable (`-> { Hash }`) | Called on each emit; its hash is merged **under** any call-site `metadata:` (call-site wins). A raising callable is swallowed and logged, so emission never breaks. |
| `logger` | `Rails.logger` | Any Logger | Where the engine logs (missing-schema warning, a raising `metadata_defaults`). |
| `publisher_schema_paths` | `[]` | Array of paths | Inputs to the **optional** catalog-aggregation task only (see below). Not part of the runtime path. |

---

## The `Event`

`EventEngine::Event` is a keyword-init `Struct`:

```
event_name  event_type  event_version  process_type  subject  domain
payload  metadata  occurred_at  idempotency_key
aggregate_type  aggregate_id  aggregate_version
```

`Event.from(record)` rebuilds one from any object exposing those readers (symbolizing
the payload keys) — handy for handler gems reconstituting a persisted event.

---

## Rake tasks

| Task | What it does |
|---|---|
| `event_engine:schema:catalog` | **Optional aggregation.** Concatenates every `schema.json` in `publisher_schema_paths` into one committed catalog at `schema_path` — useful as a single committed source or for BI/data consumers. Not required for the runtime. |
| `event_engine:catalog` | Prints a Markdown catalog of the loaded events and their subjects. |

---

## Not wired yet (TBD)

Honest gaps in the current runtime:

- **Publisher-adapter wiring.** `event_engine` does not yet register itself as
  `EventEngine::Definition.publisher`, so a pack's generated helper does not route
  through this runtime automatically — the default publisher raises. Until then, use
  `EventEngine.emit` directly. (Deliberately out of scope of the authoring-removal
  work.)
- **Pack self-registration.** No pack ships an engine that `register_slice!`s its
  schema at boot yet, and the packs themselves aren't set up. The primitive exists;
  the convention doesn't.
- **Boot still requires a committed `db/event_schema.json`.** The engine raises in
  production if that file is missing — which is in tension with the fully-passive
  goal (schema arriving only via `register_slice!`). Reconciling the two is part of
  finishing the passive wiring.
- **`the_local` guides.** The AI-assistant reference under
  `lib/event_engine/reference/` and the `the_local` subagents still describe the old
  in-gem DSL. They are generated provider docs (owned by `the_local-develop`) and
  will be regenerated to match this runtime.

---

## Development

```bash
bundle install
bundle exec rake test        # Minitest, via the dummy app in test/dummy
```

---

## License

Available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
