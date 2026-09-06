require "test_helper"
require "tempfile"
require "json"

class SliceSurvivesBootTest < ActiveSupport::TestCase
  setup { @previous_registry = EventEngine.schema_registry }
  teardown { EventEngine.schema_registry = @previous_registry }

  def write_json(*schemas)
    file = Tempfile.new(["event_schema", ".json"])
    file.write(JSON.pretty_generate(schemas.map(&:to_h)))
    file.close
    file
  end

  def build_schema(event_name, domain)
    EventEngine::CatalogEntry.new(
      event_name: event_name,
      event_version: 1,
      event_type: :domain,
      domain: domain,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: []
    )
  end

  test "a slice registered before boot still resolves after boot" do
    EventEngine.schema_registry = EventEngine::SchemaRegistry.new
    slice = write_json(build_schema(:pig_weighed, :swine))
    catalog = write_json(build_schema(:cow_fed, :cattle))

    EventEngine.register_slice!(schema_path: slice.path)
    EventEngine.boot_from_schema!(
      schema_path: catalog.path,
      registry: EventEngine::SchemaRegistry.new
    )

    assert_equal :pig_weighed, EventEngine.schema_registry.schema(:pig_weighed).event_name
  ensure
    slice.unlink
    catalog.unlink
  end

  test "a slice registered after boot resolves alongside the catalog" do
    EventEngine.schema_registry = EventEngine::SchemaRegistry.new
    slice = write_json(build_schema(:pig_weighed, :swine))
    catalog = write_json(build_schema(:cow_fed, :cattle))

    EventEngine.boot_from_schema!(
      schema_path: catalog.path,
      registry: EventEngine::SchemaRegistry.new
    )
    EventEngine.register_slice!(schema_path: slice.path)

    assert_equal :cow_fed, EventEngine.schema_registry.schema(:cow_fed).event_name
  ensure
    slice.unlink
    catalog.unlink
  end

  test "an event the catalog already carries does not break boot when a slice registered it too" do
    EventEngine.schema_registry = EventEngine::SchemaRegistry.new
    slice = write_json(build_schema(:cow_fed, :cattle))
    catalog = write_json(build_schema(:cow_fed, :cattle))

    EventEngine.register_slice!(schema_path: slice.path)

    assert_nothing_raised do
      EventEngine.boot_from_schema!(
        schema_path: catalog.path,
        registry: EventEngine::SchemaRegistry.new
      )
    end
  ensure
    slice.unlink
    catalog.unlink
  end
end
