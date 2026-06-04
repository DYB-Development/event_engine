require "test_helper"
require "ostruct"

module EventEngine
  class EventHelpersTest < ActiveSupport::TestCase
    include EventEngineTestHelpers
    class CowFed < EventDefinition
      event_name :cow_fed
      event_type :domain

      input :cow
      required_payload :weight, from: :cow, attr: :weight
    end

    setup do
      @helpers_snapshot = snapshot_event_engine_helpers

      # 1. Compile DSL → schema
      compiled = DslCompiler.compile([CowFed])
      compiled.finalize!

      # 2. Merge into EventSchema (no file in this test)
      event_schema = EventSchema.new
      compiled.events.each do |event|
        schema = compiled.latest_for(event).dup
        schema.event_version = 1
        event_schema.register(schema)
      end
      event_schema.finalize!

      registry = SchemaRegistry.new
      # 3. Load runtime registry from schema
      registry.reset!
      registry.load_from_schema!(event_schema)

      # 4. Install helpers from runtime registry
      EventEngine.install_helpers(registry: registry)
    end

    test "defines helper method on EventEngine" do
      assert EventEngine.respond_to?(:cow_fed)
    end

    test "helper passes aggregate fields through to the built event" do
      cow = OpenStruct.new(weight: 500)

      event = EventEngine.cow_fed(
        cow: cow,
        aggregate_type: "Cow",
        aggregate_id: "cow-7",
        aggregate_version: 2
      )

      assert_equal "Cow", event.aggregate_type
      assert_equal "cow-7", event.aggregate_id
      assert_equal 2, event.aggregate_version
    end

    teardown do
      restore_event_engine_helpers(@helpers_snapshot)
    end
  end
end
