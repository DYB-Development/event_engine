require "test_helper"
require "tempfile"
require "ostruct"

module EventEngine
  class EventEngineHelpersWriterTest < ActiveSupport::TestCase
    include EventEngineTestHelpers
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

    test "a required input becomes a required keyword" do
      source = generate(schema_with(required_inputs: [:cow]))

      assert_includes source, "cow:,"
    end

    test "an optional input becomes a keyword defaulting to nil" do
      source = generate(schema_with(required_inputs: [:cow], optional_inputs: [:note]))

      assert_includes source, "note: nil"
    end

    test "the envelope keys are delegated to emit" do
      source = generate(schema_with(required_inputs: [:cow]))

      assert_includes source, "metadata: metadata"
    end

    test "the generated file defines a real helper that emits" do
      helpers_snapshot = snapshot_event_engine_helpers
      previous_registry = EventEngine.schema_registry
      event_schema = schema_with(required_inputs: [:cow])
      EventEngine.schema_registry =
        SchemaRegistry.new.tap { |registry| registry.load_from_schema!(event_schema) }

      received = []
      EventEngine.register_handler(->(event) { received << event }, process_types: :all)

      Tempfile.create(["helpers", ".rb"]) do |file|
        EventEngineHelpersWriter.write(file.path, event_schema)
        load file.path

        EventEngine.cow_fed(cow: OpenStruct.new(weight: 500))
      end

      assert_equal 1, received.size
    ensure
      restore_event_engine_helpers(helpers_snapshot)
      EventEngine.schema_registry = previous_registry
      EventEngine.reset_handlers!
    end

    test "the generated signature raises a native ArgumentError for a missing required input" do
      helpers_snapshot = snapshot_event_engine_helpers
      event_schema = schema_with(required_inputs: [:cow])

      Tempfile.create(["helpers", ".rb"]) do |file|
        EventEngineHelpersWriter.write(file.path, event_schema)
        load file.path

        assert_raises(ArgumentError) { EventEngine.cow_fed }
      end
    ensure
      restore_event_engine_helpers(helpers_snapshot)
    end
  end
end
