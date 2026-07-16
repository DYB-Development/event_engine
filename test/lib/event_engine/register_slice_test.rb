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

  def build_schema(event_name)
    EventEngine::EventDefinition::Schema.new(
      event_name: event_name,
      event_version: 1,
      event_type: :domain,
      domain: :sales,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: []
    )
  end

  test "registers a slice's schema into the shared registry" do
    EventEngine.schema_registry = EventEngine::SchemaRegistry.new
    slice = write_slice(build_schema(:cow_fed))

    EventEngine.register_slice!(schema_path: slice.path)

    assert_equal 1, EventEngine.schema_registry.schema(:cow_fed).event_version
  ensure
    slice.unlink
  end

  test "a second generator's slice does not evict the first" do
    EventEngine.schema_registry = EventEngine::SchemaRegistry.new
    first = write_slice(build_schema(:cow_fed))
    second = write_slice(build_schema(:pig_weighed))

    EventEngine.register_slice!(schema_path: first.path)
    EventEngine.register_slice!(schema_path: second.path)

    assert_equal 1, EventEngine.schema_registry.schema(:cow_fed).event_version
  ensure
    first.unlink
    second.unlink
  end
end
