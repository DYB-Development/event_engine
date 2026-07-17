require "test_helper"

class ConfigurationSchemaPathTest < ActiveSupport::TestCase
  test "defaults the schema path to a plain relative path without touching Rails" do
    assert_equal "db/event_schema.json", EventEngine::Configuration.new.schema_path
  end
end
