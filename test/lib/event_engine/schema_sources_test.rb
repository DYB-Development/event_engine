require "test_helper"

module EventEngine
  class SchemaSourcesTest < ActiveSupport::TestCase
    setup { @original_paths = EventEngine.configuration.publisher_schema_paths }
    teardown { EventEngine.configuration.publisher_schema_paths = @original_paths }

    test "uses the configured publisher schema paths when they are set" do
      EventEngine.configuration.publisher_schema_paths = [ "/configured/schema.json" ]

      assert_equal [ "/configured/schema.json" ], EventEngine.schema_sources
    end

    test "discovers the registered packs' schema paths when none are configured" do
      port = Class.new { def self.pack_schema_paths = [ "/packs/marketing/schema.json" ] }

      assert_equal [ "/packs/marketing/schema.json" ], EventEngine.discovered_schema_paths(port)
    end

    test "discovers nothing when no pack has loaded the definition port" do
      assert_equal [], EventEngine.discovered_schema_paths(nil)
    end
  end
end
