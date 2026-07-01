require "test_helper"

module EventEngine
  class EventHelperWriterTest < ActiveSupport::TestCase
    def event_schema_with(*definitions)
      compiled = DslCompiler.compile(definitions)
      compiled.finalize!

      event_schema = EventSchema.new
      compiled.events.each do |event|
        schema = compiled.latest_for(event).dup
        schema.event_version = 1
        event_schema.register(schema)
      end
      event_schema.finalize!
      event_schema
    end

    class CowFed < EventDefinition
      event_name :cow_fed
      event_type :domain
      input :cow
      required_payload :weight, from: :cow, attr: :weight
    end

    test "generates a real def for an event keyed by its required inputs" do
      source = EventHelperWriter.generate(event_schema_with(CowFed))

      assert_includes source, "def cow_fed(cow:"
    end
  end
end
