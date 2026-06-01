require "test_helper"
require "event_engine/subagents"

module EventEngine
  class SubagentsTest < ActiveSupport::TestCase
    test "names include the define agent" do
      assert_includes EventEngine::Subagents.names, "event_engine-define"
    end

    test "content_for renders frontmatter with the agent name" do
      assert_includes EventEngine::Subagents.content_for("event_engine-define"), "name: event_engine-define"
    end
  end
end
