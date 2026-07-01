require "event_engine/schema_diff"
require "tmpdir"

module EventEngine
  class SchemaDriftGuard
    class DriftError < StandardError; end

    def self.check!(schema_path:, definitions:, helpers_path: EventSchemaDumper.default_helpers_path(schema_path))
      raise DriftError, "Schema file does not exist: #{schema_path}" unless File.exist?(schema_path)

      regenerated_schema, regenerated_helpers = regenerate(definitions)

      check_file!(schema_path, File.read(schema_path), regenerated_schema)
      check_file!(helpers_path, committed(helpers_path), regenerated_helpers)

      true
    end

    def self.check_file!(path, committed, regenerated)
      return if committed == regenerated

      raise DriftError, <<~MSG
        EventEngine schema drift detected.

        The DSL definitions do not match #{path}.

        #{SchemaDiff.new(expected: committed, actual: regenerated)}
        Run:
          bin/rails event_engine:schema:dump

        And commit the updated schema file.
      MSG
    end

    def self.committed(path)
      File.exist?(path) ? File.read(path) : ""
    end

    def self.regenerate(definitions)
      Dir.mktmpdir("event_schema") do |dir|
        schema_path = File.join(dir, "event_schema.rb")
        EventEngine::EventSchemaDumper.dump!(definitions: definitions, path: schema_path)
        [File.read(schema_path), File.read(EventSchemaDumper.default_helpers_path(schema_path))]
      end
    end
  end
end
