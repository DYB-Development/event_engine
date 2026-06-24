require "test_helper"
require "digest"

class SchemaFingerprintTest < ActiveSupport::TestCase
  test "schemas with same structure have same fingerprint" do
    a = EventEngine::EventDefinition::Schema.new(
      event_name: :cow_fed,
      event_type: :domain,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: [{ name: :weight, from: :cow, attr: :weight }]
    )

    b = EventEngine::EventDefinition::Schema.new(
      event_name: :cow_fed,
      event_type: :domain,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: [{ name: :weight, from: :cow, attr: :weight }]
    )

    assert_equal a.fingerprint, b.fingerprint
  end

  test "process_type does not affect the fingerprint" do
    a = EventEngine::EventDefinition::Schema.new(
      event_name: :cow_fed,
      event_type: :domain,
      process_type: :durable,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: [{ name: :weight, from: :cow, attr: :weight }]
    )

    b = EventEngine::EventDefinition::Schema.new(
      event_name: :cow_fed,
      event_type: :domain,
      process_type: :broker,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: [{ name: :weight, from: :cow, attr: :weight }]
    )

    assert_equal a.fingerprint, b.fingerprint
  end

  test "domain does not affect the fingerprint" do
    a = EventEngine::EventDefinition::Schema.new(
      event_name: :cow_fed,
      event_type: :domain,
      domain: :sales,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: [{ name: :weight, from: :cow, attr: :weight }]
    )

    b = EventEngine::EventDefinition::Schema.new(
      event_name: :cow_fed,
      event_type: :domain,
      domain: :marketing,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: [{ name: :weight, from: :cow, attr: :weight }]
    )

    assert_equal a.fingerprint, b.fingerprint
  end

  test "schemas with different payload have different fingerprints" do
    a = EventEngine::EventDefinition::Schema.new(
      event_name: :cow_fed,
      event_type: :domain,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: [{ name: :weight, from: :cow, attr: :weight }]
    )

    b = EventEngine::EventDefinition::Schema.new(
      event_name: :cow_fed,
      event_type: :domain,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: [{ name: :age, from: :cow, attr: :age }]
    )

    refute_equal a.fingerprint, b.fingerprint
  end
end
