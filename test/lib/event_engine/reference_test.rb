require "test_helper"
require "event_engine/reference"

module EventEngine
  class ReferenceTest < ActiveSupport::TestCase
    test "content documents the event definition DSL" do
      assert_includes EventEngine::Reference.content, "event_name"
    end
  end
end
