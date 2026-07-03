require "test_helper"
require "tempfile"
require "json"

class BootFromJsonTest < ActiveSupport::TestCase
  setup { @previous_registry = EventEngine.schema_registry }
  teardown { EventEngine.schema_registry = @previous_registry }

  def write_json(*schemas)
    file = Tempfile.new(["event_schema", ".json"])
    file.write(JSON.pretty_generate(schemas.map(&:to_h)))
    file.close
    file
  end

  test "boot loads the registry from the JSON schema artifact" do
    schema = EventEngine::EventDefinition::Schema.new(
      event_name: :cow_fed,
      event_version: 1,
      event_type: :domain,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: [{ name: :weight, required: true, from: :cow, attr: :weight }]
    )
    file = write_json(schema)

    EventEngine.boot_from_schema!(
      schema_path: file.path,
      registry: EventEngine::SchemaRegistry.new
    )

    assert_equal [1], EventEngine.schema_registry.versions_for(:cow_fed)
  ensure
    file.unlink
  end
end
