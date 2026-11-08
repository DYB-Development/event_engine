require "test_helper"

module EventEngine
  class RecordedEventsTest < ActiveSupport::TestCase
    setup { @previous_registry = EventEngine.schema_registry }

    teardown do
      EventEngine.schema_registry = @previous_registry
      EventEngine.processing_rules = nil
      EventEngine.reset_processors!
      EventEngine.reset_handlers!
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

    test "an event whose rule says recorded reaches every handler with no processor registered for it" do
      EventEngine.schema_registry = catalog_with(:lead_created)
      EventEngine.register_processor(:inline, ->(_event) {})
      EventEngine.processing_rules = ProcessingRules.new(default: :inline, events: { lead_created: :recorded })
      handled = []
      EventEngine.register_handler(->(event) { handled << event.event_name }, process_types: :all)

      EventEngine.emit(:lead_created, inputs: {})

      assert_equal [ :lead_created ], handled
    end

    test "a rule that says recorded passes the rules check with no processor registered under that name" do
      EventEngine.schema_registry = catalog_with(:lead_created)
      EventEngine.processing_rules = ProcessingRules.new(events: { lead_created: :recorded })

      assert EventEngine.validate_rules!
    end
  end
end
