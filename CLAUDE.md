# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EventEngine is a Ruby on Rails engine gem (v0.1.0) providing a schema-first event pipeline. It uses a DSL to define events, compiles them into a canonical schema file, persists events via the outbox pattern, and delivers them through pluggable transport adapters.

## Development Commands

```bash
bundle install                        # Install dependencies
bundle exec rake test                 # Run all tests (Minitest)
bundle exec ruby -Itest test/path/to/test_file.rb  # Run a single test file
bundle exec ruby -Itest test/path/to/test_file.rb -n test_method_name  # Run a single test method
```

Rake tasks (prefixed with `app:` when run from engine root via dummy app):
```bash
bundle exec rake app:event_engine:schema        # Check for schema drift (DSL vs file)
bundle exec rake app:event_engine:schema:dump   # Regenerate event_schema.rb from definitions
bundle exec rake app:event_engine:schema_check  # Alternative drift check
```

## Architecture

### Event Lifecycle

1. **Define** — Ruby classes in `app/event_definitions/` inherit from `EventEngine::EventDefinition` and declare inputs, payload fields, event name, and event type via a class-level DSL.

2. **Compile** — `DslCompiler` converts definition classes into `EventSchema` objects. `EventSchemaDumper` writes the canonical `db/event_schema.rb` file (must be committed to source control).

3. **Boot** — At Rails boot, `Engine` loads `db/event_schema.rb` via `EventSchemaLoader`, populates `SchemaRegistry`, and installs singleton helper methods on the `EventEngine` module (e.g., `EventEngine.cow_fed(...)`).

4. **Emit** — Calling a helper method triggers `EventEmitter` → `EventBuilder` (constructs payload) → `OutboxWriter` (persists to `event_engine_outbox_events` table) → `Delivery` (inline or ActiveJob).

5. **Publish** — `OutboxPublisher` reads unpublished events from the outbox and sends them through the configured transport. Supports retry with `max_attempts` and dead-lettering.

### Key Components

- **EventDefinition** — DSL base class. Composed of `Inputs`, `Payloads`, `Validation`, and `Schemas` concerns.
- **SchemaRegistry** — In-memory registry holding all event schemas by name/version. Loaded once at boot from the schema file.
- **SchemaDriftGuard** — Validates that DSL definitions match the committed schema file. Used by CI rake tasks.
- **EventSchemaMerger** — Handles schema versioning via SHA256 fingerprinting of payload fields.
- **Transports** — `InMemoryTransport` (dev/test) and `Kafka` (production). Configured via `EventEngine.configure`.

### Schema File is Authoritative

The `db/event_schema.rb` file is the source of truth at runtime. Event definitions are only used at development time to generate/update this file. In non-dev/test environments, a missing schema file raises an error at boot.

## Test Setup

- **Framework**: Minitest with `minitest-reporters` and `minitest-focus`
- **Database**: SQLite via a dummy Rails app in `test/dummy/`
- **Helpers**: `EventEngineTestHelpers` included in all test cases (see `test/support/`)
- **Test structure**: `test/lib/` (unit), `test/integration/`, `test/models/`, `test/services/`, `test/transports/`

## Configuration

```ruby
EventEngine.configure do |config|
  config.delivery_adapter = :inline   # or :active_job
  config.transport = EventEngine::Transports::InMemoryTransport.new
  config.batch_size = 100
  config.max_attempts = 5
end
```

## Key Patterns

- **Isolated Rails Engine** with `isolate_namespace EventEngine`
- **Outbox pattern** for reliable event delivery before transport
- **DSL compilation** — definition classes are never used at runtime; only the compiled schema file is
- **Dynamic method installation** — `EventEngine.install_helpers` defines singleton methods on the module from registry contents

## Development Process (TDD)

Follow this cycle for all feature work:

1. **Plan** — Decide what needs to be built and break it into tasks
2. **Write failing test** — Create the simplest test that fails for the desired behavior
3. **Make it pass** — Write minimal code to make the test pass
4. **Commit** — Commit the passing test and implementation
5. **Refactor** — Clean up code while keeping tests green
6. **Verify** — Run full test suite to ensure no regressions
7. **Commit** — Commit the refactored code
8. **Repeat** — Continue with next test until task is complete
9. **Push** — Push changes when feature/task is complete

### Commit Guidelines

- Commit after each test passes (small, incremental commits)
- Commit after refactoring (separate from feature commits)
- Push only when a feature or task is fully complete
- Use imperative mood in commit messages (e.g., "Add idempotency_key support")

<!-- the_local:begin -->
## Delegate to your locals

This project has installed expert subagents. Before doing work yourself,
check whether a local owns it and delegate — never work from memory on
something a local covers:

- the_local-* agents

See each agent's description for specifics.
<!-- the_local:end -->



