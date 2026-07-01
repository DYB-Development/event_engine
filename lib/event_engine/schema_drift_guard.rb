require "event_engine/schema_diff"
require "tmpdir"

module EventEngine
  class SchemaDriftGuard
    class DriftError < StandardError; end

    def self.check!(schema_path:, definitions:, helpers_path: nil, json_path: nil)
      raise DriftError, "Schema file does not exist: #{schema_path}" unless File.exist?(schema_path)

      regenerated = regenerate(definitions, helpers: !helpers_path.nil?, json: !json_path.nil?)

      check_drift!(schema_path, regenerated[:schema], "schema")
      check_helpers_drift!(helpers_path, regenerated[:helpers]) if helpers_path
      check_json_drift!(json_path, regenerated[:json]) if json_path

      true
    end

    def self.check_helpers_drift!(helpers_path, regenerated)
      raise DriftError, "Helpers file does not exist: #{helpers_path}" unless File.exist?(helpers_path)

      check_drift!(helpers_path, regenerated, "helpers")
    end

    def self.check_json_drift!(json_path, regenerated)
      raise DriftError, "JSON schema file does not exist: #{json_path}" unless File.exist?(json_path)

      check_drift!(json_path, regenerated, "json schema")
    end

    def self.check_drift!(path, regenerated, label)
      committed = File.read(path)
      return if committed == regenerated

      raise DriftError, <<~MSG
        EventEngine #{label} drift detected.

        The DSL definitions do not match #{path}.

        #{SchemaDiff.new(expected: committed, actual: regenerated)}
        Run:
          bin/rails event_engine:schema:dump

        And commit the updated file.
      MSG
    end

    def self.regenerate(definitions, helpers:, json:)
      Dir.mktmpdir do |dir|
        schema_path = File.join(dir, "event_schema.rb")
        helpers_path = File.join(dir, "event_engine_helpers.rb")
        json_path = File.join(dir, "event_schema.json")

        EventEngine::EventSchemaDumper.dump!(
          definitions: definitions,
          path: schema_path,
          helpers_path: helpers ? helpers_path : nil,
          json_path: json ? json_path : nil
        )

        {
          schema: File.read(schema_path),
          helpers: helpers ? File.read(helpers_path) : nil,
          json: json ? File.read(json_path) : nil
        }
      end
    end
  end
end
