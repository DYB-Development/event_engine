require "test_helper"

module EventEngine
  class UnroutedEventsTest < ActiveSupport::TestCase
    setup { @previous_registry = EventEngine.schema_registry }

    teardown do
      EventEngine.schema_registry = @previous_registry
      EventEngine.processing_rules = nil
      EventEngine.reset_processors!
    end

    def catalog_with(*event_names)
      event_schema = EventSchema.new
      event_names.each do |event_name|
        event_schema.register(
          CatalogEntry.new(
            event_name: event_name,
            event_version: 1,
            event_type: :domain,
            domain: :marketing,
            required_inputs: [],
            optional_inputs: [],
            payload_fields: []
          )
        )
      end
      event_schema.finalize!

      SchemaRegistry.new.tap { |registry| registry.load_from_schema!(event_schema) }
    end

    test "names a catalogued event that no rule routes" do
      EventEngine.schema_registry = catalog_with(:lead_created, :lead_converted)
      EventEngine.register_processor(:inline, ->(_event) {})
      EventEngine.processing_rules = ProcessingRules.new(events: { lead_created: :inline })

      error = assert_raises(UnroutedEventsError) { EventEngine.validate_rules! }

      assert_includes error.message, "lead_converted"
    end

    test "declaring no rules at all routes nothing and is allowed" do
      EventEngine.schema_registry = catalog_with(:lead_created)
      EventEngine.processing_rules = ProcessingRules.new

      assert EventEngine.validate_rules!
    end

    test "a pack rule covers every event in that pack" do
      EventEngine.schema_registry = catalog_with(:lead_created, :lead_converted)
      EventEngine.register_processor(:inline, ->(_event) {})
      EventEngine.processing_rules = ProcessingRules.new(packs: { marketing: :inline })

      assert EventEngine.validate_rules!
    end
  end
end
