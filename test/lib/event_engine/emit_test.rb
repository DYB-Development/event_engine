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
      registry.reset!
      registry.load_from_schema!(event_schema)

      @previous_registry = EventEngine.active_registry
      EventEngine.active_registry = registry
    end

    teardown do
      EventEngine.active_registry = @previous_registry
      EventEngine.reset_handlers!
    end

    test "emit builds and dispatches an event from the active registry" do
      event = EventEngine.emit(:cow_fed, inputs: { cow: OpenStruct.new(weight: 500) })

      assert_equal 500, event.payload[:weight]
    end
  end
end
