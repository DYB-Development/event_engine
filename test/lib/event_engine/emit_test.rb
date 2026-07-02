require "test_helper"
require "ostruct"

module EventEngine
  class EmitTest < ActiveSupport::TestCase
    class CowFed < EventDefinition
      event_name :cow_fed
      event_type :domain

      input :cow
      required_payload :weight, from: :cow, attr: :weight
    end

    setup do
      @previous_registry = EventEngine.schema_registry

      compiled = DslCompiler.compile([CowFed])
      compiled.finalize!

      event_schema = EventSchema.new
      compiled.events.each do |event|
        schema = compiled.latest_for(event).dup
        schema.event_version = 1
        event_schema.register(schema)
      end
      event_schema.finalize!

      registry = SchemaRegistry.new
      registry.load_from_schema!(event_schema)
      EventEngine.schema_registry = registry
    end

    teardown do
      EventEngine.schema_registry = @previous_registry
      EventEngine.reset_handlers!
    end

    test "emit builds the payload from the given inputs" do
      cow = OpenStruct.new(weight: 500)

      event = EventEngine.emit(:cow_fed, inputs: { cow: cow })

      assert_equal({ weight: 500 }, event.payload)
    end

    test "emit dispatches the built event to a registered handler" do
      received = []
      EventEngine.register_handler(->(event) { received << event }, process_types: :all)

      EventEngine.emit(:cow_fed, inputs: { cow: OpenStruct.new(weight: 500) })

      assert_equal 1, received.size
    end

    test "emit passes aggregate fields through to the built event" do
      event = EventEngine.emit(
        :cow_fed,
        inputs: { cow: OpenStruct.new(weight: 500) },
        aggregate_type: "Cow",
        aggregate_id: "cow-7",
        aggregate_version: 2
      )

      assert_equal "cow-7", event.aggregate_id
    end

    test "emit raises when a required input is missing" do
      assert_raises(ArgumentError) do
        EventEngine.emit(:cow_fed, inputs: {})
      end
    end

    test "emit raises when an unknown input is given" do
      assert_raises(ArgumentError) do
        EventEngine.emit(:cow_fed, inputs: { cow: OpenStruct.new(weight: 500), horse: 1 })
      end
    end

    test "emit selects a specific version via event_version:" do
      EventEngine.schema_registry = two_version_registry

      event = EventEngine.emit(
        :barn_built,
        inputs: { barn: OpenStruct.new(color: "red", size: "large") },
        event_version: 1
      )

      assert_equal 1, event.event_version
    end

    def two_version_registry
      event_schema = EventSchema.new
      event_schema.register(barn_schema(version: 1, field: :color))
      event_schema.register(barn_schema(version: 2, field: :size))
      event_schema.finalize!

      SchemaRegistry.new.tap { |registry| registry.load_from_schema!(event_schema) }
    end

    def barn_schema(version:, field:)
      EventDefinition::Schema.new(
        event_name: :barn_built,
        event_version: version,
        event_type: :domain,
        required_inputs: [:barn],
        optional_inputs: [],
        payload_fields: [{ name: field, from: :barn, attr: field }]
      )
    end
  end
end
