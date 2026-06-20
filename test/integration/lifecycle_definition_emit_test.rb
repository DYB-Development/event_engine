require "test_helper"
require "ostruct"

module EventEngine
  class LifecycleDefinitionEmitTest < ActiveSupport::TestCase
    include EventEngineTestHelpers

    class ExportCsvEvents < EventEngine::LifecycleDefinition
      subject :export_csv
      event_type :product

      input :export
      required_payload :format, from: :export, attr: :format

      lifecycle :started, :completed
    end

    setup do
      @helpers_snapshot = snapshot_event_engine_helpers
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
      registry.reset!
      registry.load_from_schema!(event_schema)

      EventEngine.install_helpers(registry: registry)
    end

    teardown do
      restore_event_engine_helpers(@helpers_snapshot)
      EventEngine.reset_subjects!
    end

    test "a generated lifecycle family installs a helper that emits an event carrying its subject" do
      export = OpenStruct.new(format: "csv")

      event = EventEngine.export_csv_completed(export: export)

      assert_equal :export_csv, event.subject
    end
  end
end
