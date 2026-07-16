require "test_helper"
require "tmpdir"
require "ostruct"

class EngineBootTest < ActiveSupport::TestCase
  include EventEngineTestHelpers

  def cow_fed_schema
    EventEngine::EventSchema.new.tap do |event_schema|
      event_schema.register(
        EventEngine::EventDefinition::Schema.new(
          event_name: :cow_fed,
          event_version: 1,
          event_type: :domain,
          domain: :sales,
          required_inputs: [:cow],
          optional_inputs: [],
          payload_fields: [{ name: :weight, from: :cow, attr: :weight }]
        )
      )
      event_schema.finalize!
    end
  end

  test "engine boot loads the schema and generated helpers so an event can be emitted" do
    helpers_snapshot = snapshot_event_engine_helpers
    previous_registry = EventEngine.schema_registry
    event_schema = cow_fed_schema

    Dir.mktmpdir do |dir|
      schema_path = File.join(dir, "event_schema.json")
      helpers_path = File.join(dir, "event_engine_helpers.rb")
      EventEngine::EventSchemaJsonWriter.write(schema_path, event_schema)
      EventEngine::EventEngineHelpersWriter.write(helpers_path, event_schema)

      EventEngine::Engine.send(:boot!, schema_path: schema_path, helpers_path: helpers_path)

      event = EventEngine::Sales.cow_fed(cow: OpenStruct.new(weight: 500))
      assert_equal 500, event.payload[:weight]
    end
  ensure
    restore_event_engine_helpers(helpers_snapshot)
    EventEngine.schema_registry = previous_registry
  end
end
