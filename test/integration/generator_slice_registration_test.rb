require "test_helper"
require "ostruct"
require "tempfile"
require "json"

module EventEngine
  class GeneratorSliceRegistrationTest < ActiveSupport::TestCase
    setup { @previous_registry = EventEngine.schema_registry }

    teardown do
      EventEngine.schema_registry = @previous_registry
      EventEngine.reset_handlers!
    end

    def write_slice(schema)
      file = Tempfile.new(["event_schema", ".json"])
      file.write(JSON.pretty_generate([schema.to_h]))
      file.close
      file
    end

    def build_schema
      EventDefinition::Schema.new(
        event_name: :cow_fed,
        event_version: 1,
        event_type: :domain,
        domain: :sales,
        required_inputs: [:cow],
        optional_inputs: [],
        payload_fields: [{ name: :weight, required: true, from: :cow, attr: :weight }]
      )
    end

    test "a generator emits an event registered from its slice alone" do
      EventEngine.schema_registry = SchemaRegistry.new
      slice = write_slice(build_schema)
      EventEngine.register_slice!(schema_path: slice.path)

      received = []
      EventEngine.register_handler(->(event) { received << event }, process_types: :all)

      EventEngine.emit(:cow_fed, domain: :sales, inputs: { cow: OpenStruct.new(weight: 500) })

      assert_equal :cow_fed, received.first.event_name
    ensure
      slice.unlink
    end
  end
end
