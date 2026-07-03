require "test_helper"

class SchemaFromHTest < ActiveSupport::TestCase
  def build_schema
    EventEngine::EventDefinition::Schema.new(
      event_name: :cow_fed,
      event_version: 1,
      event_type: :domain,
      process_type: :durable,
      subject: :feeding,
      domain: :sales,
      required_inputs: [:cow],
      optional_inputs: [:barn],
      payload_fields: [
        { name: :cow_id, required: true, from: :cow, attr: :id }
      ]
    )
  end

  test "from_h reconstructs a Schema equal to the one to_h came from" do
    schema = build_schema

    assert_equal schema, EventEngine::EventDefinition::Schema.from_h(schema.to_h)
  end
end
