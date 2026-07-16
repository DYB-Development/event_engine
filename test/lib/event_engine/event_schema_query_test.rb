require "test_helper"

class EventSchemaQueryTest < ActiveSupport::TestCase
  def build_schema(event_name:, version:, domain: nil)
    EventEngine::EventDefinition::Schema.new(
      event_name: event_name,
      event_version: version,
      event_type: :domain,
      domain: domain,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: [{ name: :weight, from: :cow, attr: :weight }]
    )
  end

  test "events returns unique event names" do
    es = EventEngine::EventSchema.new
    es.register(build_schema(event_name: :cow_fed, version: 1))
    es.register(build_schema(event_name: :cow_fed, version: 2))
    es.register(build_schema(event_name: :pig_fed, version: 1))

    assert_equal [:cow_fed, :pig_fed], es.events.sort
  end

  test "versions_for returns sorted versions for an event" do
    es = EventEngine::EventSchema.new
    es.register(build_schema(event_name: :cow_fed, version: 2))
    es.register(build_schema(event_name: :cow_fed, version: 1))

    assert_equal [1, 2], es.versions_for(:cow_fed)
  end

  test "schema_for returns specific version" do
    es = EventEngine::EventSchema.new
    schema = build_schema(event_name: :cow_fed, version: 1)
    es.register(schema)

    assert_equal schema, es.schema_for(:cow_fed, 1)
  end

  test "latest_for returns highest version for an event" do
    es = EventEngine::EventSchema.new
    v1 = build_schema(event_name: :cow_fed, version: 1)
    v2 = build_schema(event_name: :cow_fed, version: 2)
    es.register(v1)
    es.register(v2)

    assert_equal v2, es.latest_for(:cow_fed)
  end

  test "latest_for returns nil when event is unknown" do
    es = EventEngine::EventSchema.new
    assert_nil es.latest_for(:missing)
  end

  test "schema_for resolves within the requested domain" do
    es = EventEngine::EventSchema.new
    sales = build_schema(event_name: :deal_won, version: 1, domain: :sales)
    marketing = build_schema(event_name: :deal_won, version: 1, domain: :marketing)
    es.register(sales)
    es.register(marketing)

    assert_equal sales, es.schema_for(:deal_won, 1, domain: :sales)
  end
end
