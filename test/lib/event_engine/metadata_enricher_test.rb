require "test_helper"
require "ostruct"

module EventEngine
  class MetadataEnricherTest < ActiveSupport::TestCase
    def cow_fed_schema
      EventDefinition::Schema.new(
        event_name: :cow_fed,
        event_version: 1,
        event_type: :domain,
        required_inputs: [:cow],
        optional_inputs: [],
        payload_fields: [{ name: :weight, required: true, from: :cow, attr: :weight }]
      )
    end

    setup do
      @previous_registry = EventEngine.schema_registry

      event_schema = EventSchema.new
      event_schema.register(cow_fed_schema)
      event_schema.finalize!

      registry = SchemaRegistry.new
      registry.load_from_schema!(event_schema)

      EventEngine.schema_registry = registry
    end

    teardown do
      EventEngine.schema_registry = @previous_registry
      EventEngine.configuration.metadata_defaults = nil
    end

    test "emitted event carries the default metadata envelope" do
      EventEngine.configuration.metadata_defaults = -> { { app_version: "1.0" } }

      event = EventEngine.emit(:cow_fed, inputs: { cow: OpenStruct.new(weight: 500) })

      assert_equal "1.0", event.metadata[:app_version]
    end

    test "call-site metadata wins over the default envelope on conflict" do
      EventEngine.configuration.metadata_defaults = -> { { actor_id: 1 } }

      event = EventEngine.emit(:cow_fed, inputs: { cow: OpenStruct.new(weight: 500) }, metadata: { actor_id: 99 })

      assert_equal 99, event.metadata[:actor_id]
    end

    test "a raising metadata_defaults does not break emission" do
      EventEngine.configuration.metadata_defaults = -> { raise "boom" }

      event = EventEngine.emit(:cow_fed, inputs: { cow: OpenStruct.new(weight: 500) }, metadata: { actor_id: 7 })

      assert_equal 7, event.metadata[:actor_id]
    end
  end
end
