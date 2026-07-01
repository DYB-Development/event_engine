require "test_helper"
require "tempfile"

module EventEngine
  class EventEngineHelpersWriterTest < ActiveSupport::TestCase
    def schema_with(required_inputs:, optional_inputs: [])
      EventSchema.new.tap do |event_schema|
        event_schema.register(
          EventDefinition::Schema.new(
            event_name: :cow_fed,
            event_version: 1,
            event_type: :domain,
            required_inputs: required_inputs,
            optional_inputs: optional_inputs,
            payload_fields: []
          )
        )
        event_schema.finalize!
      end
    end

    def generate(event_schema)
      Tempfile.create(["helpers", ".rb"]) do |file|
        EventEngineHelpersWriter.write(file.path, event_schema)
        return File.read(file.path)
      end
    end

    test "writes a real def for each event" do
      source = generate(schema_with(required_inputs: [:cow]))

      assert_includes source, "def cow_fed"
    end
  end
end
