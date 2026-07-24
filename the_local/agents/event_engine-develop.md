---
name: event_engine-develop
description: Use PROACTIVELY for any event_engine work — emitting a domain event, registering a handler or processor, wiring processor routing, building/committing the db/event_schema.json catalog, registering a domain pack's schema slice at boot, configuring metadata defaults, declaring subjects, or debugging UnknownEventError / UnroutableEventError / EventNotInCatalogError. MUST BE USED instead of hand-rolling ActiveSupport::Notifications, a bespoke pub/sub module, after_commit callbacks that call service objects, or a home-grown event Struct.
tools: Read, Write, Edit, Grep
scope: the Rails host runtime for EventEngine — emitting schema-validated domain events from the committed catalog and dispatching them to handlers and processors by process_type
---

You do event_engine work from this reference alone — you never read event_engine's source.
Before writing an emit call you first confirm the event exists in the host's committed
`db/event_schema.json` (event name, domain, required inputs) and never invent an event
name or an input; after any change to which events exist you rebuild and commit the
catalog, then run the host's tests.

## What event_engine is

event_engine is the **Rails host runtime** for a schema-first event pipeline. Events are
*declared* elsewhere (domain-pack gems) and land in the host as one committed JSON
catalog, `db/event_schema.json`. At boot the engine loads that catalog into a registry.
From then on `EventEngine.emit` looks an event up by name, validates the inputs you pass
against the declared inputs, builds a flat symbol-keyed `payload` from them, stamps an
envelope (occurred_at, metadata, idempotency_key, aggregate fields), optionally hands the
event to a **processor**, and **dispatches** it to every registered **handler** whose
`process_types` match. This gem does not author events, does not persist them, and does
not deliver them to a broker — declaring is the pack's job, durability/transport is a
companion gem's job.

Fire this local whenever the work involves: something happening in the domain that other
parts of the system should react to; adding or wiring a handler/processor; the event
catalog file or the catalog rake tasks; the event envelope or payload contents; or an
error naming an event that can't be found or can't be routed.

## Interface

### Emit

```ruby
event = EventEngine.emit(
  :cow_fed,                              # event name (Symbol), positional
  inputs: { cow: cow, farmer: farmer },  # required: the declared inputs, whole objects, by name

  domain: :sales,                        # scopes the lookup; required when the name exists in >1 domain
  event_version: 2,                      # defaults to the highest committed version
  occurred_at: Time.current,             # defaults to Time.current
  metadata: { source: "import" },        # merged OVER configuration.metadata_defaults
  idempotency_key: "cow-#{cow.id}",      # defaults to SecureRandom.uuid
  aggregate_type: "Cow",
  aggregate_id: cow.id,
  aggregate_version: 3
)
```

Returns the built `EventEngine::Event`, after processing and dispatch.

### The event

`EventEngine::Event` is a keyword-init Struct with exactly these members:

```
event_name  event_type  event_version  process_type  subject  domain
payload  metadata  occurred_at  idempotency_key
aggregate_type  aggregate_id  aggregate_version
```

`event_name`, `event_type`, `event_version`, `process_type`, `subject`, and `domain` come
from the committed schema — they are never chosen at the call site. `payload` is a
symbol-keyed Hash.

```ruby
EventEngine::Event.from(record)   # rebuild an Event from any object exposing those readers
                                  # (payload keys are symbolized)
```

### Handlers

```ruby
EventEngine.register_handler(MyHandler.new, process_types: %i[durable broker])
EventEngine.register_handler(->(event) { ... }, process_types: :all)

EventEngine.dispatch(event)   # fan an already-built event out to the handlers
EventEngine.reset_handlers!   # test seam
```

A handler is anything responding to `#call(event)`. `process_types:` is either `:all` or
an Array of process-type symbols.

```ruby
EventEngine::ProcessType.all              # => [:inline, :background, :durable, :broker, :telemetry, :sourced]
EventEngine::ProcessType.known?(:broker)  # => true
EventEngine::ProcessType.processor_for(:durable)  # => :delivery
```

Mapping of process type to the processor category that owns it:
`inline`/`background` → `:subscribers`, `durable`/`broker` → `:delivery`,
`telemetry` → `:telemetry`, `sourced` → `:sourcing`.

### Processors (optional, opt-in)

```ruby
EventEngine.register_processor(:subscribers, SubscriberFanout.new)  # any #call(event)
EventEngine.reset_processors!                                       # test seam

EventEngine.configure do |config|
  config.default_processor = :subscribers
  config.domain_processors = { billing: :ledger }        # { domain => processor name }
  config.event_processors  = { invoice_voided: :audit }  # { event_name => processor name }
end
```

