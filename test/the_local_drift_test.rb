# frozen_string_literal: true

require "test_helper"
require "the_local/provider_build"

class TheLocalDriftTest < Minitest::Test
  def test_committed_agents_match_the_rendered_build
    gem_root = File.expand_path("..", __dir__)
    TheLocal::ProviderBuild.new(gem_root).agents.each do |agent|
      assert_equal agent.to_markdown, File.read(agent.source_path)
    end
  end
end
