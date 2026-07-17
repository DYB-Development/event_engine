require "test_helper"

class GemspecTest < ActiveSupport::TestCase
  def dependency_names
    gemspec_path = File.expand_path("../../../event_engine.gemspec", __dir__)
    Gem::Specification.load(gemspec_path).dependencies.map(&:name)
  end

  test "does not depend on the rails meta-gem" do
    refute_includes dependency_names, "rails"
  end

  test "depends on railties for the Rails adapter" do
    assert_includes dependency_names, "railties"
  end

  test "depends on activesupport for the core conveniences it uses" do
    assert_includes dependency_names, "activesupport"
  end
end