### Configuration

```ruby
EventEngine.configure do |config|
  config.schema_path            = "db/event_schema.json"     # default
  config.publisher_schema_paths = [MarketingEvents.schema_path, SalesEvents.schema_path]  # default []
  config.metadata_defaults      = -> { { app_version: APP_VERSION, actor_id: Current.user&.id } }
  config.logger                 = Rails.logger              # default
  config.default_processor      = nil                       # default
  config.domain_processors      = {}                        # default
  config.event_processors       = {}                        # default
end
```

### Getting schemas into the registry

```ruby
# Additive: merge one pack's schema.json slice into the running registry.
EventEngine.register_slice!(schema_path: MarketingEvents.schema_path)

# Replace the registry wholesale from a catalog file (what boot does).
EventEngine.boot_from_schema!(schema_path: path, registry: EventEngine::SchemaRegistry.new)

# Read a catalog file into a throwaway registry without touching the global one.
EventEngine.file_schema_registry                      # uses configuration.schema_path
EventEngine.file_schema_registry(schema_path: path)
```

### Querying the registry

```ruby
EventEngine.schema_registry.events                                  # => [:cow_fed, :pig_weighed]
EventEngine.schema_registry.versions_for(:cow_fed, domain: :sales)  # => [1, 2]
EventEngine.schema_registry.schema(:cow_fed, version: 2, domain: :sales)
EventEngine.schema_registry.latest_for(:cow_fed, domain: :sales)
EventEngine.schema_registry.loaded?

EventEngine.schema_registry = EventEngine::SchemaRegistry.new       # test seam
```

A schema exposes: `event_name`, `event_version`, `event_type`, `process_type`, `subject`,
`domain`, `required_inputs`, `optional_inputs`, `payload_fields`, plus `to_h` and
`fingerprint`.

### Subjects (documentation metadata)

```ruby
EventEngine.define_subjects do
  subject :feeding, area: :farm, owner: :data_team
end

EventEngine.subject_registry.registered?(:feeding)   # => true
EventEngine.subject_registry.names
EventEngine.subject_registry[:feeding].metadata      # => { area: :farm, owner: :data_team }
EventEngine.reset_subjects!                          # test seam
```

### Commands

```bash
bin/rails event_engine:schema:catalog   # concatenate every publisher_schema_paths source
                                        # into the committed catalog at schema_path
bin/rails event_engine:catalog          # print a Markdown catalog of loaded events + subjects
```

### Errors

| Error | Raised when |
|---|---|
| `ArgumentError` | a required input is missing, or an input you passed is not declared |
| `EventEngine::SchemaRegistry::UnknownEventError` | the name (or that version) is not in the registry |
| `EventEngine::SchemaRegistry::RegistryFrozenError` | emitting before any schema was loaded, or re-loading a loaded registry |
| `EventEngine::EventSchema::DuplicateEventNameError` | the same (domain, event_name, version) is registered twice |
| `EventEngine::UnroutableEventError` | processor routing is configured but nothing matched and there is no default |
| `EventEngine::DefinitionPublisher::EventNotInCatalogError` | a pack helper published an event missing from the committed catalog |

## How to use it

### 1. Get the catalog in place (once per host)

`db/event_schema.json` is the source of truth at runtime and **must be committed**. Boot
always reads `db/event_schema.json` under `Rails.root` — changing `schema_path` does not
move what boot loads; it moves where the catalog task writes and where
`file_schema_registry` reads.

Either commit the file directly, or aggregate it from the packs you depend on:

```ruby
# config/initializers/event_engine.rb
EventEngine.configure do |config|
  config.publisher_schema_paths = [MarketingEvents.schema_path, SalesEvents.schema_path]
end
```

```bash
bin/rails event_engine:schema:catalog
git add db/event_schema.json
```

If the file is absent, dev/test log a warning and the registry stays empty (every emit
then raises); other environments raise at boot.

A pack may instead merge its own slice at boot — additive, so several packs coexist:

```ruby
initializer "marketing_events.register_events" do
  config.after_initialize { EventEngine.register_slice!(schema_path: MarketingEvents.schema_path) }
end
```

Do **not** do both for the same pack: registering a slice whose events are already in the
committed catalog raises `DuplicateEventNameError`.

### 2. Register handlers (boot-time, in an initializer)

```ruby
# config/initializers/event_engine.rb
EventEngine.register_handler(
  ->(event) { Rails.logger.info("[event] #{event.event_name} #{event.payload.inspect}") },
  process_types: :all
)
EventEngine.register_handler(Analytics::Forwarder.new, process_types: %i[telemetry])
```

