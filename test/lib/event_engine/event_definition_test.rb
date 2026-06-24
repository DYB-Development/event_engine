require "test_helper"

module EventEngine
  class EventDefinitionTest < ActiveSupport::TestCase
    test "schema carries the declared process_type" do
      definition = Class.new(EventEngine::EventDefinition) do
        event_name :processed
        event_type :domain
        process_type :broker
      end

      assert_equal :broker, definition.schema.process_type
    end

    test "an unknown process_type is a schema error" do
      definition = Class.new(EventEngine::EventDefinition) do
        event_name :processed
        event_type :domain
        process_type :bogus
      end

      refute definition.valid_schema?
    end

    test "schema carries the declared subject" do
      definition = Class.new(EventEngine::EventDefinition) do
        event_name :processed
        event_type :domain
        subject :feeding
      end

      assert_equal :feeding, definition.schema.subject
    end

    test "schema carries the declared domain" do
      definition = Class.new(EventEngine::EventDefinition) do
        event_name :processed
        event_type :domain
        domain :sales
      end

      assert_equal :sales, definition.schema.domain
    end
  end
end
