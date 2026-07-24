require "test_helper"
require "the_local/provider_build"

class TheLocalDriftTest < ActiveSupport::TestCase
  test "committed agents match the rendered build" do
    gem_root = File.expand_path("..", __dir__)

    TheLocal::ProviderBuild.new(gem_root).agents.each do |agent|
      assert_equal agent.to_markdown, File.read(agent.source_path)
    end
  end
end
