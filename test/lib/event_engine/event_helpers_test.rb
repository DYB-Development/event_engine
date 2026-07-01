require "test_helper"
require "ostruct"
require "tmpdir"

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
      @previous_registry = EventEngine.active_registry

      @dir = Dir.mktmpdir
      schema_path = File.join(@dir, "event_schema.rb")
      EventEngine::EventSchemaDumper.dump!(definitions: [CowFed], path: schema_path)

      EventEngine.boot_from_schema!(schema_path: schema_path, registry: SchemaRegistry.new)
    end

    teardown do
      restore_event_engine_helpers(@helpers_snapshot)
      EventEngine.active_registry = @previous_registry
      FileUtils.remove_entry(@dir) if @dir
    end

    test "generates a real helper method on EventEngine" do
      assert EventEngine.respond_to?(:cow_fed)
    end

    test "the generated helper passes aggregate fields through to the built event" do
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
  end
end
