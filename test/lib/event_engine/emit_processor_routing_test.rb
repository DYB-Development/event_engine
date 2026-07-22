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

    test "emit prefers the event rule over the domain rule and the default" do
      chosen = []
      %i[by_default by_domain by_event].each do |name|
        EventEngine.register_processor(name, ->(_event) { chosen << name })
      end
      EventEngine.configure do |config|
        config.default_processor = :by_default
        config.domain_processors = { herd: :by_domain }
        config.event_processors = { cow_fed: :by_event }
      end

      emit_cow_fed

      assert_equal [:by_event], chosen
    end

    test "emit raises when routing is configured but nothing matches the event" do
      EventEngine.configure { |config| config.domain_processors = { flock: :shepherd } }

      assert_raises(UnroutableEventError) { emit_cow_fed }
    end
  end
end
