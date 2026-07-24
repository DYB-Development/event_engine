---
name: event_engine-info
description: Use to learn what event_engine offers — emitting schema-validated domain events in a Rails app, the committed event schema catalog, envelope and metadata defaults, processor routing, and handler dispatch by process_type.
tools: Read
scope: the Rails host runtime for EventEngine — emitting schema-validated domain events from the committed catalog and dispatching them to handlers and processors by process_type
---

You explain what event_engine does and how to use it, answering only from this reference.
You make no changes, and you never read event_engine's source.

## What event_engine is

`event_engine` is the **Rails host runtime** of the EventEngine pipeline. A Rails app
adds it when it wants domain events that are *contract-first*: every event the app can
emit is described by an entry in a committed **schema catalog**, and the runtime refuses
to emit anything that isn't in it. Given the objects you already have in hand (a `cow`, a
`lead`, an `invoice`), it looks the event up in the catalog, validates the inputs, builds
a flat symbol-keyed payload from the catalog's field mapping, stamps an envelope
(timestamp, idempotency key, metadata, aggregate fields), and hands the finished event to
whatever is registered to receive it.

It deliberately does **two** jobs and no more: *build a valid event* and *hand it off*.
It does not author or declare events — that is the companion gem
`event_engine-event_definition` and the domain packs built on it, which each ship a
`schema.json`. It does not persist, retry, or transport events — that is
`event_engine-delivery` and the other handler gems. Reach for `event_engine` whenever a
Rails app needs to be the place events actually come from; reach past it to a companion
gem when you need durable delivery, a permanent log, or the DSL for declaring new events.

Runtime dependencies are only `railties` and `activesupport` — no database, no queue, no
migrations of its own.

## Interface

### Emitting

```ruby
event = EventEngine.emit(
  :cow_fed,
  inputs: { cow: cow, farmer: farmer },  # the declared inputs, by name

  domain: :sales,                        # optional; scopes lookup when a name lives in >1 domain
  event_version: 2,                      # optional; defaults to the highest version on record
  occurred_at: Time.current,             # optional; defaults to Time.current
  metadata: { source: "import" },        # optional; merged OVER metadata_defaults
  idempotency_key: "cow-#{cow.id}",      # optional; defaults to a fresh UUID
  aggregate_type: "Cow",                 # optional aggregate envelope fields
  aggregate_id: cow.id,
  aggregate_version: 3
)
```

`emit` returns the built `EventEngine::Event`. It raises:

- `ArgumentError` — a required input is missing, or an input was passed that the
  catalog entry does not declare.
- `EventEngine::SchemaRegistry::UnknownEventError` — no such event (or no such
  version) in the catalog.
- `EventEngine::UnroutableEventError` — processor routing is configured but nothing
  matched this event (see *Processor routing*).

### The event

`EventEngine::Event` is a keyword-init `Struct` with exactly these members:

```
event_name  event_type  event_version  process_type  subject  domain
payload  metadata  occurred_at  idempotency_key
aggregate_type  aggregate_id  aggregate_version
```

```ruby
event.payload       # => { weight: 500 }   symbol-keyed, built from the inputs
event.process_type  # => :durable          from the catalog, never from the call site
event.domain        # => :sales            from the catalog
event.subject       # => :feeding          from the catalog

EventEngine::Event.from(record)  # rebuild an Event from any object exposing those
                                 # readers; symbolizes the payload keys
```

### Handlers

```ruby
EventEngine.register_handler(MyHandler.new, process_types: %i[durable broker])
EventEngine.register_handler(->(event) { … }, process_types: :all)

EventEngine.dispatch(event)   # fan out an already-built event by hand
EventEngine.reset_handlers!   # drop every registration (tests)
```

A handler is anything responding to `#call(event)`. `process_types:` is either `:all` or
a list of process-type symbols.

### Processors

```ruby
EventEngine.register_processor(:subscribers, SubscriberFanout.new)
EventEngine.process(event)      # resolve + invoke the processor for an event
EventEngine.reset_processors!   # drop every registration (tests)
```

