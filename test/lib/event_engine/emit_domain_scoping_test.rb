require "test_helper"
require "ostruct"

module EventEngine
  class EmitDomainScopingTest < ActiveSupport::TestCase
    def build_schema(domain:)
      EventDefinition::Schema.new(
        event_name: :cow_fed,
        event_version: 1,
        event_type: :domain,
        domain: domain,
        required_inputs: [:cow],
        optional_inputs: [],
        payload_fields: []
      )
    end

    setup do
      @previous_registry = EventEngine.schema_registry

      event_schema = EventSchema.new
      event_schema.register(build_schema(domain: :sales))
      event_schema.register(build_schema(domain: :marketing))
      event_schema.finalize!

      EventEngine.schema_registry =
        SchemaRegistry.new.tap { |registry| registry.load_from_schema!(event_schema) }
    end

    teardown do
      EventEngine.schema_registry = @previous_registry
      EventEngine.reset_handlers!
    end

    test "resolves the schema within the requested domain" do
      received = []
      EventEngine.register_handler(->(event) { received << event }, process_types: :all)

      EventEngine.emit(:cow_fed, domain: :marketing, inputs: { cow: OpenStruct.new })

      assert_equal :marketing, received.first.domain
    end
  end
end
