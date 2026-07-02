require "test_helper"
require "ostruct"

module EventEngine
  class EventHelpersDispatchTest < ActiveSupport::TestCase
    class CowFed < EventDefinition
      event_name :cow_fed
      event_type :domain
      process_type :broker
      subject :feeding
      domain :sales

      input :cow
      required_payload :weight, from: :cow, attr: :weight
    end

    setup do
      @previous_registry = EventEngine.schema_registry

      EventEngine.define_subjects { subject :feeding }

      compiled = DslCompiler.compile([ CowFed ])
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
      EventEngine.reset_subjects!
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
