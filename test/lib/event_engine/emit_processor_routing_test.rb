require "test_helper"
require "ostruct"

module EventEngine
  class EmitProcessorRoutingTest < ActiveSupport::TestCase
    def cow_fed_schema
      EventDefinition::Schema.new(
        event_name: :cow_fed,
        event_version: 1,
        event_type: :domain,
        domain: :herd,
        required_inputs: [:cow],
        optional_inputs: [],
        payload_fields: []
      )
    end

    setup do
      @previous_registry = EventEngine.schema_registry

      event_schema = EventSchema.new
      event_schema.register(cow_fed_schema)
      event_schema.finalize!

      EventEngine.schema_registry =
        SchemaRegistry.new.tap { |registry| registry.load_from_schema!(event_schema) }
    end

    teardown do
      EventEngine.schema_registry = @previous_registry
      EventEngine.reset_handlers!
      EventEngine.reset_processors!
      EventEngine.configuration.default_processor = nil
      EventEngine.configuration.domain_processors = {}
      EventEngine.configuration.event_processors = {}
    end

    def emit_cow_fed
      EventEngine.emit(:cow_fed, domain: :herd, inputs: { cow: OpenStruct.new })
    end

    test "emit invokes the resolved processor with the built event" do
      received = []
      EventEngine.register_processor(:subscribers, ->(event) { received << event })
      EventEngine.configure { |config| config.default_processor = :subscribers }

      emit_cow_fed

      assert_equal 1, received.size
    end
  end
end
