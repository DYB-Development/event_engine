require "test_helper"

module EventEngine
  class SchemaSourcesTest < ActiveSupport::TestCase
    setup { @original_paths = EventEngine.configuration.publisher_schema_paths }
    teardown { EventEngine.configuration.publisher_schema_paths = @original_paths }

    test "uses the configured publisher schema paths when they are set" do
      EventEngine.configuration.publisher_schema_paths = [ "/configured/schema.json" ]

      assert_equal [ "/configured/schema.json" ], EventEngine.schema_sources
    end
  end
end
