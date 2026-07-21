# EventEngine

The **Rails host runtime** of the [EventEngine](https://github.com/DYB-Development) pipeline.

EventEngine is a schema-first event pipeline. Domain events are **declared** and
**compiled** into a committed contract by the domain-pack gems (built on
[`event_engine-event_definition`](https://github.com/DYB-Development/event_engine-event_definition)).
This gem is the **runtime** that a Rails app installs: it loads those committed
contracts, **builds** a validated `EventEngine::Event` from the data you hand it,
and **dispatches** each event to whatever handlers are registered.

This gem does **not** author events (that is `event_engine-event_definition` + your
domain packs) and does **not** deliver them (that is the handler gems below). It is
the seam in the middle: contract in, built event out, fanned to handlers.

> **Status:** the authoring layer has been fully extracted out of this gem. One
> runtime seam — the **publisher adapter** that lets a pack's generated helper call
> back into this runtime automatically — is **not wired yet**. See
> [Not wired yet (TBD)](#not-wired-yet-tbd). Until it lands, drive the runtime with
> [`EventEngine.emit`](#emitting-events) directly.

---

## Where this gem sits

| Gem | Responsibility | Add it when |
|---|---|---|
| [`event_engine-event_definition`](https://github.com/DYB-Development/event_engine-event_definition) | The DSL, schema value objects, and the build step that turns definitions into a committed helper file + `schema.json`. No Rails. | A gem or app **declares** events |
| **`event_engine`** (this gem) | Load the committed schema catalog, build validated events, dispatch them to handlers by `process_type` | Always — it's the host runtime |
| `event_engine-delivery` | Transactional outbox, retries, dead-letters, transports (Kafka), dashboard | You need durable/broker delivery |
| `event_engine-store` | Durable append-only event log + replay & projections | You need a permanent record / event sourcing |
| `event_engine-subscribers`, `-telemetry`, `-sourced` | Handler gems for inline/background subscribers, telemetry, and event sourcing | You want that processing style |

Domain packs (e.g. `event_engine-marketing_events`, `-sales_events`, `-user_events`)
declare events against `event_engine-event_definition` and each ships its own
committed `schema.json`. This gem aggregates those into one catalog.

---

## Mental model

```
domain packs (event_engine-event_definition)
    each commits its own db/…/schema.json
                    │
                    │  event_engine:schema:catalog
                    │  (aggregates publisher_schema_paths)
                    ▼
        db/event_schema.json  ◄── the committed catalog; commit it
                    │  Rails boot (Engine initializer)
                    ▼
            SchemaRegistry     ◄── in-memory, loaded once at boot
                    │  EventEngine.emit(:cow_fed, inputs: { cow: cow }, domain: :sales)
                    ▼
   EventBuilder builds a validated EventEngine::Event
                    │  EventEngine.dispatch(event)
                    ▼
        HandlerRegistry ──► every handler whose process_types match event.process_type
                             (event_engine-delivery / -store / -subscribers / your own)
```

Two things to internalize:

1. **The committed catalog — not any definition class — is the source of truth at
   runtime.** The engine reads `db/event_schema.json` at boot and reconstructs the
   registry from it. No Ruby is evaluated from a schema file. In production a missing
   catalog raises at boot.
2. **Building and handling are decoupled.** `EventEngine.dispatch` only fans the
   event out by `process_type`. This gem ships **no** handlers.

---

## What this gem assumes

Before anything works at runtime, these must be true — each is provided by another
part of the pipeline, not by this gem:

- **A committed `db/event_schema.json` exists** (the catalog). Aggregated from your
  packs' `schema.json` by [`event_engine:schema:catalog`](#rake-tasks), or contributed
  slice-by-slice at boot via [`register_slice!`](#contributing-events-from-a-pack).
  Missing at boot: **prod raises**, dev/test logs a warning and continues.
- **Events were declared elsewhere.** The DSL, compilation, and helper generation
  live in `event_engine-event_definition` + your domain packs. This gem only *reads*
  the compiled result.
- **At least one handler is registered** if you want emitted events to *do*
  something — a companion gem or [your own](#registering-a-handler). With none, the
  event is built and dispatched to no one (valid, just inert).

---

## Setup

```ruby
# Gemfile
gem "event_engine"
```

```bash
bundle install
```

### 1. Configure the runtime

```ruby
# config/initializers/event_engine.rb
EventEngine.configure do |config|
  # Where the aggregated catalog is read from at boot.
  config.schema_path = "db/event_schema.json"          # default

  # The packs whose committed schema.json feed the catalog task.
  config.publisher_schema_paths = [
    MarketingEvents::Engine.root.join("db/schema.json"),
    SalesEvents::Engine.root.join("db/schema.json")
  ]

  # Merged into every event's metadata (see Configuration).
  config.metadata_defaults = -> { { request_id: Current.request_id } }

  config.logger = Rails.logger                          # default
end
```

Every field is optional and has a default — see the [Configuration](#configuration)
table for exactly what each accepts.

### 2. Build (or contribute) the catalog

Aggregate your packs' committed `schema.json` into the one catalog the engine boots
from:

```bash
bin/rails event_engine:schema:catalog   # reads publisher_schema_paths → writes db/event_schema.json
```

**Commit `db/event_schema.json`.** Re-run and re-commit whenever a pack ships a new
schema. (Alternatively a pack can register its slice at boot — see
[Contributing events from a pack](#contributing-events-from-a-pack).)

### 3. Register a handler

Add a handler gem (`event_engine-delivery`, `-store`, `-subscribers`, …) **or**
register your own:

```ruby
# config/initializers/event_engine.rb (after the configure block)
EventEngine.register_handler(
  ->(event) { Rails.logger.info("[event] #{event.event_name} #{event.payload.inspect}") },
  process_types: :all
)
```

### 4. Emit

```ruby
EventEngine.emit(
  :cow_fed,
  inputs: { cow: cow },
  domain: :sales
)
```

---

## Emitting events

`EventEngine.emit` is the always-available runtime entry point. It looks the event up
in the registry, builds its payload from the inputs you pass (using the `from:`/`attr:`
mapping baked into the committed schema), stamps the envelope, and dispatches the
built event.

```ruby
event = EventEngine.emit(
  :cow_fed,
  inputs: { cow: cow, farmer: farmer },  # the declared inputs, by name

  domain: :sales,                        # scopes the lookup when an event name
                                         #   exists in more than one domain
  event_version: 2,                      # optional; defaults to the latest version
  occurred_at: Time.current,             # optional; defaults to Time.current
  metadata: { source: "import" },        # optional; merged over metadata_defaults
  idempotency_key: "cow-#{cow.id}",      # optional; defaults to a UUID
  aggregate_type: "Cow",                 # optional aggregate envelope fields
  aggregate_id: cow.id,
  aggregate_version: 3
)

event.payload        # => { weight: 500 }        (symbol-keyed, built from inputs)
event.process_type   # => :durable               (declared in the schema)
event.subject        # => :feeding               (declared in the schema)
```

`emit` returns the built-and-dispatched `EventEngine::Event`. Input validation
(missing required input, unknown input) raises `ArgumentError` at build time.

### Named helpers (`MarketingEvents.lead_created`)

The ergonomic per-event helpers live in the **domain packs**, generated by
`event_engine-event_definition`. This runtime does not generate them; at boot it will
`load db/event_engine_helpers.rb` **if a pack has committed one**, but it never
creates that file. If no helper file is present, use `EventEngine.emit` directly.

> Automatically routing a pack's generated helper through this runtime is the
> [publisher-adapter seam that is not wired yet](#not-wired-yet-tbd).

---

## Dispatch and `process_type`

`EventEngine.dispatch(event)` calls every registered handler whose `process_types`
match the event's own `process_type` (or that registered with `:all`). The
`process_type` is part of the event's committed schema, not chosen at emit time.

Known process types and the handler category each maps to:

| `process_type` | Handled by (category) |
|---|---|
| `inline`, `background` | subscribers |
| `durable`, `broker` | delivery |
| `telemetry` | telemetry |
| `sourced` | sourcing |

### Registering a handler

A handler is any object that responds to `#call(event)`.

```ruby
EventEngine.register_handler(MyHandler.new, process_types: %i[durable broker])
EventEngine.register_handler(->(event) { … }, process_types: :all)
```

`process_types:` is either `:all` or a list of `process_type` symbols the handler
wants. Companion gems register themselves this way from their own railties.

---

## Contributing events from a pack

Instead of (or in addition to) the catalog task, a pack can merge its committed
schema into the shared registry at boot. `register_slice!` is **additive** — each
pack's slice merges in without evicting the others:

```ruby
module MarketingEvents
  class Engine < ::Rails::Engine
    initializer "marketing_events.register_events" do
      config.after_initialize do
        EventEngine.register_slice!(schema_path: MarketingEvents::Engine.root.join("db/schema.json"))
      end
    end
  end
end
```

---

## Configuration

Set via `EventEngine.configure { |config| … }`. All fields are optional.

| Field | Default | Accepts | What it does |
|---|---|---|---|
| `schema_path` | `"db/event_schema.json"` | String / path | The committed catalog the engine loads at boot, and the file `event_engine:schema:catalog` writes. |
| `publisher_schema_paths` | `[]` | Array of paths | The packs' committed `schema.json` files that `event_engine:schema:catalog` aggregates into the catalog. |
| `metadata_defaults` | `nil` | A callable (`-> { Hash }`) | Called on each emit; its hash is merged **under** any call-site `metadata:` (call-site wins). A raising callable is swallowed and logged, so emission never breaks. |
| `logger` | `Rails.logger` | Any Logger | Where the engine logs (e.g. the missing-schema warning, a raising `metadata_defaults`). |

---

## The `Event`

`EventEngine::Event` is a keyword-init `Struct` with these members:

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
| `event_engine:schema:catalog` | Aggregates every path in `publisher_schema_paths` into the committed catalog at `schema_path`. Run and commit whenever a pack's schema changes. |
| `event_engine:catalog` | Prints a Markdown catalog of the loaded events and their subjects — a human-readable view of the current contract. |

---

## Not wired yet (TBD)

Honest gaps in the current runtime:

- **Publisher-adapter wiring — TBD.** The pipeline's join point is the publisher port
  `EventEngine::Definition.publisher` (defined in `event_engine-event_definition`): a
  pack's generated helper calls `publish(event_name, **envelope)` on it. This gem does
  **not** yet register itself as that publisher, so calling a generated pack helper
  does not automatically route through this runtime. Until the adapter lands, use
  `EventEngine.emit` directly, or have packs `register_slice!` their schema at boot.
  (This was deliberately out of scope of the authoring-removal work.)
- **Stale boot message — TBD.** When the catalog is missing, the engine's warning/error
  still names the removed `event_engine:schema:dump` task. Cosmetic; pending a message
  cleanup. It should point at `event_engine:schema:catalog`.
- **`the_local` guides — TBD.** The AI-assistant reference under
  `lib/event_engine/reference/` and the `the_local` subagents still describe the old
  in-gem DSL. They are generated provider docs (owned by `the_local-develop`) and will
  be regenerated to match this runtime.

---

## Development

```bash
bundle install
bundle exec rake test        # Minitest, via the dummy app in test/dummy
```

---

## License

Available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
