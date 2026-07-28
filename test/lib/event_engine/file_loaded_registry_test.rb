require "test_helper"

class FileLoadedRegistryTest < ActiveSupport::TestCase
  def build_schema(event_name:, version:)
    EventEngine::CatalogEntry.new(
      event_name: event_name,
      event_version: version,
      event_type: :domain,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: [{ name: :weight, from: :cow, attr: :weight }]
    )
  end

  test "register stores schemas in underlying EventSchema" do
    registry = EventEngine::SchemaRegistry.new

    schema = build_schema(event_name: :cow_fed, version: 1)
    registry.register(schema)

    assert_equal schema, registry.event_schema.schema_for(:cow_fed, 1)
  end

  test "exposes read-only EventSchema query methods" do
    registry = EventEngine::SchemaRegistry.new

    v1 = build_schema(event_name: :cow_fed, version: 1)
    v2 = build_schema(event_name: :cow_fed, version: 2)

    registry.register(v1)
    registry.register(v2)

    assert_equal [:cow_fed], registry.events
    assert_equal [1, 2], registry.versions_for(:cow_fed)
    assert_equal v2, registry.latest_for(:cow_fed)
  end

  test "finalize! freezes underlying EventSchema" do
    registry = EventEngine::SchemaRegistry.new
    registry.register(build_schema(event_name: :cow_fed, version: 1))

    registry.finalize!

    assert registry.event_schema.frozen?
  end
end
