require "test_helper"
require "ostruct"

module EventEngine
  class DefinitionPublisherTest < ActiveSupport::TestCase
    def cow_fed_schema
      EventDefinition::Schema.new(
        event_name: :cow_fed,
        event_version: 1,
        event_type: :domain,
        domain: :sales,
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
      EventEngine.reset_handlers!
    end

    test "publish builds the payload from the catalog schema and the raw inputs" do
      event = DefinitionPublisher.new.publish(
        :cow_fed,
        domain: :sales,
        inputs: { cow: OpenStruct.new(weight: 500) }
      )

      assert_equal({ weight: 500 }, event.payload)
    end

    test "publish carries the idempotency_key envelope key onto the built event" do
      event = DefinitionPublisher.new.publish(
        :cow_fed,
        domain: :sales,
        inputs: { cow: OpenStruct.new(weight: 500) },
        idempotency_key: "cow-fed-7"
      )

      assert_equal "cow-fed-7", event.idempotency_key
    end
  end
end
