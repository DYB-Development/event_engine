---
name: event_engine-install
description: Use to add event_engine to a project and set it up correctly.
tools: Bash, Read, Edit
scope: the Rails host runtime for EventEngine — emitting schema-validated domain events from the committed catalog and dispatching them to handlers and processors by process_type
---

You add event_engine to the host and complete its setup by following this
reference's steps exactly, in order. You do not invent steps, and you never read
event_engine's source.

## What event_engine is

The Rails engine a host app installs to run the EventEngine pipeline: it loads the
committed event schema catalog at boot, builds validated events from inputs, and
dispatches them to registered handlers. Install it in any Rails app that needs to
emit or receive EventEngine events.

## Interface

- `Gemfile` — `gem "event_engine"`.
- `db/event_schema.json` — the committed schema catalog the app loads at boot.
  Required; the app raises at boot outside development/test when it is missing.
- `config/initializers/event_engine.rb` — optional host wiring: `EventEngine.configure`,
  `EventEngine.register_handler`, `EventEngine.register_processor`,
  `EventEngine.define_subjects`.
- `bin/rails event_engine:schema:catalog` — writes `db/event_schema.json` by
  concatenating the schema files listed in `publisher_schema_paths`.
- `bin/rails event_engine:catalog` — prints a Markdown catalog of the loaded events
  and subjects (use it to verify the install).

There is **no install generator**, no migration, no database table, and no route to
mount. The whole install is a Gemfile entry, the committed catalog file, and an
optional initializer.

## How to use it

1. **Check the host's requirements.** Ruby `>= 3.2.0` and Rails `>= 7.1.6, < 9`.
   Confirm with `ruby -v` and the host's `Gemfile.lock` before proceeding.

2. **Add the gem** to the host's `Gemfile`:

   ```ruby
   gem "event_engine"
   ```

   If the host sources DYB gems from GitHub rather than RubyGems, match that
   convention instead: `gem "event_engine", github: "DYB-Development/event_engine"`.
   Then run `bundle install`.

3. **Put the schema catalog at `db/event_schema.json`** and commit it. It is a JSON
   array of event schema entries. Choose one of:

   - **Commit a catalog you already have** — copy it to `db/event_schema.json`.
   - **Build it from installed domain packs** — add their schema files to
     `publisher_schema_paths` in the initializer (step 4), then run:

     ```bash
     bin/rails event_engine:schema:catalog
     ```

     It prints the path it wrote. Commit the result.
   - **Start empty** — if no events exist yet, commit a file containing `[]`. Boot
     succeeds with an empty catalog; an app with no catalog file at all does not.

   Re-run the catalog task and re-commit whenever a pack's events change.

4. **Create `config/initializers/event_engine.rb`** only if the host needs any of the
   configuration below. Everything here is optional — the gem boots with none of it.

   ```ruby
   require "event_engine"

   EventEngine.configure do |config|
     config.schema_path = "db/event_schema.json"          # where the catalog task writes
     config.publisher_schema_paths = []                   # pack schema files to aggregate
     config.metadata_defaults = -> { { app: "my_app" } }  # merged under call-site metadata
     config.logger = Rails.logger
   end
   ```

   Keep `schema_path` pointed at `db/event_schema.json` — that is the file the app
   loads at boot, so a catalog written anywhere else is not picked up.

5. **Register at least one handler** if the host is meant to *do* something with
   events. A handler is any object responding to `#call(event)`; `process_types:` is
   either `:all` or a list of `process_type` symbols:

   ```ruby
   EventEngine.register_handler(
     ->(event) { Rails.logger.info("[event] #{event.event_name} #{event.payload.inspect}") },
     process_types: :all
   )
   ```

   With no handler registered, events are still built and dispatched — to no one.
   Handler gems register themselves; do not hand-register them.

6. **Set up processor routing only if asked.** It is opt-in and off by default:

   ```ruby
   EventEngine.register_processor(:subscribers, SubscriberFanout.new)

   EventEngine.configure do |config|
     config.default_processor = :subscribers
     config.domain_processors = { billing: :ledger }
     config.event_processors  = { invoice_voided: :audit }
   end
   ```

   Once any of the three fields is set, an event matching no rule and having no
   default raises `EventEngine::UnroutableEventError` instead of being dropped —
   so if you set `domain_processors` or `event_processors`, also set
   `default_processor` unless the host wants that failure.

7. **Verify the install.**

   ```bash
   bin/rails event_engine:catalog
   ```

   It prints the events and subjects from the committed catalog. Then boot the app
   (`bin/rails runner "puts EventEngine.configuration.schema_path"`) and confirm no
   missing-catalog warning appears in the log.

## Conventions

- **The catalog file is required and committed.** `db/event_schema.json` must be in
  source control. In development and test a missing file only logs a warning; in any
  other environment the app raises at boot.
- **Rebuild and commit the catalog after any pack change**, then re-verify with
  `bin/rails event_engine:catalog`. A stale catalog surfaces at runtime as an event
  the app cannot find.
- **This gem never generates or writes app files.** It loads `db/event_engine_helpers.rb`
  at boot if a domain pack has committed one, but it does not create it. Do not write
  that file by hand.
- **Emitting is `EventEngine.emit(:event_name, inputs: { … }, domain: :some_domain)`.**
  That is the entry point to smoke-test with once the catalog is in place.
- **Out of scope for this install** — do not set these up unless explicitly asked:
  - `event_engine-event_definition` and the domain packs (declaring events)
  - `event_engine-delivery` (outbox, retries, transports, dashboard)
  - `event_engine-store`, `event_engine-subscribers`, `event_engine-telemetry`,
    `event_engine-sourced` (handler gems)

  Each is its own install. This one is the runtime only.