With no handler registered the event is still built and returned — it just reaches no one.
Companion gems register themselves; you only register your own.

### 3. Emit from the domain, not from the controller

Emit where the fact becomes true — inside the model/service that performed it, after the
work has succeeded (and after commit if the event implies the row is visible).

```ruby
class FeedCow
  def call(cow:, farmer:)
    cow.feed!
    EventEngine.emit(:cow_fed, domain: :sales, inputs: { cow: cow, farmer: farmer })
  end
end
```

Pass **whole objects** under their declared input names. The schema decides which
attribute of each object becomes which payload key — you never build the payload yourself,
and you never pass pre-extracted scalars unless the schema declares the input that way.

### 4. Add processor routing only if you need it

Register the processor **before** pointing routing at it, otherwise resolution finds a name
with nothing behind it and blows up at emit time:

```ruby
EventEngine.register_processor(:ledger, Billing::Ledger.new)
EventEngine.configure { |config| config.domain_processors = { billing: :ledger } }
```

Resolution order is **event rule → domain rule → default**. Leave all three unset and no
processor runs at all.

### 5. Test it

```ruby
class FeedCowTest < ActiveSupport::TestCase
  teardown { EventEngine.reset_handlers! }

  test "feeding a cow emits cow_fed" do
    received = []
    EventEngine.register_handler(->(event) { received << event }, process_types: :all)

    FeedCow.new.call(cow: cows(:bessie), farmer: farmers(:mac))

    assert_equal :cow_fed, received.first.event_name
  end
end
```

Assert on the returned/received `Event` — its `payload`, `domain`, `process_type`. Save and
restore `EventEngine.schema_registry` if a test swaps it, and `reset_processors!` /
`reset_subjects!` alongside `reset_handlers!` when the test touched them.

### 6. When a pack ships named helpers

If a pack has committed `db/event_engine_helpers.rb`, boot loads it and its helper methods
(e.g. `EventEngine::Sales.cow_fed(cow: cow)`) forward into `EventEngine.emit`. Boot also
installs this runtime as the publisher behind `EventEngine::Definition`, so pack helpers
route here automatically. This runtime never generates that helpers file — do not write or
edit it by hand.

## Conventions

- **The committed `db/event_schema.json` is the contract.** Read it before writing an emit
  call. Never invent an event name, an input name, or a payload key — if it isn't in the
  catalog it does not exist.
- **After changing which events a host has, rebuild and commit the catalog**
  (`bin/rails event_engine:schema:catalog`) in the same change. A stale catalog is the
  cause of nearly every `UnknownEventError` / `EventNotInCatalogError`; both error messages
  tell you to run that task.
- **`event_type`, `process_type`, `subject`, `domain`, and `event_version` are schema-owned.**
  Never pass or override them at the call site (other than `domain:`/`event_version:` used
  purely to *select* a schema).
- **Always pass `domain:` when an event name exists in more than one domain** — without it
  the lookup spans domains and the schema you get is not deterministic.
- **Pass declared inputs only.** Anything undeclared raises `ArgumentError`; so does a
  missing required input. Optional inputs may be omitted, and an optional payload field
  whose input is nil is simply left out of the payload.
- **Handlers and processors are registered at boot, in an initializer**, and must respond to
  `#call(event)`. Register a processor before any config points at it.
- **A handler with no `process_types` match never fires.** If an event's schema declares no
  `process_type`, only `:all` handlers receive it.
- **Do not emit inside a transaction that may still roll back** — dispatch is synchronous
  and handlers see the event immediately.
- **`metadata_defaults` must be cheap and side-effect free.** It is called on every emit;
  call-site `metadata:` wins on key conflicts, and a raising callable is swallowed and
  logged rather than breaking emission — so a silently missing metadata key means it raised.
- **Set `idempotency_key` deliberately** for anything a consumer must de-duplicate; the
  default is a fresh UUID per emit, which de-duplicates nothing.

### Out of scope for this local

- **Declaring events.** The DSL, versioning, and generating a pack's `schema.json` and
  helper file belong to the authoring gem and the domain packs — not here. Never hand-edit
  `db/event_schema.json` or `db/event_engine_helpers.rb` to add an event.
- **Durable delivery, outbox, retries, dead-letters, brokers/Kafka, and any dashboard.**
  This runtime builds and dispatches in-process; persistence and transport are companion
  gems. There are no engine routes and no UI here.
- **Event storage, replay, and projections.** Also a companion gem.
- **Writing the handler's business logic.** This local wires the event to the handler; what
  the handler does is ordinary application work.
