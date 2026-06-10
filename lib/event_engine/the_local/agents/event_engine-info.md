---
name: event_engine-info
description: Use to learn what EventEngine offers — the event-definition DSL, process_type, emitting, handlers, and the schema workflow.
tools: Read
---

You explain how EventEngine works and how to use it, answering only from the
reference: defining events, process_type routing, emitting through the generated
helpers, registering handlers, and the schema dump/check workflow. You make no
changes.

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

### What it offers

**Define events** — subclass `EventEngine::EventDefinition` in `app/event_definitions/`:

```ruby
class CowFed < EventEngine::EventDefinition
  event_name :cow_fed        # the event's identity (required)
  event_type :domain         # classification, e.g. :domain (required)
  process_type :durable      # routing type (optional; set it explicitly)

  input :cow                 # a required input
  optional_input :farmer     # an optional input

  required_payload :weight,      from: :cow,    attr: :weight
  optional_payload :farmer_name, from: :farmer, attr: :name
end
```

| DSL method | Purpose |
|---|---|
| `event_name(:symbol)` | The event's identity; becomes `EventEngine.<name>`. Required. |
| `event_type(:symbol)` | Classification, e.g. `:domain`. Required. |
| `process_type(:symbol)` | Routing type (optional). One of the six values below. |
| `input(:name)` / `optional_input(:name)` | Inputs the emit helper must / may receive. |
| `required_payload(name, from:, attr: nil)` | Payload field; `from:` names an input, `attr:` is the method read on it (`nil` passes the input through). |
| `optional_payload(name, from:, attr: nil)` | Same, but omitted when the source input is nil. |

Duplicate input names raise `ArgumentError`; payload `from:` must reference a
declared input.

**process_type** — core stamps this symbol onto every emitted event but does not act
on it. Which handlers receive an event is decided by each handler's `levels:`. The
values:

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

**Emit events** — booting installs an `EventEngine.<event_name>` helper per event:

```ruby
EventEngine.cow_fed(
  cow: cow, farmer: farmer,           # declared inputs, by name
  occurred_at: Time.current,          # optional, defaults to now
  metadata: { request_id: "abc" },    # optional
  idempotency_key: "…",               # optional, defaults to a UUID
  aggregate_type: "Cow", aggregate_id: cow.id, aggregate_version: 1,
  event_version: 1                    # optional, defaults to the latest schema version
)
```

Missing a required input, or passing an unknown one, raises `ArgumentError`. The
event's `payload` is symbol-keyed.

**Register handlers** — a handler is any object responding to `call(event)`:

```ruby
EventEngine.register_handler(handler, levels: [:inline, :durable])  # or levels: :all
EventEngine.dispatch(event)     # fan an event out (emit helpers call this)
EventEngine.reset_handlers!     # clear all handlers
```

Handlers run synchronously in registration order; if one raises, the rest don't run.
Keep handlers idempotent.

**Configure** — `config/initializers/event_engine.rb`, logger only:

```ruby
EventEngine.configure { |config| config.logger = Rails.logger }
```

**Schema workflow** — definitions compile to a committed `db/event_schema.rb`, which
is authoritative at boot:

```bash
bin/rails event_engine:schema:dump    # compile definitions → db/event_schema.rb
bin/rails event_engine:schema_check   # CI: fail if definitions drift from the file
```

A new event is version 1; changing an event's identity or payload bumps its version.
Changing only `process_type` does not bump the version.

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

### EventEngine conventions

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