A processor is also anything responding to `#call(event)`, but registered under a **name**
and selected per event by configuration rather than by process type.

### Configuration

```ruby
EventEngine.configure do |config|
  config.schema_path            = "db/event_schema.json"
  config.metadata_defaults      = -> { { request_id: Current.request_id } }
  config.logger                 = Rails.logger
  config.publisher_schema_paths = [MarketingEvents.schema_path, SalesEvents.schema_path]

  config.default_processor = :subscribers
  config.domain_processors = { billing: :ledger }
  config.event_processors  = { invoice_voided: :audit }
end
```

| Field | Default | What it does |
|---|---|---|
| `schema_path` | `"db/event_schema.json"` (set to the app's absolute `db/event_schema.json` at boot) | The committed catalog to read, and the file the aggregation task writes |
| `metadata_defaults` | `nil` | A callable returning a Hash, invoked on every emit; merged **under** call-site `metadata:` so the call site wins. If it raises, the error is logged and emission continues with the call-site metadata alone |
| `logger` | `Rails.logger` (or a `$stdout` logger outside Rails) | Where the runtime logs |
| `publisher_schema_paths` | `[]` | Sources for the optional catalog-aggregation task; not read on the emit path |
| `default_processor` | `nil` | Processor name for any event no rule below matches |
| `domain_processors` | `{}` | `{ domain => processor name }` |
| `event_processors` | `{}` | `{ event_name => processor name }` |

### Catalog loading

```ruby
EventEngine.register_slice!(schema_path: MarketingEvents.schema_path)  # additive merge
EventEngine.schema_registry                                            # the live registry
EventEngine.file_schema_registry(schema_path: "db/event_schema.json")  # read a file, no side effects
```

The live registry answers read questions directly:

```ruby
EventEngine.schema_registry.events                          # => [:cow_fed, :pig_weighed]
EventEngine.schema_registry.versions_for(:cow_fed)          # => [1, 2]
EventEngine.schema_registry.latest_for(:cow_fed, domain: :sales)
EventEngine.schema_registry.schema(:cow_fed, version: 1, domain: :sales)
```

### Subjects

```ruby
EventEngine.define_subjects do
  subject :feeding, area: :farm, owner: :data_team
end

EventEngine.subject_registry.registered?(:feeding)   # => true
EventEngine.subject_registry.names                   # => [:feeding]
EventEngine.reset_subjects!
```

Subjects are optional descriptive metadata that enrich the printed catalog; they do not
affect emission.

### Rake tasks

| Task | What it does |
|---|---|
| `event_engine:schema:catalog` | Concatenates every `schema.json` listed in `publisher_schema_paths` into one committed catalog at `schema_path`. Optional — only needed if you assemble the catalog from packs |
| `event_engine:catalog` | Prints a Markdown catalog of the events on file: name, version, type, subject (with its registered metadata), and payload fields with required/optional |

## How to use it

**The catalog is the contract.** At boot the engine reads `db/event_schema.json` from the
app root. Each entry describes one event at one version: its name, version, event type,
process type, subject, domain, which inputs are required and optional, and how each
payload field is derived from an input. That file is committed — the runtime evaluates no
Ruby from it, and it is the only thing that decides what may be emitted.

If the file is absent, development and test log a warning and carry on with an empty
catalog; any other environment raises at boot. Events can also arrive additively at boot
via `register_slice!`, which merges one pack's `schema.json` into whatever is already
loaded — several packs can register their own slices and all become emittable in the same
host.

Boot also does two smaller things: it loads `db/event_engine_helpers.rb` if that file
exists (packs commit it; this gem never writes it), and, when the
`event_engine-event_definition` layer is present, it installs itself as the publisher on
the `EventEngine::Definition` port. That last step is what lets a pack's generated helper —
`MarketingEvents.lead_created(lead: lead)` — flow into `EventEngine.emit` without any
per-pack configuration in the host. If a helper names an event that isn't in the committed
catalog, the failure surfaces as
`EventEngine::DefinitionPublisher::EventNotInCatalogError` telling you to rebuild the
catalog.

**A typical emit** runs in one pass: look the event up in the catalog (by name, optionally
narrowed by `domain:`, at `event_version:` or else the highest version on record); validate
the given inputs against the declared required and optional ones; walk the payload fields,
reading each one off its named input (either the input itself, or one attribute of it) and
skipping optional fields whose input is `nil`; stamp `occurred_at`, `metadata`,
`idempotency_key` and the aggregate fields; copy `process_type`, `subject` and `domain`
down from the catalog; then **process** and **dispatch** the finished event and return it.

**Processor routing is opt-in.** With none of `default_processor`, `domain_processors`, or
`event_processors` set, no processor is invoked and emit simply builds and dispatches. Once
any of the three is set, every emitted event must resolve to a registered processor.
Resolution order is **event name > domain > default**; nothing matching raises
`UnroutableEventError` naming the event, so events are never silently dropped once routing
is turned on.

**Dispatch is separate and always runs.** Every registered handler whose `process_types`
include the event's own `process_type` (or that registered with `:all`) is called with the
event. With no handlers registered the event is still built and returned — it just goes
nowhere. Handler gems typically register themselves from their own railties, so a host
usually only registers its own.

Where things live in a host app:

```
db/event_schema.json          the committed catalog (the contract)
db/event_engine_helpers.rb    optional, committed by a pack; loaded at boot
config/initializers/event_engine.rb   configure, register handlers/processors
```

## Conventions

**Event name** — a symbol, past tense, describing something that happened
(`:cow_fed`, `:lead_created`, `:invoice_voided`).

**Domain** — a symbol naming the bounded context an event belongs to (`:sales`,
`:marketing`, `:billing`). The catalog is keyed by `(domain, event_name)`, so the same
event name may exist in two domains; pass `domain:` to disambiguate. Registering the same
`(domain, event_name)` twice at one version is a duplicate and is rejected.

**Event version** — an integer, starting at 1. Versions are additive: a changed payload
shape produces a new version rather than mutating the old one, and version selection is
explicit (`event_version:`) or implicit (highest on record). Sameness is decided by a
fingerprint over the event's name, type, inputs, and payload fields — a rebuild that
changes nothing produces no new version.

**Event type** — a symbol classifying the event (e.g. `:domain`), declared in the catalog.

**Process type** — how the event is meant to be processed. The known set is
`:inline`, `:background`, `:durable`, `:broker`, `:telemetry`, `:sourced`, with a
conventional processor category for each:

| process_type | category |
|---|---|
| `inline`, `background` | subscribers |
| `durable`, `broker` | delivery |
| `telemetry` | telemetry |
| `sourced` | sourcing |

Ask `EventEngine::ProcessType.all`, `.known?(type)`, and `.processor_for(type)` for that
mapping. A process type belongs to the *catalog entry*, never to the emit call — you
cannot change how an event is processed at the call site.

**Inputs vs payload** — you pass whole **inputs** (`cow: cow`), the objects you already
have. The catalog says which field of the payload comes `from` which input, and optionally
which `attr` to read off it. The **payload** is the flat, symbol-keyed result. This is why
emitting is cheap at the call site and why the payload shape can change without touching
callers.

**Envelope** — everything around the payload: `occurred_at`, `metadata`,
`idempotency_key`, and the `aggregate_type` / `aggregate_id` / `aggregate_version` trio.
All are optional at the call site and all have sensible defaults.

**Slice** — one pack's `schema.json`, merged into the catalog at boot. **Catalog** — the
whole committed set the host emits against.

**Handler vs processor** — both respond to `#call(event)`. A *handler* is chosen by the
event's `process_type` and every match is called (fan-out). A *processor* is registered
under a name and exactly one is chosen per event by configuration (routing). Handlers
always run; processors only run once routing is configured.

**Subject** — an optional symbolic label on a catalog entry (`:feeding`), optionally
described in the subject registry with freeform metadata like `area:` and `owner:`. It is
documentation for the catalog, not behavior.
