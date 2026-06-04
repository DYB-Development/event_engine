require "test_helper"
require "ostruct"

module EventEngine
  class EventHelpersDispatchTest < ActiveSupport::TestCase
    include EventEngineTestHelpers

    class CowFed < EventDefinition
      event_name :cow_fed
      event_type :domain

      input :cow
      required_payload :weight, from: :cow, attr: :weight
    end

    setup do
      @helpers_snapshot = snapshot_event_engine_helpers

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
      registry.reset!
      registry.load_from_schema!(event_schema)

      EventEngine.install_helpers(registry: registry)
    end

    teardown do
      restore_event_engine_helpers(@helpers_snapshot)
      EventEngine.reset_handlers!
    end

    test "the helper dispatches a built event to a registered handler" do
      received = []
      EventEngine.register_handler(->(event) { received << event }, levels: :all)

      EventEngine.cow_fed(cow: OpenStruct.new(weight: 500))

      assert_equal 1, received.size
    end
  end
end
