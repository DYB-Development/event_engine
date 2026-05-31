# Per-Event Levels — Implementation Plan

Status: **Phase 1 in design**

Source proposal: `~/projects/other/dyb_docs/gems/event_engine/per-event-levels.md`.
This note is the repo-side, build-facing plan. Where the source proposal is
ambiguous, the **Decisions** section below is authoritative.

## Goal

Let each event declare its position on the event-system level ladder via
`event_level` (already added in #68), and have the framework route it
accordingly — so moving an event up a level is a **one-line change to its
definition**, not a rewrite. Producer code never changes
(`EventEngine.sale_processed(sale:)` is identical at every level).

## The level ladder, in EventEngine terms

`event_level` is declared **per `EventDefinition`**. The system runs a mix of
levels at once; the level decides an event's path, not a global mode.

| Level | Outbox? | Capture (emit-time) | Delivery (specified transport) |
|---|---|---|---|
| **1** | No | sync, in-process | in-memory sink |
| **2** | No | async via background job | in-memory / local-queue sink |
| **3** | **Yes** | write outbox → local async drain | local / in-memory sink |
| **4** | **Yes** | write outbox → drain | **Kafka** (specifiable) |
| **5** | Yes (source of truth) | outbox retained as history | event-sourced / replay |

## Decisions (locked)

1. **Outbox is the floor for level ≥ 3.** Every level 3+ event captures to the
   outbox. What you *specify* per event is the transport it drains to.
2. **Level 4 = outbox + Kafka**, not Kafka-instead-of-outbox. The source
   proposal's `4 => Kafka` route is misleading; level 4 still goes through the
   outbox, then drains to the specified transport (Kafka is the obvious choice).
3. **Straight-to-broker with no outbox is NOT a level — it's telemetry.** The
   lossy, non-durable, `acks=0`/sink path is the separate `telemetry true` mode
   (source proposal §"Telemetry"). Out of scope for Phase 1.
4. **`event_level` is per `EventDefinition`** (number 1–5, excluded from the
   schema fingerprint — established in #68).

## Architecture: two axes, two seams

The ladder has two independent axes — **capture** and **delivery** — and they
are decided at two different points in the pipeline. This is intentional, not a
split-logic smell.

### Seam A — Capture (emit-time branch, in `EventEmitter`)

Today `EventEmitter.emit` calls `OutboxWriter.write` **unconditionally**
(`event_emitter.rb`), which is exactly why a transport-layer router (the closed
#69) was inert — it only ever saw already-outboxed events.

The fix: the emitter consults the event's `event_level` and branches on capture:

- **level ≤ 2** → do **not** write the outbox; dispatch the built event directly
  (level 1 sync; level 2 via background job).
- **level ≥ 3** → `OutboxWriter.write` as today; the publisher drains it later.

### Seam B — Delivery (publish-time routing, after the outbox drain)

For outbox-backed events only (≥ 3), the `OutboxPublisher` drains rows and hands
each event to its **specified transport**. A level→transport router lives here
and *only ever sees ≥ 3 events* — which is what makes it coherent (and is why it
was meaningless as a global `config.transport` in #69).

## Open questions (decide before the slice that needs them — do NOT guess)

- **OQ1 — Level 3 delivery target.** EventEngine has **no in-process subscriber
  bus** (ROADMAP #45 — in-process hooks are `ActiveSupport::Notifications`;
  consumers are out of scope by the producer-side-only principle). So what does
  a level-3 event drain *to*? Candidate answers: an `InMemoryTransport` that
  just collects; or we accept that "level 3 local processing" in this gem means
  "durable capture + drain to a configured local transport," with actual
  fan-out still the consumer's job. **Needs a decision before building level 3.**
- **OQ2 — How a ≥ 3 event specifies its transport.** Options: (a) a per-event
  DSL field on the definition; (b) a global `LevelRouter` map (level→transport)
  consulted by the publisher; (c) both. The source proposal shows (b).
- **OQ3 — Interaction with the existing global `delivery_adapter`
  (`:inline` / `:active_job`) and `config.transport`.** Level 2's "async via
  background job" overlaps with `delivery_adapter: :active_job`. Does
  `event_level` subsume `delivery_adapter`, or layer on top of it? Must be
  pinned before level 2.
- **OQ4 — Level 5 (event sourcing / replay).** Large; treat as future, out of
  Phase 1.
- **OQ5 — Namespace defaults** (source proposal §2). Defer past Phase 1.

## Resequenced Phase 1 (corrects #69's ordering)

Each slice lands something that actually does work, and is built strict-TDD
(one assertion per test, one behavior per commit, ≤ 2 files per commit).

1. **✅ `event_level` DSL** — #68, merged.
2. **Emit-time capture branch** — `EventEmitter` writes the outbox only for
   level ≥ 3; level ≤ 2 skips it. *The linchpin.* First failing test: a level-1
   event emits **no** `OutboxEvent` row. (Resolve OQ3 for the level-2 async path
   before that sub-slice.)
3. **`OutboxTransport`** — extract the existing publisher/drain logic into a
   transport so the outbox is per-event addressable rather than the hardcoded
   floor (level 3). (Resolve OQ1 first.)
4. **`LocalQueueTransport`** (level 2) — background-job dispatch, no outbox.
5. **`LevelRouter`** (delivery seam) — route drained ≥ 3 events to their
   specified transport. Reuse the unit from the closed `feat/level-router`
   branch; now it has real destinations and a correct position. Add the
   end-to-end smoke test here (deferred from #69).

## Out of scope for Phase 1

- Telemetry mode (`telemetry true`, `sample_rate`, `buffer_size`, sinks).
- Observability metrics + `event_engine:report` / `check_upgrade_signals`
  (source proposal Phase 2).
- Decision-support tooling: `simulate_upgrade`, `dependencies`,
  `upgrade_to_level` trigger registry (source proposal Phases 3–4).
- Namespace defaults; level 5 / event sourcing.
