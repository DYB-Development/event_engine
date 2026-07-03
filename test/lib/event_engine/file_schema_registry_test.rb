require "test_helper"
require "json"

class FileSchemaRegistryTest < ActiveSupport::TestCase
  def json_path
    Rails.root.join("db", "event_schema.json")
  end

  setup do
    schema = EventEngine::EventDefinition::Schema.new(
      event_name: :cow_fed,
      event_version: 1,
      event_type: :domain,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: [{ name: :weight, required: true, from: :cow, attr: :weight }]
    )
    File.write(json_path, JSON.pretty_generate([schema.to_h]))
  end

  teardown { File.delete(json_path) if File.exist?(json_path) }

  test "reads the committed schema from the JSON artifact" do
    assert_equal [1], EventEngine.file_schema_registry.versions_for(:cow_fed)
  end
end
