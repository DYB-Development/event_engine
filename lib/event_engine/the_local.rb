require "event_engine/reference"

module EventEngine
  module Companion
    def self.register!
      TheLocal.register("event_engine",
        scope: "events — defining EventEngine events, emitting, and the schema workflow",
        agents_dir: File.expand_path("the_local/agents", __dir__)) do |c|
        c.agent "info",
          description: "Use to learn what EventEngine offers — the event-definition DSL, " \
            "process_type, emitting, handlers, and the schema workflow.",
          tools: "Read",
          knowledge: Reference.content,
          body: <<~BODY.chomp
            You explain how EventEngine works and how to use it, answering only from the
            reference: defining events, process_type routing, emitting through the generated
            helpers, registering handlers, and the schema dump/check workflow. You make no
            changes.
          BODY

        c.agent "install",
          description: "Use to add EventEngine to a Rails app and set it up correctly.",
          tools: "Bash, Read, Edit",
          knowledge: Reference.content,
          body: <<~BODY.chomp
            You install EventEngine following the reference's install section exactly: add the
            gem, bundle, run `bin/rails g event_engine:install`, set the logger in the
            initializer, then dump and commit db/event_schema.rb. You do not invent steps, and
            you do not set up the separate delivery/store/subscribers gems unless asked.
          BODY

        c.agent "develop",
          description: "Use PROACTIVELY for any EventEngine work — defining events, choosing " \
            "process_type, emitting, and keeping the committed schema in sync. MUST BE USED " \
            "instead of hand-writing event plumbing.",
          tools: "Read, Write, Edit, Grep",
          knowledge: Reference.content,
          body: <<~BODY.chomp
            You build EventEngine events following the reference's conventions: one
            EventDefinition class per event in app/event_definitions/, payloads composed from
            inputs, process_type set explicitly, emitted through the generated
            EventEngine.<event_name> helpers. After any definition change you run
            `bin/rails event_engine:schema:dump` and commit db/event_schema.rb, keeping
            event_engine:schema_check green. You keep handlers idempotent.
          BODY
      end
    end
  end
end

begin
  require "the_local"
  EventEngine::Companion.register!
rescue LoadError
end
