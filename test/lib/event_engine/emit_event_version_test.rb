require "test_helper"
require "ostruct"
require "tempfile"
require "json"

module EventEngine
  class EmitEventVersionTest < ActiveSupport::TestCase
    def cow_fed_schema(version)
      CatalogEntry.new(
        event_name: :cow_fed,
        event_version: version,
        event_type: :domain,
        required_inputs: [:cow],
        optional_inputs: [],
        payload_fields: [{ name: :weight, required: true, from: :cow, attr: :weight }]
      )
    end

    setup do
      @previous_registry = EventEngine.schema_registry
      @catalog = Tempfile.new(["catalog", ".json"])
      @catalog.write(JSON.pretty_generate([cow_fed_schema(1).to_h, cow_fed_schema(2).to_h]))
      @catalog.close

      EventEngine.boot_from_schema!(
        schema_path: @catalog.path,
        registry: SchemaRegistry.new
      )
    end

    teardown do
      EventEngine.schema_registry = @previous_registry
      EventEngine.reset_handlers!
      @catalog.unlink
    end

    test "emit builds the requested version when event_version is given" do
      event = EventEngine.emit(:cow_fed, inputs: { cow: OpenStruct.new(weight: 500) }, event_version: 1)

      assert_equal 1, event.event_version
    end
  end
end
