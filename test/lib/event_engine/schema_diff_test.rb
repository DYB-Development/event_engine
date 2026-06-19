require "test_helper"
require "event_engine/schema_diff"

class EventEngineSchemaDiffTest < ActiveSupport::TestCase
  test "reports no change when expected and actual match" do
    diff = EventEngine::SchemaDiff.new(expected: "a\n", actual: "a\n")

    assert_not diff.changed?
  end
end
