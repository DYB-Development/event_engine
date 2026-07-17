require "test_helper"

class GemspecTest < ActiveSupport::TestCase
  def dependency_names
    gemspec_path = File.expand_path("../../../event_engine.gemspec", __dir__)
    Gem::Specification.load(gemspec_path).dependencies.map(&:name)
  end

  test "does not depend on the rails meta-gem" do
    refute_includes dependency_names, "rails"
  end
end
