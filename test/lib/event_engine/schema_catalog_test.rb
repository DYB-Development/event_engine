require "test_helper"

class SchemaCatalogTest < ActiveSupport::TestCase
  def schema(event_name:, subject: nil, payload_fields: [])
    EventEngine::EventDefinition::Schema.new(
      event_name: event_name,
      event_version: 1,
      event_type: :domain,
      subject: subject,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: payload_fields
    )
  end

  def schema_registry_for(*schemas)
    event_schema = EventEngine::EventSchema.new
    schemas.each { |s| event_schema.register(s) }
    event_schema.finalize!

    registry = EventEngine::SchemaRegistry.new
    registry.reset!
    registry.load_from_schema!(event_schema)
    registry
  end

  def catalog_for(*schemas, subjects: EventEngine::SubjectRegistry.new)
    EventEngine::SchemaCatalog.new(
      schema_registry: schema_registry_for(*schemas),
      subject_registry: subjects
    )
  end

  test "renders a catalog heading" do
    catalog = catalog_for(schema(event_name: :cow_fed))

    assert_includes catalog.to_markdown, "# Event Catalog"
  end

  test "lists each event with its version" do
    catalog = catalog_for(schema(event_name: :cow_fed))

    assert_includes catalog.to_markdown, "## cow_fed (v1)"
  end

  test "includes the event type" do
    catalog = catalog_for(schema(event_name: :cow_fed))

    assert_includes catalog.to_markdown, "- Type: domain"
  end
end
