require "test_helper"
require "tmpdir"
require "ostruct"

class CoreWithoutRailsAdapterTest < ActiveSupport::TestCase
  class CowFed < EventEngine::EventDefinition
    event_name :cow_fed
    event_type :domain

    input :cow
    required_payload :weight, from: :cow, attr: :weight
  end

  test "compiles, boots from a file, and builds an event using only core POROs" do
    previous_registry = EventEngine.schema_registry
    compiled = EventEngine::DslCompiler.compile([CowFed])

    Dir.mktmpdir do |dir|
      schema_path = File.join(dir, "event_schema.json")
      EventEngine::EventSchemaJsonWriter.write(schema_path, compiled.event_schema)

      EventEngine.boot_from_schema!(
        schema_path: schema_path,
        registry: EventEngine::SchemaRegistry.new
      )

      schema = EventEngine.schema_registry.schema(:cow_fed)
      built = EventEngine::EventBuilder.build(schema: schema, data: { cow: OpenStruct.new(weight: 500) })

      assert_equal 500, built[:payload][:weight]
    end
  ensure
    EventEngine.schema_registry = previous_registry
  end
end
