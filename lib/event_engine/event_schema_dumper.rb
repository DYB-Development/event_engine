module EventEngine
  class EventSchemaDumper
    def self.dump!(definitions:, path:, helpers_path: default_helpers_path(path))
      compiled_schema = DslCompiler.compile(definitions)
      compiled_schema.finalize!

      loaded_schema = EventSchemaLoader.load(path)
      merged_schema = EventSchemaMerger.merge(compiled_schema, loaded_schema)

      EventSchemaWriter.write(path, merged_schema)
      EventHelperWriter.write(helpers_path, merged_schema)
    end

    def self.default_helpers_path(schema_path)
      File.join(File.dirname(schema_path), "event_engine_helpers.rb")
    end
  end
end
