require "test_helper"
require "the_local"
require "event_engine/the_local"

module EventEngine
  class CompanionTest < ActiveSupport::TestCase
    setup do
      TheLocal.reset!
      EventEngine::Companion.register!
    end

    test "registers the core command interface" do
      assert_equal ["event_engine-info", "event_engine-install", "event_engine-develop"],
                   TheLocal.registry.agents.map(&:qualified_name)
    end

    test "committed agent files match the registration" do
      TheLocal.registry.agents.each do |agent|
        assert_equal agent.to_markdown, File.read(agent.source_path)
      end
    end
  end
end
