require "test_helper"

module EventEngine
  class SchemaProcessTypeBackCompatTest < ActiveSupport::TestCase
    test "legacy event_level backfills process_type when absent" do
      schema = EventDefinition::Schema.new(event_name: :cow_fed, event_level: 3)

      assert_equal :durable, schema.process_type
    end
  end
end
