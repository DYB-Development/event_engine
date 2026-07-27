require "test_helper"
require "the_local/provider_check"

class TheLocalProviderTest < ActiveSupport::TestCase
  GEM_ROOT = File.expand_path("..", __dir__)

  def test_the_trio_of_locals_is_committed
    assert_equal %w[event_engine-develop.md event_engine-info.md event_engine-install.md],
                 Dir.children(File.join(GEM_ROOT, "the_local", "agents")).sort
  end
end
