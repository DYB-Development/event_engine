# Plan: event processing model (replacing numeric levels)

Status: proposed. This is a design + migration plan, not yet implemented.

## Why

`event_level` (an integer, 1–5) hides several independent concerns behind one
ordinal:

- It implies a magnitude ("4 > 3") when the rungs are different infrastructure
  with different guarantees, not "more of the same."
- `event_level 4` means nothing without a lookup table.
- It forces **one** rung per event, when an event often wants several kinds of
  processing at once (e.g. record durably **and** feed telemetry).
- It folds in things that aren't delivery at all — telemetry, event sourcing —
  as if they were a "delivery level."

How that strain shows up in the current code:

- The integer is decoded in **two** places: `Delivery::Handler#call` (`1 / 2 /
  else`) and `OutboxRouter#route` (`3 / 4 / 5 / else`). The boundaries are
  implicit; `else` silently swallows 3, 4, 5, and `nil`.
- An omitted level is `nil` and falls through to the outbox path — a surprising
  default.
- Subscriber abstractions (`Subscriber`, `SubscriberRegistry`) live in **core**,
  but subscriber *execution* (levels 1 and 2) lives in **event_engine-delivery**.
  So you must install the durable-delivery gem to run an in-process subscriber
  that has nothing to do with the outbox or a broker.
- Level 5 ("event sourcing") just raises — it never fit, because sourcing is a
  recording concern, not a delivery one.

## Target model: processing, not levels

An event declares **how it should be processed**. The work is done by
**processors**, each a gem that registers a handler with core and self-selects
the events tagged for it. Core is a pure bus.

Two structural facts drive the shape:

1. **Processing is combinable.** An event can be processed by several processors
   (delivered durably, recorded, and fed to telemetry). So an event carries a
   *set* of processing intents, not a single symbol.
2. **A processor may have graded modes.** Delivery is a strict capability ladder;
   the others are on/off (or carry their own descriptor).

### Core is the bus only

Core owns: event definitions, the schema + dump/version workflow, the emit
helpers, the `Event`, and `register_handler` / `dispatch`. Core ships **no**
processors and **no** subscriber machinery. A telemetry-only app pulls in nothing
it doesn't use.

### Processors (each its own gem)

| processor | gem | what it does |
|---|---|---|
| in-process subscribers | (new — extracted from delivery) | runs `Subscriber#handle` in this app, inline or in a job |
| delivery | event_engine-delivery | transactional outbox + handoff to a broker |
| record / sourcing | event_engine-store (+ future sourcing) | append-only log, replay, projections; event sourcing |
| telemetry | (telemetry gem) | feeds metrics/stats |

### Presets resolve to capabilities

The preset is the safe, self-documenting front door. It resolves to explicit
capability flags — that is what the processors actually read. The delivery ladder
is strict (each rung adds to the one below); `broker` hands off externally
**instead of** running in-process subscribers, matching today's `OutboxRouter`
(level 3 notifies subscribers, level 4 publishes).

| preset | in-process subscribers | backgrounded | durable (outbox) | broker |
|---|---|---|---|---|
| `inline` | ✓ | – | – | – |
| `background` | ✓ | ✓ | – | – |
| `durable` | ✓ | ✓ | ✓ | – |
| `broker` | – | ✓ | ✓ | ✓ |

Telemetry and sourcing are **independent** switches added on top of any delivery
preset (an event can be `broker` + `sourced` + `telemetry`). They are not rungs
on this ladder — folding them in would re-create the "one slot, one choice"
problem the number had.

Principle: **the event declares, the processor obeys.** Core owns the
preset→capabilities resolution and the event carries the resolved capabilities.
A processor never decides whether it applies by inspecting a magnitude — it reads
its own flag. The "is this wired?" safety stays in the processor (delivery raises
if an event wants `broker` but no transport is registered).

### DSL surface (illustrative — exact spelling decided in step 1)

```ruby
class OrderPlaced < EventEngine::EventDefinition
  event_name :order_placed
  event_type :domain

  process :broker      # delivery, broker rung (resolves to its capabilities)
  process :telemetry   # telemetry processor
  process :sourced     # sourcing processor (future)
end
```

Open question for step 1: whether `process` takes one delivery preset plus
independent processor switches, or a flat set the resolver interprets.

## What this removes

- The numeric `event_level` and its two `case` statements.
- The `event_level` range validation (PR #92) — an unknown preset fails at
  resolution, so the validation becomes dead code.
- `OutboxRouter`'s `level 5 → UnsupportedLevelError`. Sourcing is the
  store/sourcing processor, not a delivery rung.
- The "install delivery just to run an inline subscriber" coupling.

## Back-compat / migration hazards

- **The committed `db/event_schema.rb` serializes `event_level: N`** and apps
  boot from it. The schema **loader** must accept old integer levels for one
  transition (map `1→inline … 4→broker`; `5→` sourcing/transitional) or force a
  re-dump. This is the real migration work — do it before removing the enum.
- **Keep processing out of the fingerprint**, exactly as `event_level` is
  excluded today, so changing how an event is processed doesn't bump its version.
- **`HandlerRegistry`'s `levels:` param becomes vestigial** (every processor
  registers `:all` and self-selects). Drop it, or repurpose to capability filters.
- **Circular requires:** keep the preset→capabilities map in its own file in
  core, required before `event_definition`, so processors only read capabilities
  off the event and never reach back into core's internals.

## Out of scope (separate threads)

- `event_id` / `idempotency_key` split. Decision so far: `idempotency_key` stays
  the broker pass-through; do **not** add producer-side outbox dedup (a too-broad
  key silently drops intended events). The only latent item is the outbox's
  `unique: true` index on `idempotency_key`, revisited separately if/when wanted.
- Telemetry's analytical descriptor (trend / rate / audit) — its own design pass.

## Phased plan

Each phase is a small, independently shippable PR. Behavior stays correct at
every step; the legacy enum is removed only after the new path is proven.

1. **Preset module in core.** Add the preset set and
   `capabilities_for(preset) → { in_process_subscribers:, backgrounded:,
   durable:, broker: }` in its own file. Pure and isolated. (test-first)
2. **Declare on the definition.** Add `process` to `EventDefinition` alongside the
   existing `event_level`; carry resolved capabilities onto the schema and the
   `Event`. Keep `event_level` working in parallel.
3. **Schema loader back-compat.** Loader accepts both old `event_level:` and the
   new processing form; dumper writes the new form. Re-dump `db/event_schema.rb`.
4. **Route on capabilities.** Rewrite `Delivery::Handler` / `OutboxRouter` to read
   the capability flags instead of the integer. Behavior parity with the old
   mapping.
5. **Extract the in-process subscriber processor.** Move `Subscriber`,
   `SubscriberRegistry`, inline/background execution, and `DispatchSubscribersJob`
   out of delivery into the new processor gem; delivery becomes outbox + broker
   only.
6. **Remove the legacy enum.** Delete `event_level`, the PR #92 validation, and
   `UnsupportedLevelError`; drop the transitional loader shim.
7. **(Later) telemetry and sourcing processors** as their own gems, plugging into
   the same capability/processor contract.
