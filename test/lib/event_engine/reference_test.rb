require "test_helper"
require "event_engine/reference"

module EventEngine
  class ReferenceTest < ActiveSupport::TestCase
    test "content documents the event definition DSL" do
      assert_includes EventEngine::Reference.content, "event_name"
    end

    test "content guides how to choose an event level" do
      assert_includes EventEngine::Reference.content, "Choosing an event level"
    end
  end
end
