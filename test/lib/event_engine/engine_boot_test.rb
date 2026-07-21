require "test_helper"
require "tmpdir"
require "ostruct"
require "json"

class EngineBootTest < ActiveSupport::TestCase
  include EventEngineTestHelpers

  def cow_fed_schema
    EventEngine::EventDefinition::Schema.new(
      event_name: :cow_fed,
      event_version: 1,
      event_type: :domain,
      domain: :sales,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: [{ name: :weight, required: true, from: :cow, attr: :weight }]
    )
  end

  def helpers_source
    <<~RUBY
      module EventEngine
        module Sales
          def self.cow_fed(cow:)
            EventEngine.emit(:cow_fed, domain: :sales, inputs: { cow: cow })
          end
        end
      end
    RUBY
  end

  test "engine boot loads the schema and generated helpers so an event can be emitted" do
    helpers_snapshot = snapshot_event_engine_helpers
    previous_registry = EventEngine.schema_registry

    Dir.mktmpdir do |dir|
      schema_path = File.join(dir, "event_schema.json")
      helpers_path = File.join(dir, "event_engine_helpers.rb")
      File.write(schema_path, JSON.pretty_generate([cow_fed_schema.to_h]))
      File.write(helpers_path, helpers_source)

      EventEngine::Engine.send(:boot!, schema_path: schema_path, helpers_path: helpers_path)

      event = EventEngine::Sales.cow_fed(cow: OpenStruct.new(weight: 500))
      assert_equal 500, event.payload[:weight]
    end
  ensure
    restore_event_engine_helpers(helpers_snapshot)
    EventEngine.schema_registry = previous_registry
  end
end
