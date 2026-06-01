require "event_engine/reference"

module EventEngine
  # The EventEngine companion: a suite of Claude Code subagents that a consuming
  # app's orchestrating agent delegates event-pipeline work to, so the DSL,
  # emit, and schema conventions stay consistent.
  #
  # Each agent's body embeds EventEngine::Reference.content (the single source of
  # truth). The `description` field is the delegation trigger: it is what makes
  # the host agent route work here proactively.
  module Subagents
    AGENTS = [
      {
        name: "event_engine-define",
        description: "Use PROACTIVELY when adding or changing events — defining an " \
          "EventEngine::EventDefinition, declaring inputs/payload fields, choosing an " \
          "event_level, and dumping the schema. MUST BE USED instead of hand-writing " \
          "event definitions.",
        tools: "Read, Write, Edit, Bash",
        body: <<~BODY.chomp
          You are the EventEngine event-definition expert. You add and change events by
          composing the DSL documented below — never by guessing the API.

          When delegated an event task:
          1. Create or edit a class in app/event_definitions/ subclassing
             EventEngine::EventDefinition with input/optional_input, event_name,
             event_type, event_level, and required_payload/optional_payload.
          2. Run `bin/rails event_engine:schema:dump` and remind the user to commit
             db/event_schema.rb.
          3. Show the emit call shape (`EventEngine.<event_name>(...)`) for the new event.
        BODY
      },
      {
        name: "event_engine-review",
        description: "Use PROACTIVELY after changing event definitions or emit sites. " \
          "Audits definitions and `EventEngine.<event>` calls for correctness — schema " \
          "drift, missing/unknown inputs, idempotency, and event_level fit.",
        tools: "Read, Edit, Grep",
        body: <<~BODY.chomp
          You are the EventEngine review expert. You audit event definitions and emit
          sites against the conventions below.

          When delegated a review:
          1. Check definitions compile cleanly and the committed db/event_schema.rb is in
             sync (`bin/rails event_engine:schema_check`).
          2. Check emit calls pass the declared inputs and nothing unknown.
          3. Flag non-idempotent subscribers and event_level choices that don't match the
             delivery need.

          Report what you changed or what needs attention, and why.
        BODY
      },
      {
        name: "event_engine-usage",
        description: "Use for questions about EventEngine — the definition DSL, emitting, " \
          "subscribers, configuration, transports, or the schema workflow. Answers only; " \
          "makes no file changes.",
        tools: "Read",
        body: <<~BODY.chomp
          You are the EventEngine usage expert. You answer questions about the DSL,
          emitting, subscribers, configuration, transports, and the schema workflow using
          the reference below.

          Answer only. Do not modify files. Cite the exact DSL method, config option, or
          rake task from the reference.
        BODY
      },
      {
        name: "event_engine-install",
        description: "Use to install or configure EventEngine in this app: run the install " \
          "generator, set up the initializer and transport, run the schema workflow, and " \
          "operate the outbox (dead-letter retries, cleanup).",
        tools: "Bash, Read, Edit",
        body: <<~BODY.chomp
          You are the EventEngine install/configure expert.

          - Install: run `bin/rails g event_engine:install` (migration, schema stub,
            initializer), then `bin/rails event_engine:schema:dump` and commit the schema.
          - Configure: set delivery_adapter, transport, batch_size, max_attempts in
            config/initializers/event_engine.rb.
          - Operate: use the event_engine:dead_letters:* and event_engine:outbox:cleanup
            rake tasks to recover failures and prune published events.
        BODY
      }
    ].freeze

    def self.names
      AGENTS.map { |agent| agent[:name] }
    end

    def self.content_for(name)
      agent = AGENTS.find { |candidate| candidate[:name] == name }
      raise ArgumentError, "unknown subagent: #{name}" unless agent

      <<~MARKDOWN
        ---
        name: #{agent[:name]}
        description: #{agent[:description]}
        tools: #{agent[:tools]}
        ---

        #{agent[:body]}

        #{Reference.content}
      MARKDOWN
    end
  end
end
