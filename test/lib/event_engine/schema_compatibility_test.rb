require "test_helper"

class SchemaCompatibilityTest < ActiveSupport::TestCase
  def schema(payload_fields)
    EventEngine::EventDefinition::Schema.new(
      event_name: :cow_fed,
      event_version: 1,
      event_type: :domain,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: payload_fields
    )
  end

  test "identical schemas have no breaking changes" do
    fields = [{ name: :weight, required: true, from: :cow, attr: :weight }]

    compatibility = EventEngine::SchemaCompatibility.new(old: schema(fields), new: schema(fields))

    assert_empty compatibility.breaking_changes
  end

  test "removing a required payload field is a breaking change" do
    old = schema([{ name: :weight, required: true, from: :cow, attr: :weight }])
    new = schema([])

    compatibility = EventEngine::SchemaCompatibility.new(old: old, new: new)

    assert_includes compatibility.breaking_changes, "required payload field removed: weight"
  end

  test "making an optional payload field required is a breaking change" do
    old = schema([{ name: :weight, required: false, from: :cow, attr: :weight }])
    new = schema([{ name: :weight, required: true, from: :cow, attr: :weight }])

    compatibility = EventEngine::SchemaCompatibility.new(old: old, new: new)

    assert_includes compatibility.breaking_changes, "payload field became required: weight"
  end
end
