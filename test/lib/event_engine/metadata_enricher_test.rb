require "test_helper"
require "ostruct"

module EventEngine
  class MetadataEnricherTest < ActiveSupport::TestCase
    include EventEngineTestHelpers

    class CowFed < EventDefinition
      event_name :cow_fed
      event_type :domain

      input :cow
      required_payload :weight, from: :cow, attr: :weight
    end

    setup do
      @helpers_snapshot = snapshot_event_engine_helpers

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

      EventEngine.install_helpers(registry: registry)
    end

    teardown do
      restore_event_engine_helpers(@helpers_snapshot)
      EventEngine.configuration.metadata_defaults = nil
    end

    test "emitted event carries the default metadata envelope" do
      EventEngine.configuration.metadata_defaults = -> { { app_version: "1.0" } }

      event = EventEngine.cow_fed(cow: OpenStruct.new(weight: 500))

      assert_equal "1.0", event.metadata[:app_version]
    end

    test "call-site metadata wins over the default envelope on conflict" do
      EventEngine.configuration.metadata_defaults = -> { { actor_id: 1 } }

      event = EventEngine.cow_fed(cow: OpenStruct.new(weight: 500), metadata: { actor_id: 99 })

      assert_equal 99, event.metadata[:actor_id]
    end

    test "a raising metadata_defaults does not break emission" do
      EventEngine.configuration.metadata_defaults = -> { raise "boom" }

      event = EventEngine.cow_fed(cow: OpenStruct.new(weight: 500), metadata: { actor_id: 7 })

      assert_equal 7, event.metadata[:actor_id]
    end
  end
end
