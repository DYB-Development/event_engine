module EventEngine
  class EventSchemaDumper
    def self.dump!(definitions:, path:, helpers_path: nil, json_path: nil, domain: nil)
      compiled_schema = DslCompiler.compile(scope_to_domain(definitions, domain))
      compiled_schema.finalize!

      loaded_schema = load_prior_schema(path, json_path)
      merged_schema = EventSchemaMerger.merge(compiled_schema, loaded_schema)

      EventSchemaWriter.write(path, merged_schema)
      EventEngineHelpersWriter.write(helpers_path, merged_schema) if helpers_path
      EventSchemaJsonWriter.write(json_path, merged_schema) if json_path
    end

    def self.scope_to_domain(definitions, domain)
      return definitions unless domain

      Array(definitions).select { |definition| definition.schema.domain == domain }
    end

    def self.load_prior_schema(path, json_path)
      return EventSchemaJsonLoader.load(json_path) if json_path

      EventSchemaLoader.load(path)
    end
  end
end
