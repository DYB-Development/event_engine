# Per-Event Levels — As Built

Status: **Phase 1 complete** (levels 1–4 working; level 5 unsupported).

Source proposal: `~/projects/other/dyb_docs/gems/event_engine/per-event-levels.md`.
This note records the design as built. Where it diverges from the source
proposal, this note is authoritative.

## Goal

Each event declares its position on the event-system level ladder via
`event_level`, and the framework routes it accordingly — so moving an event up
a level is a **one-line change to its definition**, not a rewrite. Producer code
never changes: `EventEngine.sale_processed(sale:)` is identical at every level.

## The level ladder, in EventEngine terms

`event_level` is declared **per `EventDefinition`** (a number, 1–5). The system
runs a mix of levels at once; the level decides an event's path, not a global
mode. Levels 1–3 invoke in-process **subscribers**; level 4 publishes to a
broker transport.

| Level | Outbox? | Subscribers run | Configuration needed |
|---|---|---|---|
| **1** | No | synchronously, in the caller's stack | none |
| **2** | No | in a background job (ActiveJob) | a job backend |
| **3** | **Yes** | when the outbox is drained (durable) | outbox migration |
| **4** | **Yes** | not run — event is published to a broker | outbox migration + a transport |
| **5** | — | — | unsupported (raises) |

The break point is **3 → 4**: levels 1–3 are in-process subscribers with
increasing durability; level 4 is where events leave the process to a broker and
consumers become separate services.

## Decisions (locked)

1. **Levels 1–3 invoke subscribers; level 4 publishes to a transport.** Per the
   ladder, level 3 is "durable in-process — worker reads outbox, runs
   subscribers." Only level 4 needs an external transport (e.g. Kafka).
2. **Outbox is the floor for level ≥ 3.** Levels 1–2 never touch the outbox;
   levels 3–4 always capture to it (in the producer's transaction).
3. **`event_level` is per `EventDefinition`** (excluded from the schema
   fingerprint — a level change is routing, not a contract change).
4. **Configuration is required only for the levels an app uses.** Level 1 needs
   nothing; level 2 a job backend; level 3 the outbox migration; level 4 the
   outbox plus a transport. Apps using only levels 1–2 never run the outbox
   migration.
5. **Missing level-4 transport: warn early, raise late.** At boot,
   `DefinitionTransportCheck` logs a non-blocking warning if a level-4 event
   exists with no real transport. At runtime, `OutboxRouter` raises
   `MissingTransportError` when such an event is actually drained — so the host
   app's error handling catches it without the app locking up at boot. A
   `NullTransport` counts as "no transport."
6. **Legacy events (no level) are unchanged.** They write the outbox and publish
   to the configured transport exactly as before.

## Architecture: two seams

### Seam A — Capture (emit time, in `EventEmitter`)

`EventEmitter.emit` branches on `event_level`:

- **level 1** → `dispatch_synchronously`: build the event, invoke its
  subscribers inline, return a non-persisted `Event`. No outbox.
- **level 2** → `dispatch_in_background`: enqueue `DispatchSubscribersJob`,
  return a non-persisted `Event`. No outbox.
- **level ≥ 3 (and legacy nil)** → `OutboxWriter.write`; the publisher drains it
  later.

### Seam B — Drain routing (publish time, in `OutboxRouter`)

`OutboxPublisher` drains outbox rows and hands each to an injected
`OutboxRouter`, which routes by the row's `event_level`:

- **level 3** → invoke the event's subscribers (`SubscriberRegistry`).
- **level 4** → `transport.publish` (raises `MissingTransportError` if no real
  transport).
- **level 5** → raise `UnsupportedLevelError`.
- **legacy nil** → `transport.publish`.

The publisher depends only on `#route`; the transport is composed into the
router from outside, so the publisher knows nothing about transports.

## Key components

- **`Subscriber`** — base class; `subscribes_to :event_name` self-registers the
  subclass at load time. Implements `#handle(event)`.
- **`SubscriberRegistry`** — maps event names to subscriber classes.
- **`Event`** — non-persisted value object passed to subscribers and returned by
  levels 1–2.
- **`DispatchSubscribersJob`** — ActiveJob job that invokes subscribers (level 2).
- **`OutboxRouter`** — drain-time dispatch by level.
- **`DefinitionTransportCheck`** — boot-time level-4 transport warning.

## Out of scope

- **Telemetry mode** (`telemetry true`, sampling, buffering, sinks) — the
  separate lossy, non-durable pattern from the source proposal.
- **Level 5 / event sourcing** — replay, temporal queries, read models. A
  paradigm shift, not a transport choice; currently raises.
- **Observability + decision tooling** — `event_engine:report`,
  `simulate_upgrade`, `dependencies`, `upgrade_to_level` (source proposal
  Phases 2–4).
- **Namespace defaults** — per-namespace `event_type` / `event_level` defaults.
