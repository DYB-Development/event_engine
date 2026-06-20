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

  test "adding an optional payload field is not a breaking change" do
    old = schema([{ name: :weight, required: true, from: :cow, attr: :weight }])
    new = schema([
      { name: :weight, required: true, from: :cow, attr: :weight },
      { name: :breed, required: false, from: :cow, attr: :breed }
    ])

    compatibility = EventEngine::SchemaCompatibility.new(old: old, new: new)

    assert_empty compatibility.breaking_changes
  end

  def registry_for(schema)
    event_schema = EventEngine::EventSchema.new
    event_schema.register(schema)
    event_schema.finalize!

    registry = EventEngine::SchemaRegistry.new
    registry.reset!
    registry.load_from_schema!(event_schema)
    registry
  end

  test "violations reports breaking changes per event across registries" do
    old = registry_for(schema([{ name: :weight, required: true, from: :cow, attr: :weight }]))
    new = registry_for(schema([]))

    violations = EventEngine::SchemaCompatibility.violations(old_registry: old, new_registry: new)

    assert_includes violations, "cow_fed: required payload field removed: weight"
  end
end
