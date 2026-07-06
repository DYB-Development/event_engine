module EventEngine
  class EventSchemaDumper
    def self.dump!(definitions:, path:, helpers_path: nil, json_path: nil)
      compiled_schema = DslCompiler.compile(definitions)
      compiled_schema.finalize!

      loaded_schema = load_prior_schema(path, json_path)
      merged_schema = EventSchemaMerger.merge(compiled_schema, loaded_schema)

      EventSchemaWriter.write(path, merged_schema)
      EventEngineHelpersWriter.write(helpers_path, merged_schema) if helpers_path
      EventSchemaJsonWriter.write(json_path, merged_schema) if json_path
    end

    def self.load_prior_schema(path, json_path)
      return EventSchemaJsonLoader.load(json_path) if json_path

      EventSchemaLoader.load(path)
    end
  end
end
