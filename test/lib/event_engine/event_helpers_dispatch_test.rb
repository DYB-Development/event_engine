require "test_helper"
require "ostruct"

module EventEngine
  class EventHelpersDispatchTest < ActiveSupport::TestCase
    def cow_fed_schema
      EventDefinition::Schema.new(
        event_name: :cow_fed,
        event_version: 1,
        event_type: :domain,
        process_type: :broker,
        subject: :feeding,
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

    test "emit dispatches a built event to a registered handler" do
      received = []
      EventEngine.register_handler(->(event) { received << event }, process_types: :all)

      EventEngine.emit(:cow_fed, inputs: { cow: OpenStruct.new(weight: 500) })

      assert_equal 1, received.size
    end

    test "the dispatched event carries the declared process_type" do
      received = []
      EventEngine.register_handler(->(event) { received << event }, process_types: :all)

      EventEngine.emit(:cow_fed, inputs: { cow: OpenStruct.new(weight: 500) })

      assert_equal :broker, received.first.process_type
    end

    test "the dispatched event carries the declared subject" do
      received = []
      EventEngine.register_handler(->(event) { received << event }, process_types: :all)

      EventEngine.emit(:cow_fed, inputs: { cow: OpenStruct.new(weight: 500) })

      assert_equal :feeding, received.first.subject
    end

    test "the dispatched event carries the declared domain" do
      received = []
      EventEngine.register_handler(->(event) { received << event }, process_types: :all)

      EventEngine.emit(:cow_fed, inputs: { cow: OpenStruct.new(weight: 500) })

      assert_equal :sales, received.first.domain
    end
  end
end
