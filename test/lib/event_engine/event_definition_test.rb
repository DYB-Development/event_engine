require "test_helper"

module EventEngine
  class EventDefinitionTest < ActiveSupport::TestCase
    test "event_level can be declared and is stored on the definition" do
      definition = Class.new(EventEngine::EventDefinition) do
        event_name :levelled
        event_type :domain
        event_level 3
      end

      assert_equal 3, definition.instance_variable_get(:@event_level)
    end

    test "schema carries the declared event_level" do
      definition = Class.new(EventEngine::EventDefinition) do
        event_name :levelled
        event_type :domain
        event_level 4
      end

      assert_equal 4, definition.schema.event_level
    end
  end
end
