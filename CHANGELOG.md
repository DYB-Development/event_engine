# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.1] - 2026-07-29

### Fixed

- Running `event_engine:catalog` broke `emit`. The task scaffolds a rules file
  listing every catalogued event with no value, and those bare keys counted as
  declared rules — so routing was considered active while every event resolved to
  nothing, raising `UnroutableEventError` on emit until each rule was filled in.

  An app that processes events through **handlers** rather than processors — for
  example one using `event_engine-store`, whose `Recorder` observes every event —
  could not emit at all after building its catalog.

  An undecided rule is now treated as no rule: a rules file where nothing is decided
  behaves exactly like no rules file, and `event_engine:rules:check` still reports
  the undecided events so the gap stays visible.


## [0.2.0] - 2026-07-29

This release completes the split between **authoring** and **runtime**. Events are
now declared with `event_engine-event_definition` and compiled into a committed
catalog; this gem builds a validated event from that catalog and hands it to a
processor. How an event is processed is declared by the host in a rules file.

### Added

- **Processing rules.** `config/event_rules.yml` declares which processor handles
  each event, resolved **event → pack → default**. `event_engine:catalog` writes the
  file alongside the catalog, listing every catalogued event so a new one is visible
  rather than silently unrouted; rules you have already decided are preserved.
- **Processor registry.** `EventEngine.register_processor(name, processor)`, with
  processor gems registering themselves under the process types they service.
- **Pack discovery.** `EventEngine.schema_sources` prefers `publisher_schema_paths`
  when set and otherwise discovers every pack that registered itself, so a host with
  packs in its Gemfile needs no per-pack configuration.
- **`DefinitionPublisher`**, registered at boot, so a pack's generated helper routes
  into `EventEngine.emit` with no wiring in the host.
- **`event_engine:rules:check`** — verifies every rule names a registered processor
  and that no catalogued event is left unrouted. Intended for CI or deploy.
- Errors that name the fix: `UnregisteredProcessorError`, `UnroutedEventsError`,
  `InvalidRulesError`.

### Changed

- **Breaking.** `process_type` now comes from the rules file, not the schema. The
  catalog is the event's contract — what it carries — and no longer describes what
  happens to it. Previously `emit` read `schema.process_type`, which raised
  `NoMethodError` for any event authored by a pack.
- **Breaking.** `EventEngine::EventDefinition::Schema` is now
  `EventEngine::CatalogEntry`, at `lib/event_engine/catalog_entry.rb`. The old file
  shared a require path with `event_engine-event_definition`, so in an app running
  both gems this gem's own class never loaded.
- **Breaking.** The Rails engine is now a `Rails::Railtie`. Hosts with
  `mount EventEngine::Engine => "/…"` must remove that line; the gem served no routes.
- **Breaking.** `event_engine:schema:catalog` is now `event_engine:catalog`.

### Removed

- **Breaking.** The authoring layer — the DSL, compiler, definition loader, lifecycle
  definitions, schema writers and authoring rake tasks. Declare events with
  `event_engine-event_definition` instead.
- **Breaking.** `Configuration#default_processor`, `#domain_processors` and
  `#event_processors`. Processing is declared in the rules file, which is now the only
  source for that decision.
- **Breaking.** `EventEngine::SubjectRegistry`, `EventEngine.define_subjects` and
  `.subject_registry`. Subjects are an authoring concern; the runtime passes through
  the subject its catalog entry declares.
- The markdown catalog printer (`SchemaCatalog`). It omitted the domain, the
  `from:`/`attr:` mapping and the fingerprint; `db/event_schema.json` is complete.
- Unreferenced `ProcessType` and `EventSchemaMerger`.


## [0.1.0] - 2026-06-25

### Added

- **`:manual` delivery adapter** — Delivery becomes a no-op; the outbox is drained
  only by an explicit `OutboxPublisher` call (a scheduled job, rake task, or
  operator action). Lets apps control exactly when events are published.
- **Per-event levels** — Each event can declare an `event_level` (1–5) that decides how it is delivered, without changing producer code.
  - Levels 1–3 invoke in-process subscribers with increasing durability: level 1 synchronously, level 2 via a background job, level 3 durably when the outbox is drained
  - Level 4 publishes to a broker transport; level 5 (event sourcing) is unsupported and raises
  - `Subscriber` base class with `subscribes_to` for self-registering event handlers, backed by `SubscriberRegistry`
  - `OutboxRouter` routes drained outbox events to subscribers or the transport by level
  - `DispatchSubscribersJob` runs level-2 subscribers in the background
  - Level-4 transport safety: warns at boot (`DefinitionTransportCheck`) and raises `OutboxRouter::MissingTransportError` at publish time when no transport is configured; `NullTransport` counts as unconfigured
  - Events with no `event_level` keep the existing outbox-and-transport behavior

- **Cloud Reporter** — Optional module that sends event metadata to EventEngine Cloud for observability. Activated by setting `cloud_api_key` in configuration. Zero impact when unconfigured.
  - `Cloud::Serializer` — Converts event notifications to metadata-only entries (never sends payloads)
  - `Cloud::Batch` — Thread-safe entry accumulator with configurable max size
  - `Cloud::ApiClient` — Net::HTTP client with 5s timeout, fire-and-forget error handling
  - `Cloud::Subscribers` — Hooks into existing `ActiveSupport::Notifications` for event tracking
  - `Cloud::Reporter` — Singleton managing the collect/batch/flush lifecycle
  - Engine boot integration — Auto-starts reporter when `cloud_api_key` is present
- Cloud configuration options: `cloud_api_key`, `cloud_endpoint`, `cloud_batch_size`, `cloud_flush_interval`, `cloud_environment`, `cloud_app_name`
- Boot logging — Reporter logs start/stop messages for operator visibility
- `NullTransport` as default transport (logs warnings for discarded events instead of nil errors)
- Event definition DSL (`event_name`, `event_type`, `input`, `required_payload`, `optional_payload`)
- Schema compilation via `DslCompiler` and `EventSchemaDumper`
- Schema versioning with SHA256 fingerprint-based version detection
- Schema drift detection via `SchemaDriftGuard` and rake tasks
- `SchemaRegistry` for in-memory schema lookup at runtime
- Outbox pattern: `OutboxWriter`, `OutboxPublisher` with configurable batch size and max attempts
- Dead letter support for failed publish attempts
- `EventEmitter` and `EventBuilder` for event construction
- Dynamic helper method installation (`EventEngine.cow_fed(...)`)
- Pluggable transport interface with `InMemoryTransport` and `Kafka` adapters
- `DefinitionLoader` for auto-loading event definitions
- Inline and ActiveJob delivery adapters
- `occurred_at` and `metadata` support on outbox events
- Rails engine generator for installation
- Rake tasks: `event_engine:schema`, `event_engine:schema:dump`

[Unreleased]: https://github.com/DYB-Development/event_engine/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/DYB-Development/event_engine/releases/tag/v0.1.0
