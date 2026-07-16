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

    def write_slice(event_name)
      schema = EventDefinition::Schema.new(
        event_name: event_name,
        event_version: 1,
        event_type: :domain,
        domain: :sales,
        required_inputs: [:animal],
        optional_inputs: [],
        payload_fields: [{ name: :weight, required: true, from: :animal, attr: :weight }]
      )
      file = Tempfile.new(["event_schema", ".json"])
      file.write(JSON.pretty_generate([schema.to_h]))
      file.close
      file
    end

    test "events from two generators' slices both emit in the same host" do
      EventEngine.schema_registry = SchemaRegistry.new
      cattle = write_slice(:cow_fed)
      swine = write_slice(:pig_weighed)
      EventEngine.register_slice!(schema_path: cattle.path)
      EventEngine.register_slice!(schema_path: swine.path)

      received = []
      EventEngine.register_handler(->(event) { received << event.event_name }, process_types: :all)

      EventEngine.emit(:cow_fed, domain: :sales, inputs: { animal: OpenStruct.new(weight: 500) })
      EventEngine.emit(:pig_weighed, domain: :sales, inputs: { animal: OpenStruct.new(weight: 200) })

      assert_equal [:cow_fed, :pig_weighed], received.sort
    ensure
      cattle.unlink
      swine.unlink
    end
  end
end
