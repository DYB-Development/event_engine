# EventEngine

The **Rails host runtime** of the [EventEngine](https://github.com/DYB-Development) pipeline.

EventEngine is a schema-first event pipeline. Domain events are **declared** and
**compiled** into a committed contract by domain-pack gems (built on
[`event_engine-event_definition`](https://github.com/DYB-Development/event_engine-event_definition)).
This gem is the **runtime** a Rails app installs: it holds the schema registry,
**builds** a validated `EventEngine::Event` from the inputs a pack hands it, and
hands it to the **processor** its rules name.

This gem does **not** author events (that is `event_engine-event_definition` + your
domain packs) and does **not** deliver them (that is the processor gems below). It is
the middle of the pipe: inputs in, built event out, routed to a processor.

> **Status.** The authoring layer is fully extracted out of this gem, and the
> passive wiring is in place: the publisher adapter registers itself at boot and
> packs are discovered without per-pack host config. A host registers its
> processors and declares its [rules file](#declaring-how-events-are-processed) —
> nothing else.

---

## Where this gem sits

| Gem | Responsibility | Add it when |
|---|---|---|
| [`event_engine-event_definition`](https://github.com/DYB-Development/event_engine-event_definition) | The DSL, schema value objects, and the build step that turns definitions into a committed helper file + `schema.json`. No Rails. | A gem or app **declares** events |
| **`event_engine`** (this gem) | Catalog, build a validated event, route it to the processor its rules name | Always — it's the host runtime |
| `event_engine-delivery` | Transactional outbox, retries, dead-letters, transports (Kafka), dashboard | You need durable/broker delivery |
| `event_engine-store` | Durable append-only event log + replay & projections | You need a permanent record / event sourcing |
| `event_engine-subscribers`, `-telemetry`, `-sourced` | Processor gems for inline/background subscribers, telemetry, and event sourcing | You want that processing style |

Domain packs (e.g. `event_engine-marketing_events`, `-sales_events`, `-user_events`)
declare events against `event_engine-event_definition` and each ships its own
committed `schema.json` and helper module.

---

## How it fits together

A pack's generated helper does **not** emit. It forwards the raw inputs through a
**publisher port**; this gem is what turns those inputs into a real event and
routes it.

```
pack helper  (event_engine-event_definition)
    MarketingEvents.lead_created(lead: lead, …envelope)
          │  calls the publisher PORT (not emit):
          ▼
    EventEngine::Definition.publisher.publish(:lead_created, domain: :marketing,
                                               inputs: { lead: lead }, …envelope)
          ▼
    EventEngine::DefinitionPublisher           ◄── registered at boot, no host wiring
          │  EventEngine.emit(:lead_created, inputs: { lead: lead }, domain: :marketing, …)
          ▼
    EventBuilder builds the payload from each field's from:/attr:  ◄── catalog entry
          │  the rules file decides which processor handles it
          ▼
    the processor named by the rule
          (event_engine-delivery / -store / -subscribers / your own)
```

**`EventEngine.emit` is the official emit, and it lives here** — not in the pack. The
pack passes *inputs* (the whole objects you already have); this gem reads them via
the catalog entry's `from:`/`attr:` mapping to build the flat `payload`, stamps the
envelope, and routes it.

### The passive wiring

A host installs the gems and configures **nothing per pack**. Both halves self-wire:

1. **Emit routing** — at boot `event_engine` registers `DefinitionPublisher` as
   `EventEngine::Definition.publisher`, so every pack helper routes into
   `EventEngine.emit` automatically.
2. **Schema discovery** — a generated pack registers itself when required, so
   `event_engine:catalog` finds every pack's `schema.json` with no
   configuration. See [Building the catalog](#1-build-the-catalog).

What a host still decides for itself is **how** each event is processed, in the
[rules file](#declaring-how-events-are-processed).

---

## Getting started

```ruby
# Gemfile
gem "event_engine"
```

```bash
bundle install
```

### 1. Build the catalog

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

To build `db/event_schema.json` from your packs, run the catalog task — it finds
them without configuration:

```bash
bin/rails event_engine:catalog
```

This writes **two** files: the catalog itself, and the
[rules file](#declaring-how-events-are-processed) listing every event in it.

### Where the catalog's sources come from

`EventEngine.schema_sources` resolves what the catalog aggregates:

1. `config.publisher_schema_paths`, when you have set it — an explicit list always wins.
2. Otherwise, **every pack that has registered itself**. Packs generated by
   `event_engine-event_definition` call `EventEngine::Definition.register_pack(self)`
   when required, so requiring a pack is enough to make its `schema.json` discoverable.

Discovery is optional and degrades quietly: `event_engine` does not depend on
`event_engine-event_definition`, so with no packs loaded there is nothing to
discover and `schema_sources` returns the configured list (empty by default).

A host with packs in its Gemfile therefore needs no per-pack configuration:

```ruby
EventEngine.configuration.publisher_schema_paths  # => []
EventEngine.schema_sources                        # => ["/…/marketing/schema.json"]
```

### 2. Register your processors

A processor is anything responding to `#call(event)`, registered under a name. Add a
processor gem (`event_engine-delivery`, `-store`, `-subscribers`, …) **or** your own:

```ruby
# config/initializers/event_engine.rb
EventEngine.register_processor(:subscribers, SubscriberFanout.new)
EventEngine.register_processor(:audit, ->(event) { AuditLog.record(event) })
```

### 3. Declare how each event is processed

Name the processor for each event in `config/event_rules.yml` — see
[the rules file](#declaring-how-events-are-processed).

### 4. Emit

```ruby
EventEngine.emit(:cow_fed, inputs: { cow: cow }, domain: :sales)
```

Or, more usually, call the pack's generated helper — it routes here for you:

```ruby
MarketingEvents.lead_created(lead: lead)
```

---

## Emitting events

`EventEngine.emit` is the always-available entry point, and the target the publisher
adapter forwards to. It looks the event up in the catalog, builds its payload from
the inputs, stamps the envelope, routes it to its processor, and returns the built
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
event.process_type   # => :durable          (from the rules file)
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

## Declaring how events are processed

Every event in the catalog gets its processing declared in one file,
`config/event_rules.yml`. The catalog task writes it for you and keeps it in step
with the catalog.

```yaml
default: subscribers      # anything not named below
packs:
  marketing: subscribers  # every event in the marketing pack
  billing: ledger
events:
  invoice_voided: audit   # this one event
  lead_converted:         # catalogued but undecided
```

A rule names a **registered processor**. Resolution is **event → pack → default**,
and the resolved name is both the processor invoked and the value stamped on
`event.process_type`, so the two cannot disagree.

### Keeping it in step with the catalog

`bin/rails event_engine:catalog` writes this file alongside the catalog:

- every catalogued event appears, so a new event is visible rather than silently unrouted
- rules you have already decided are preserved
- `default` and `packs` are preserved

A newly catalogued event appears with no value. It falls through to its pack rule or
the default; if neither exists, emitting it raises rather than being dropped.

### When a rule is wrong

Both misconfigurations fail loudly and name the fix:

```
EventEngine::UnroutableEventError:
  no processing rule for event :lead_converted (pack :marketing);
  declare it in the rules file under events, packs, or default

EventEngine::UnregisteredProcessorError:
  the rule for event :lead_created (pack :marketing) names processor :ghost,
  but no processor is registered under that name
```

Declaring nothing at all is still valid: with an empty rules file no processor is
invoked and events are built and returned as before.

---

## Configuration

Set via `EventEngine.configure { |config| … }`. All fields are optional.

| Field | Default | Accepts | What it does |
|---|---|---|---|
| `schema_path` | `"db/event_schema.json"` | String / path | The committed catalog the engine loads at boot, and the file the catalog task writes. |
| `rules_path` | `"config/event_rules.yml"` | String / path | The processing rules the runtime loads, and the file the catalog task keeps in step. |
| `metadata_defaults` | `nil` | A callable (`-> { Hash }`) | Called on each emit; its hash is merged **under** any call-site `metadata:` (call-site wins). A raising callable is swallowed and logged, so emission never breaks. |
| `logger` | `Rails.logger` | Any Logger | Where the engine logs (missing-schema warning, a raising `metadata_defaults`). |
| `publisher_schema_paths` | `[]` | Array of paths | Pins the catalog task to an explicit list of `schema.json` files. Leave empty to discover registered packs. |

Processing is **not** configured here — it is declared in the
[rules file](#declaring-how-events-are-processed).

---

## The `Event`

`EventEngine::Event` is a keyword-init `Struct`:

```
event_name  event_type  event_version  process_type  subject  domain
payload  metadata  occurred_at  idempotency_key
aggregate_type  aggregate_id  aggregate_version
```

`Event.from(record)` rebuilds one from any object exposing those readers (symbolizing
the payload keys) — handy for processor gems reconstituting a persisted event.

---

## Rake tasks

| Task | What it does |
|---|---|
| `event_engine:catalog` | Builds the committed catalog at `schema_path` from every discovered pack (or from `publisher_schema_paths` when set), then keeps the rules file at `rules_path` in step with it. |


---

## Known gaps

- **Boot requires a committed `db/event_schema.json`.** The engine raises in
  production if it is missing. Building it is one task (`event_engine:catalog`),
  but it does have to be committed.
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
