require "event_engine/subagents"

module EventEngine
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Install EventEngine (schema file, initializer, migrations)"

      def install_migrations
        rake "event_engine:install:migrations"
      end

      def create_event_schema
        template "event_schema.rb", "db/event_schema.rb"
      end

      def create_initializer
        template "initializer.rb", "config/initializers/event_engine.rb"
      end

      def generate_subagents
        say ""
        say "Installing EventEngine Claude Code subagents...", :green
        EventEngine::Subagents.names.each do |name|
          create_file ".claude/agents/#{name}.md", EventEngine::Subagents.content_for(name), force: true
        end
      end

      def print_next_steps
        say <<~MSG

          EventEngine installed.

          Next steps:
            1. Define events in app/event_definitions/
            2. Run: bin/rails event_engine:schema:dump
            3. Commit db/event_schema.rb
            4. Configure transport in config/initializers/event_engine.rb

        MSG
      end
    end
  end
end
