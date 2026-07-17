require "test_helper"

class ConfigurationResolverTest < ActiveSupport::TestCase
  test "defaults the resolver to the catch-all DefaultResolver" do
    assert_instance_of EventEngine::DefaultResolver, EventEngine::Configuration.new.resolver
  end
end
