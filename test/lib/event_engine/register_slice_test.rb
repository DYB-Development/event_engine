require "test_helper"
require "tempfile"
require "json"

class RegisterSliceTest < ActiveSupport::TestCase
  setup { @previous_registry = EventEngine.schema_registry }
  teardown { EventEngine.schema_registry = @previous_registry }

  def write_slice(*schemas)
    file = Tempfile.new(["event_schema", ".json"])
    file.write(JSON.pretty_generate(schemas.map(&:to_h)))
    file.close
    file
  end

  def build_schema
    EventEngine::EventDefinition::Schema.new(
      event_name: :cow_fed,
      event_version: 1,
      event_type: :domain,
      domain: :sales,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: []
    )
  end

  test "registers a slice's schemas into the shared registry" do
    EventEngine.schema_registry = EventEngine::SchemaRegistry.new
    file = write_slice(build_schema)

    EventEngine.register_slice!(schema_path: file.path)

    assert_equal 1, EventEngine.schema_registry.schema(:cow_fed).event_version
  ensure
    file.unlink
  end
end
