## EventEngine

> **DO NOT** explore the event_engine gem source code. This reference is the
> complete user-facing API, embedded verbatim into every event_engine local so
> their guidance never drifts. Keep it the single source of truth.

EventEngine is a Rails engine for defining domain events as declarative classes,
compiling them to a committed schema, emitting them through generated helpers, and
dispatching them to registered handlers. Core builds and routes events; it ships no
handlers of its own. Durable delivery, an event store, and ready-made subscriber
classes are separate companion gems (`event_engine-delivery`, `event_engine-store`,
`event_engine-subscribers`) — this reference covers core only.

### Interface

The complete public surface — every entry point with its exact signature, so a
local answers from here instead of reading source.

**Event-definition DSL** — class methods available inside an
`EventEngine::EventDefinition` subclass placed in `app/event_definitions/`:

```ruby
event_name(:symbol)                        # required — the event's identity; becomes EventEngine.<name>
event_type(:symbol)                        # required — classification, e.g. :domain
process_type(:symbol)                      # optional — routing type; set it explicitly
input(:name)                               # an input the emit helper must receive
optional_input(:name)                      # an input the emit helper may receive
required_payload(name, from:, attr: nil)   # payload field; from: names an input, attr: is read on it
optional_payload(name, from:, attr: nil)   # same, but omitted when the source input is nil
```

`from:` must reference a declared input; `attr:` is the method read on that input
(`nil` passes the input through). Duplicate input names raise `ArgumentError`.

**process_type** — core stamps this symbol onto every emitted event but does not act
on it. Which handlers receive an event is decided by each handler's `process_types:`.
The six values:

| value | intent |
|---|---|
| `:inline` | handled in-process, synchronously |
| `:background` | handled in-process, via a background job |
| `:durable` | handled when a durable outbox drains |
| `:broker` | published to an external transport |
| `:telemetry` | metrics / observability handlers |
| `:sourced` | an append-only event store |

The companion gems register the handlers that give `:durable`, `:broker`, `:sourced`,
etc. their behavior; core just routes to whatever is registered. If `process_type`
is omitted it is `nil` — set it explicitly so routing intent is clear.

**Runtime (module-level)** — booting installs one `EventEngine.<event_name>` helper
per event; the rest are always available:

```ruby
EventEngine.<event_name>(**inputs,        # declared inputs, by name
  event_version: nil,                      # optional, defaults to the latest schema version
  occurred_at: nil,                        # optional, defaults to Time.current
  metadata: nil,                           # optional
  idempotency_key: nil,                    # optional, defaults to a UUID
  aggregate_type: nil, aggregate_id: nil, aggregate_version: nil) # optional
#   Emits the event: validates inputs, builds the payload, dispatches. Missing a
#   required input, or passing an unknown one, raises ArgumentError. payload is symbol-keyed.

EventEngine.register_handler(handler, process_types:)  # process_types: [ :inline, … ] or :all
#   handler is any object responding to call(event). Handlers run synchronously in
#   registration order; if one raises, the rest don't run.

EventEngine.dispatch(event)     # fan an event out to registered handlers (emit helpers call this)
EventEngine.reset_handlers!     # clear all registered handlers
EventEngine.configure { |config| config.logger = Rails.logger }  # config exposes logger only
```

**Schema workflow** — definitions compile to a committed `db/event_schema.rb`, which
is authoritative at boot:

```bash
bin/rails event_engine:schema:dump    # compile definitions → db/event_schema.rb
bin/rails event_engine:schema_check   # CI: fail if definitions drift from the file
```

A new event is version 1; changing an event's identity or payload bumps its version.
Changing only `process_type` does not bump the version.

### Recipe

Define an event, compile it, register a handler, and emit — the complete common task,
copy-paste and rename:

```ruby
# app/event_definitions/cow_fed.rb
class CowFed < EventEngine::EventDefinition
  event_name :cow_fed        # the event's identity (required)
  event_type :domain         # classification (required)
  process_type :durable      # routing type (set explicitly)

  input :cow                 # a required input
  optional_input :farmer     # an optional input

  required_payload :weight,      from: :cow,    attr: :weight
  optional_payload :farmer_name, from: :farmer, attr: :name
end
```

```bash
bin/rails event_engine:schema:dump    # compile → db/event_schema.rb, then commit the file
```

```ruby
# a handler is any object responding to call(event); keep it idempotent
class WeighingLog
  def call(event)
    Rails.logger.info("cow weighed #{event.payload[:weight]}kg")
  end
end

EventEngine.register_handler(WeighingLog.new, process_types: [:durable])

# emit through the generated helper, passing the declared inputs
EventEngine.cow_fed(cow: cow, farmer: farmer, occurred_at: Time.current)
```

### Install

1. Add the gem and install: `gem "event_engine"`, then `bundle install`.
2. Run `bin/rails g event_engine:install` — creates `db/event_schema.rb` and
   `config/initializers/event_engine.rb`.
3. Define events as classes in `app/event_definitions/`.
4. Run `bin/rails event_engine:schema:dump` and commit `db/event_schema.rb`.
5. Set `config.logger` in the initializer if you want something other than the default.

Durable delivery, an event store, and prebuilt subscriber classes are separate gems
(`event_engine-delivery`, `event_engine-store`, `event_engine-subscribers`); add them
when you need them and follow their own setup.

### Conventions

- Define one `EventDefinition` class per event in `app/event_definitions/`; never
  hand-build event hashes.
- Build payloads from inputs with `required_payload`/`optional_payload`; don't pass
  raw payload hashes to the emit helper.
- Always set `process_type` explicitly so routing intent is clear.
- Emit only through the generated `EventEngine.<event_name>` helpers, passing the
  declared inputs.
- Re-run `event_engine:schema:dump` and commit `db/event_schema.rb` after any
  definition change; keep `event_engine:schema_check` green in CI.
- Keep handlers and subscribers idempotent.
