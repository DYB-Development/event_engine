require "test_helper"

class EventRegistryDomainScopedLookupTest < ActiveSupport::TestCase
  def build_schema(domain:)
    EventEngine::EventDefinition::Schema.new(
      event_name: :cow_fed,
      event_version: 1,
      event_type: :domain,
      domain: domain,
      required_inputs: [],
      optional_inputs: [],
      payload_fields: []
    )
  end

  setup do
    es = EventEngine::EventSchema.new
    es.register(build_schema(domain: :sales))
    es.register(build_schema(domain: :marketing))
    es.finalize!

    @registry = EventEngine::SchemaRegistry.new
    @registry.reset!
    @registry.load_from_schema!(es)
  end

  test "scopes the lookup to the requested domain" do
    schema = @registry.schema(:cow_fed, domain: :marketing)
    assert_equal :marketing, schema.domain
  end

  test "scopes the lookup when the backing store is itself a registry" do
    nested = EventEngine::SchemaRegistry.new
    nested.reset!
    nested.load_from_schema!(@registry)

    schema = nested.schema(:cow_fed, domain: :marketing)
    assert_equal :marketing, schema.domain
  end
end
