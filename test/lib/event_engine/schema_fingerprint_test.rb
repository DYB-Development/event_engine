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

  test "event_level does not affect the fingerprint" do
    a = EventEngine::EventDefinition::Schema.new(
      event_name: :cow_fed,
      event_type: :domain,
      event_level: 3,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: [{ name: :weight, from: :cow, attr: :weight }]
    )

    b = EventEngine::EventDefinition::Schema.new(
      event_name: :cow_fed,
      event_type: :domain,
      event_level: 4,
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
