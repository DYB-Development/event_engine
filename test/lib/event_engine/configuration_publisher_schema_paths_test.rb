require "test_helper"

class ConfigurationPublisherSchemaPathsTest < ActiveSupport::TestCase
  test "defaults the publisher schema paths to an empty list" do
    assert_equal [], EventEngine::Configuration.new.publisher_schema_paths
  end
end
