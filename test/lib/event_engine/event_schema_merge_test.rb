require "test_helper"

class EventSchemaMergeTest < ActiveSupport::TestCase
  def schema(event_name:, version:, payload:)
    EventEngine::EventDefinition::Schema.new(
      event_name: event_name,
      event_version: version,
      event_type: :domain,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: payload
    )
  end

  def compiled_schema(event_name:, payload:)
    EventEngine::EventDefinition::Schema.new(
      event_name: event_name,
      event_version: nil, # compiled has no version yet
      event_type: :domain,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: payload
    )
  end

  test "does not create new version when compiled matches latest" do
    file = EventEngine::EventSchema.new
    file.register(schema(event_name: :cow_fed, version: 1, payload: [{ name: :w, from: :cow, attr: :weight }]))
    file.finalize!

    compiled = EventEngine::SchemaRegistry.new
    compiled.register(compiled_schema(event_name: :cow_fed, payload: [{ name: :w, from: :cow, attr: :weight }]))

    merged = EventEngine::EventSchemaMerger.merge(compiled, EventEngine::SchemaRegistry.new(file))

    assert_equal [1], merged.versions_for(:cow_fed)
  end

  test "does not create new version when only the domain changes" do
    file = EventEngine::EventSchema.new
    file.register(EventEngine::EventDefinition::Schema.new(
      event_name: :cow_fed, event_version: 1, event_type: :domain, domain: :sales,
      required_inputs: [:cow], optional_inputs: [],
      payload_fields: [{ name: :w, from: :cow, attr: :weight }]
    ))
    file.finalize!

    compiled = EventEngine::SchemaRegistry.new
    compiled.register(EventEngine::EventDefinition::Schema.new(
      event_name: :cow_fed, event_version: nil, event_type: :domain, domain: :marketing,
      required_inputs: [:cow], optional_inputs: [],
      payload_fields: [{ name: :w, from: :cow, attr: :weight }]
    ))

    merged = EventEngine::EventSchemaMerger.merge(compiled, EventEngine::SchemaRegistry.new(file))

    assert_equal [1], merged.versions_for(:cow_fed)
  end

  test "creates new version when compiled differs from latest" do
    file = EventEngine::EventSchema.new
    file.register(schema(event_name: :cow_fed, version: 1, payload: [{ name: :w, from: :cow, attr: :weight }]))
    file.finalize!

    compiled = EventEngine::SchemaRegistry.new
    compiled.register(compiled_schema(event_name: :cow_fed, payload: [{ name: :age, from: :cow, attr: :age }]))

    merged = EventEngine::EventSchemaMerger.merge(compiled, EventEngine::SchemaRegistry.new(file))

    assert_equal [1, 2], merged.versions_for(:cow_fed)
  end

  test "reverting schema creates new version not reuse" do
    file = EventEngine::EventSchema.new
    file.register(schema(event_name: :cow_fed, version: 1, payload: [{ name: :w, from: :cow, attr: :weight }]))
    file.register(schema(event_name: :cow_fed, version: 2, payload: [{ name: :age, from: :cow, attr: :age }]))
    file.finalize!

    compiled = EventEngine::SchemaRegistry.new
    compiled.register(compiled_schema(event_name: :cow_fed, payload: [{ name: :w, from: :cow, attr: :weight }]))

    merged = EventEngine::EventSchemaMerger.merge(compiled, EventEngine::SchemaRegistry.new(file))

    assert_equal [1, 2, 3], merged.versions_for(:cow_fed)
  end

  test "merge is a no-op when compiled and file registries are fully aligned" do
    file = EventEngine::EventSchema.new
    file.register(schema(event_name: :cow_fed, version: 1, payload: [{ name: :w, from: :cow, attr: :weight }]))
    file.finalize!

    compiled = EventEngine::SchemaRegistry.new
    compiled.register(compiled_schema(event_name: :cow_fed, payload: [{ name: :w, from: :cow, attr: :weight }]))

    merged = EventEngine::EventSchemaMerger.merge(compiled, EventEngine::SchemaRegistry.new(file))

    # Same versions
    assert_equal [1], merged.versions_for(:cow_fed)

    # Same schema fingerprint (structural equality)
    assert_equal(
      file.schema_for(:cow_fed, 1).fingerprint,
      merged.schema_for(:cow_fed, 1).fingerprint
    )
  end

  test "merge introduces change when any compiled event differs from file registry" do
    file = EventEngine::EventSchema.new
    file.register(schema(event_name: :cow_fed, version: 1, payload: [{ name: :w, from: :cow, attr: :weight }]))
    file.register(schema(event_name: :pig_fed, version: 1, payload: [{ name: :p, from: :pig, attr: :protein }]))
    file.finalize!

    compiled = EventEngine::SchemaRegistry.new
    compiled.register(compiled_schema(event_name: :cow_fed, payload: [{ name: :w, from: :cow, attr: :weight }]))
    compiled.register(compiled_schema(event_name: :pig_fed, payload: [{ name: :fat, from: :pig, attr: :fat }])) # drift

    merged = EventEngine::EventSchemaMerger.merge(compiled, EventEngine::SchemaRegistry.new(file))

    assert_equal [1], merged.versions_for(:cow_fed)
    assert_equal [1, 2], merged.versions_for(:pig_fed)
  end

  test "merge never reuses prior versions even if compiled matches older schema" do
    file = EventEngine::EventSchema.new
    file.register(schema(event_name: :cow_fed, version: 1, payload: [{ name: :w, from: :cow, attr: :weight }]))
    file.register(schema(event_name: :cow_fed, version: 2, payload: [{ name: :age, from: :cow, attr: :age }]))
    file.register(schema(event_name: :cow_fed, version: 3, payload: [{ name: :color, from: :cow, attr: :color }]))
    file.finalize!

    compiled = EventEngine::SchemaRegistry.new
    compiled.register(compiled_schema(event_name: :cow_fed, payload: [{ name: :w, from: :cow, attr: :weight }]))

    merged = EventEngine::EventSchemaMerger.merge(compiled, EventEngine::SchemaRegistry.new(file))

    assert_equal [1, 2, 3, 4], merged.versions_for(:cow_fed)
  end

  # test "changed? returns false when compiled matches file schemas" do
  #   file = EventEngine::EventSchema.new
  #   file.register(schema(event_name: :cow_fed, version: 1, payload: [{ name: :w, from: :cow, attr: :weight }]))
  #   file.finalize!

  #   compiled = EventEngine::SchemaRegistry.new
  #   compiled.register(compiled_schema(event_name: :cow_fed, payload: [{ name: :w, from: :cow, attr: :weight }]))

  #   file_registry = EventEngine::SchemaRegistry.new(file)

  #   refute EventEngine::EventSchemaMerger.changed?(compiled, file_registry)
  # end

  # test "changed? returns true when compiled schema differs from file" do
  #   file = EventEngine::EventSchema.new
  #   file.register(schema(event_name: :cow_fed, version: 1, payload: [{ name: :w, from: :cow, attr: :weight }]))
  #   file.finalize!

  #   compiled = EventEngine::SchemaRegistry.new
  #   compiled.register(compiled_schema(event_name: :cow_fed, payload: [{ name: :age, from: :cow, attr: :age }]))

  #   file_registry = EventEngine::SchemaRegistry.new(file)

  #   assert EventEngine::EventSchemaMerger.changed?(compiled, file_registry)
  # end

  # test "changed? returns true when any event would change" do
  #   file = EventEngine::EventSchema.new
  #   file.register(schema(event_name: :cow_fed, version: 1, payload: [{ name: :w, from: :cow, attr: :weight }]))
  #   file.register(schema(event_name: :pig_fed, version: 1, payload: [{ name: :p, from: :pig, attr: :protein }]))
  #   file.finalize!

  #   compiled = EventEngine::SchemaRegistry.new
  #   compiled.register(compiled_schema(event_name: :cow_fed, payload: [{ name: :w, from: :cow, attr: :weight }]))
  #   compiled.register(compiled_schema(event_name: :pig_fed, payload: [{ name: :fat, from: :pig, attr: :fat }])) # drift

  #   file_registry = EventEngine::SchemaRegistry.new(file)

  #   assert EventEngine::EventSchemaMerger.changed?(compiled, file_registry)
  # end
end
