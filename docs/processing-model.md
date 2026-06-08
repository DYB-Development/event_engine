# Plan: event processing model (replacing numeric levels)

Status: proposed. This is a design + migration plan, not yet implemented.

## Why

`event_level` (an integer, 1–5) is a single ordinal standing in for several
unrelated processing strategies:

- It implies a **magnitude / ordering** ("4 > 3") when the options aren't points
  on a line — telemetry isn't "more than" durable, it's a *different kind* of
  processing.
- The number isn't **self-documenting**; `event_level 4` means nothing without a
  lookup table.
- It lumps things that aren't delivery at all (telemetry, event sourcing) onto the
  same scale as delivery rungs, as if they were further steps along it.

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

## Target model: a named `process_type`

Replace the ordinal with a single, named `process_type` on the event definition —
one value, sitting alongside `event_name` and `event_type`:

```ruby
class OrderPlaced < EventEngine::EventDefinition
  input :order

  event_name   :order_placed
  event_type   :domain
  process_type :broker

  required_payload :order_id, from: :order, attr: :id
  required_payload :total,    from: :order, attr: :total_cents
end
```

An event has **exactly one** `process_type`. The vocabulary is flat:

```
:inline | :background | :durable | :broker | :telemetry | :sourced
```

Same single slot `event_level` occupied, but named and self-documenting instead
of an ordinal — and with no implied ordering between, say, `:broker` and
`:telemetry`.

### Processors

Each `process_type` is owned by a **processor**: a self-contained subsystem (its
own gem) that registers a handler with the core bus and handles the events whose
`process_type` it owns. Core is a **pure bus** — it defines events, carries the
`process_type`, and dispatches. It owns no processing of its own.

| `process_type` | processor (gem) | what happens |
|---|---|---|
| `:inline` | in-process subscribers | run `Subscriber#handle` synchronously, in the caller's stack |
| `:background` | in-process subscribers | run `Subscriber#handle` in a background job |
| `:durable` | delivery | write to the outbox; run subscribers when it drains |
| `:broker` | delivery | write to the outbox; publish to the broker when it drains |
| `:telemetry` | telemetry | feed metrics / stats |
| `:sourced` | sourcing (future) | record to the event-sourcing log |

Principle: **the event declares, the processor obeys.** A processor self-selects
the events whose `process_type` it owns and acts on them; it never inspects a
magnitude. The "is this wired?" safety stays inside the processor (delivery
raises if a `:broker` event has no transport registered).

### Where subscribers live

The in-process subscriber processor owns `Subscriber`, `SubscriberRegistry`, the
inline/background execution, and `DispatchSubscribersJob` — all extracted from
`event_engine-delivery`. Core keeps none of it. So "react to an event in-process"
needs only the subscriber processor, not the durable-delivery gem — fixing
today's backwards coupling where an inline subscriber requires the outbox gem.

## What this removes

- The numeric `event_level` and its two `case` statements.
- The `event_level` range validation (PR #92) — `process_type` is a known symbol
  set, so an unknown value fails at declaration; the range check becomes dead.
- `OutboxRouter`'s `level 5 → UnsupportedLevelError`. Sourcing is its own
  `process_type`, owned by the sourcing processor — not a delivery rung.
- The "install delivery just to run an inline subscriber" coupling.

## Back-compat / migration hazards

- **The committed `db/event_schema.rb` serializes `event_level: N`** and apps boot
  from it. The schema **loader** must map old integers for one transition
  (`1→:inline`, `2→:background`, `3→:durable`, `4→:broker`; `5→:sourced` once the
  sourcing processor exists) or force a re-dump. This is the real migration work —
  do it before removing the enum.
- **Keep `process_type` out of the fingerprint**, exactly as `event_level` is
  excluded today, so changing how an event is processed doesn't bump its version.
- **`HandlerRegistry`'s `levels:` param becomes vestigial** (every processor
  registers `:all` and self-selects on `process_type`). Drop it, or repurpose to a
  `process_type` filter.
- **Circular requires:** keep the `process_type` vocabulary in its own core file,
  required before `event_definition`, so processors only read `process_type` off
  the event.

## Out of scope (separate threads)

- `event_id` / `idempotency_key` split. Decision so far: `idempotency_key` stays
  the broker pass-through; do **not** add producer-side outbox dedup (a too-broad
  key silently drops intended events). The only latent item is the outbox's
  `unique: true` index on `idempotency_key`, revisited separately if/when wanted.
- Telemetry's analytical descriptor (trend / rate / audit) — its own design pass.

## Phased plan

Each phase is a small, independently shippable PR. Behavior stays correct at every
step; the legacy enum is removed only after the new path is proven.

1. **`process_type` vocabulary in core.** Add the known symbol set and which
   processor owns each value, in its own file. Pure and isolated. (test-first)
2. **Declare on the definition.** Add `process_type` to `EventDefinition`
   alongside the existing `event_level`; carry it onto the schema and the `Event`.
   Keep `event_level` working in parallel.
3. **Schema loader back-compat.** Loader accepts old `event_level:` integers and
   maps them to `process_type`; dumper writes `process_type`. Re-dump
   `db/event_schema.rb`.
4. **Route on `process_type`.** Rewrite `Delivery::Handler` / `OutboxRouter` to
   read the symbol instead of the integer. Behavior parity with the old mapping.
5. **Extract the in-process subscriber processor.** Move `Subscriber`,
   `SubscriberRegistry`, inline/background execution, and `DispatchSubscribersJob`
   out of delivery into the new processor gem; delivery becomes outbox + broker
   only.
6. **Remove the legacy enum.** Delete `event_level`, the PR #92 validation, and
   `UnsupportedLevelError`; drop the transitional loader shim.
7. **(Later) telemetry and sourcing processors** as their own gems, each owning
   its `process_type` value via the same bus/processor contract.
