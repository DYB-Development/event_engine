namespace :event_engine do
  desc "Fail if event schema DSL has drifted from db/event_schema.rb"
  task schema: :environment do
    EventEngine::DefinitionLoader.ensure_loaded!

    descendants = EventEngine::EventDefinition.descendants

    if descendants.empty?
      raise <<~MSG
        EventEngine found no EventDefinitions.

        Expected definitions to be loaded during eager load.
        Ensure they live in an eager-load path (e.g. app/event_definitions).
      MSG
    end

    EventEngine::SchemaDriftGuard.check!(
      schema_path: Rails.root.join("db/event_schema.rb"),
      definitions: descendants,
      helpers_path: Rails.root.join("db/event_engine_helpers.rb"),
      json_path: Rails.root.join("db/event_schema.json")
    )
  end

  namespace :schema do
    desc "Regenerate event_schema.rb from EventDefinitions"
    task dump: :environment do
      EventEngine::DefinitionLoader.ensure_loaded!

      descendants = EventEngine::EventDefinition.descendants

      if descendants.empty?
        raise <<~MSG
          EventEngine found no EventDefinitions.

          Expected definitions to be loaded during eager load.
          Ensure they live in an eager-load path (e.g. app/event_definitions).
        MSG
      end
      
      path = Rails.root.join("db/event_schema.rb")
      helpers_path = Rails.root.join("db/event_engine_helpers.rb")
      json_path = Rails.root.join("db/event_schema.json")

      EventEngine::EventSchemaDumper.dump!(
        definitions: descendants,
        path: path,
        helpers_path: helpers_path,
        json_path: json_path
      )

      puts "Dumping EventEngine schema to #{path}"
    end

    desc "Fail with a readable diff if definitions have drifted from db/event_schema.rb"
    task verify: :environment do
      EventEngine::DefinitionLoader.ensure_loaded!

      descendants = EventEngine::EventDefinition.descendants

      if descendants.empty?
        raise <<~MSG
          EventEngine found no EventDefinitions.

          Expected definitions to be loaded during eager load.
          Ensure they live in an eager-load path (e.g. app/event_definitions).
        MSG
      end

      EventEngine::SchemaDriftGuard.check!(
        schema_path: Rails.root.join("db/event_schema.rb"),
        definitions: descendants,
        helpers_path: Rails.root.join("db/event_engine_helpers.rb"),
        json_path: Rails.root.join("db/event_schema.json")
      )
    end

    desc "Fail if new definitions break compatibility with the committed schema"
    task compatibility: :environment do
      EventEngine::DefinitionLoader.ensure_loaded!

      violations = EventEngine::SchemaCompatibility.violations(
        old_registry: EventEngine.file_schema_registry,
        new_registry: EventEngine.compiled_schema_registry
      )

      raise "Breaking schema changes:\n#{violations.join("\n")}" if violations.any?
    end
  end
end
