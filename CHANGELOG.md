# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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

## [0.1.0] - 2025-12-16

### Added

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

[Unreleased]: https://github.com/tylercschneider/event_engine/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/tylercschneider/event_engine/releases/tag/v0.1.0
