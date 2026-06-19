require "event_engine/schema_diff"

module EventEngine
  class SchemaDriftGuard
    class DriftError < StandardError; end

    def self.check!(schema_path:, definitions:)
      raise DriftError, "Schema file does not exist: #{schema_path}" unless File.exist?(schema_path)

      committed = File.read(schema_path)
      regenerated = dump_to_string(definitions)

      return true if committed == regenerated

      raise DriftError, <<~MSG
        EventEngine schema drift detected.

        The DSL definitions do not match #{schema_path}.

        #{SchemaDiff.new(expected: committed, actual: regenerated)}
        Run:
          bin/rails event_engine:schema:dump

        And commit the updated schema file.
      MSG
    end

    def self.dump_to_string(definitions)
      Tempfile.create("event_schema") do |file|
        EventEngine::EventSchemaDumper.dump!(
          definitions: definitions,
          path: file.path
        )
        File.read(file.path)
      end
    end
  end
end
