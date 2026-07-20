require "test_helper"
require "tempfile"
require "json"

class SchemaCatalogBuilderTest < ActiveSupport::TestCase
  def write_source(*schemas)
    file = Tempfile.new(["pack_schema", ".json"])
    file.write(JSON.pretty_generate(schemas.map(&:to_h)))
    file.close
    file
  end

  def build_schema(event_name)
    EventEngine::EventDefinition::Schema.new(
      event_name: event_name,
      event_version: 1,
      event_type: :domain,
      domain: :sales,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: []
    )
  end

  test "aggregates a pack's event into the catalog file" do
    pack = write_source(build_schema(:cow_fed))
    catalog = Tempfile.new(["catalog", ".json"])

    EventEngine::SchemaCatalogBuilder.build(sources: [pack.path], catalog_path: catalog.path)

    registry = EventEngine::EventSchemaJsonLoader.load(catalog.path)
    assert_includes registry.events, :cow_fed
  ensure
    pack.unlink
    catalog.unlink
  end

  test "aggregates events from multiple packs into one catalog" do
    cattle = write_source(build_schema(:cow_fed))
    swine = write_source(build_schema(:pig_weighed))
    catalog = Tempfile.new(["catalog", ".json"])

    EventEngine::SchemaCatalogBuilder.build(
      sources: [cattle.path, swine.path],
      catalog_path: catalog.path
    )

    registry = EventEngine::EventSchemaJsonLoader.load(catalog.path)
    assert_equal [:cow_fed, :pig_weighed], registry.events.sort
  ensure
    cattle.unlink
    swine.unlink
    catalog.unlink
  end
end
