require "test_helper"
require "tmpdir"
require "ostruct"
require "json"

class CoreWithoutRailsAdapterTest < ActiveSupport::TestCase
  def cow_fed_schema
    EventEngine::EventDefinition::Schema.new(
      event_name: :cow_fed,
      event_version: 1,
      event_type: :domain,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: [{ name: :weight, required: true, from: :cow, attr: :weight }]
    )
  end

  test "boots from a schema.json and builds an event using only core POROs" do
    previous_registry = EventEngine.schema_registry

    Dir.mktmpdir do |dir|
      schema_path = File.join(dir, "event_schema.json")
      File.write(schema_path, JSON.pretty_generate([cow_fed_schema.to_h]))

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
