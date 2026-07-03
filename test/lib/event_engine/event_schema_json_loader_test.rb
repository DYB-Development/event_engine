require "test_helper"
require "tempfile"
require "json"

class EventSchemaJsonLoaderTest < ActiveSupport::TestCase
  def schema_h(event_name:, version:)
    EventEngine::EventDefinition::Schema.new(
      event_name: event_name,
      event_version: version,
      event_type: :domain,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: [{ name: :weight, required: true, from: :cow, attr: :weight }]
    ).to_h
  end

  def write_json(*schemas)
    file = Tempfile.new(["event_schema", ".json"])
    file.write(JSON.pretty_generate(schemas))
    file.close
    file
  end

  test "loads every event and version from the JSON artifact" do
    file = write_json(
      schema_h(event_name: :cow_fed, version: 1),
      schema_h(event_name: :cow_fed, version: 2)
    )

    registry = EventEngine::EventSchemaJsonLoader.load(file.path)

    assert_equal [1, 2], registry.versions_for(:cow_fed)
  ensure
    file.unlink
  end

  test "returns an empty registry when the file does not exist" do
    registry = EventEngine::EventSchemaJsonLoader.load("does_not_exist.json")

    assert_equal [], registry.events
  end
end
