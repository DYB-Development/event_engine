require "test_helper"

class EventSchemaTest < ActiveSupport::TestCase
  test "register stores schemas by event_name and event_version" do
    schema = EventEngine::EventDefinition::Schema.new(
      event_name: :cow_fed,
      event_version: 1,
      event_type: :domain,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: [{ name: :weight, from: :cow, attr: :weight }]
    )

    event_schema = EventEngine::EventSchema.new
    event_schema.register(schema)

    by_event = event_schema.schemas_by_event

    assert by_event.key?([nil, :cow_fed])
    assert by_event[[nil, :cow_fed]].key?(1)
    assert_equal schema, by_event[[nil, :cow_fed]][1]
  end

  test "register supports multiple versions for the same event_name" do
    v1 = EventEngine::EventDefinition::Schema.new(
      event_name: :cow_fed,
      event_version: 1,
      event_type: :domain,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: [{ name: :weight, from: :cow, attr: :weight }]
    )

    v2 = EventEngine::EventDefinition::Schema.new(
      event_name: :cow_fed,
      event_version: 2,
      event_type: :domain,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: [{ name: :age, from: :cow, attr: :age }]
    )

    event_schema = EventEngine::EventSchema.new
    event_schema.register(v1)
    event_schema.register(v2)

    versions = event_schema.schemas_by_event[[nil, :cow_fed]].keys.sort
    assert_equal [1, 2], versions
  end

  test "register allows the same event_name under different domains" do
    sales = EventEngine::EventDefinition::Schema.new(
      event_name: :deal_won,
      event_version: 1,
      event_type: :domain,
      domain: :sales,
      required_inputs: [],
      optional_inputs: [],
      payload_fields: []
    )

    marketing = EventEngine::EventDefinition::Schema.new(
      event_name: :deal_won,
      event_version: 1,
      event_type: :domain,
      domain: :marketing,
      required_inputs: [],
      optional_inputs: [],
      payload_fields: []
    )

    event_schema = EventEngine::EventSchema.new
    event_schema.register(sales)

    assert_nothing_raised { event_schema.register(marketing) }
  end

  test "register raises a named error on a duplicate (domain, event_name)" do
    a = EventEngine::EventDefinition::Schema.new(
      event_name: :deal_won,
      event_version: 1,
      event_type: :domain,
      domain: :sales,
      required_inputs: [],
      optional_inputs: [],
      payload_fields: []
    )

    b = EventEngine::EventDefinition::Schema.new(
      event_name: :deal_won,
      event_version: 1,
      event_type: :domain,
      domain: :sales,
      required_inputs: [],
      optional_inputs: [],
      payload_fields: []
    )

    event_schema = EventEngine::EventSchema.new
    event_schema.register(a)

    error = assert_raises(EventEngine::EventSchema::DuplicateEventNameError) do
      event_schema.register(b)
    end

    assert_match(/sales.*deal_won/m, error.message)
  end
end
