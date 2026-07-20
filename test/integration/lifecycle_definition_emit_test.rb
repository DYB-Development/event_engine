require "test_helper"
require "ostruct"

module EventEngine
  class LifecycleDefinitionEmitTest < ActiveSupport::TestCase
    class ExportCsvEvents < EventEngine::LifecycleDefinition
      subject :export_csv
      event_type :product

      input :export
      required_payload :format, from: :export, attr: :format

      lifecycle :started, :completed
    end

    setup do
      @previous_registry = EventEngine.schema_registry
      EventEngine.define_subjects { subject :export_csv }

      compiled = DslCompiler.compile(ExportCsvEvents.generated_events)
      compiled.finalize!

      event_schema = EventSchema.new
      compiled.events.each do |event|
        schema = compiled.latest_for(event).dup
        schema.event_version = 1
        event_schema.register(schema)
      end
      event_schema.finalize!

      registry = SchemaRegistry.new
      registry.load_from_schema!(event_schema)

      EventEngine.schema_registry = registry
    end

    teardown do
      EventEngine.schema_registry = @previous_registry
      EventEngine.reset_subjects!
    end

    test "a generated lifecycle family emits an event carrying its subject" do
      export = OpenStruct.new(format: "csv")

      event = EventEngine.emit(:export_csv_completed, inputs: { export: export })

      assert_equal :export_csv, event.subject
    end
  end
end
