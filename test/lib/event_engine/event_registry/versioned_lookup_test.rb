require "test_helper"

class EventRegistryVersionedLookupTest < ActiveSupport::TestCase
  def build_schema(name:, version:)
    EventEngine::CatalogEntry.new(
      event_name: name,
      event_version: version,
      event_type: :domain,
      required_inputs: [],
      optional_inputs: [],
      payload_fields: []
    )
  end

  setup do
    es = EventEngine::EventSchema.new
    es.register(build_schema(name: :cow_fed, version: 1))
    es.register(build_schema(name: :cow_fed, version: 2))
    es.register(build_schema(name: :pig_fed, version: 1))
    es.finalize!

    @registry = EventEngine::SchemaRegistry.new
    @registry.reset!
    @registry.load_from_schema!(es)
  end

  test "returns latest schema by default" do
    schema = @registry.schema(:cow_fed)
    assert_equal 2, schema.event_version
  end

  test "returns explicit historical version when requested" do
    schema = @registry.schema(:cow_fed, version: 1)
    assert_equal 1, schema.event_version
  end

  test "raises when requested version does not exist" do
    assert_raises(EventEngine::SchemaRegistry::UnknownEventError) do
      @registry.schema(:cow_fed, version: 99)
    end
  end
end
