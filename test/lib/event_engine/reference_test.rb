require "test_helper"
require "event_engine/reference"

module EventEngine
  class ReferenceTest < ActiveSupport::TestCase
    test "content documents the event definition DSL" do
      assert_includes EventEngine::Reference.content, "event_name"
    end

    test "content documents process_type routing" do
      assert_includes EventEngine::Reference.content, "process_type"
    end

    test "content documents the schema dump command" do
      assert_includes EventEngine::Reference.content, "event_engine:schema:dump"
    end
  end
end
