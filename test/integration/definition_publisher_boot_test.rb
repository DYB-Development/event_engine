require "test_helper"
require "tmpdir"
require "ostruct"
require "json"

class DefinitionPublisherBootTest < ActiveSupport::TestCase
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

  def with_definition_port
    EventEngine.const_set(:Definition, Module.new { class << self; attr_accessor :publisher; end })
    yield EventEngine::Definition
  ensure
    EventEngine.send(:remove_const, :Definition)
  end

  def boot_catalog
    Dir.mktmpdir do |dir|
      catalog_path = File.join(dir, "event_schema.json")
      File.write(catalog_path, JSON.pretty_generate([cow_fed_schema.to_h]))

      EventEngine::Engine.send(
        :boot!,
        schema_path: catalog_path,
        helpers_path: File.join(dir, "event_engine_helpers.rb")
      )

      yield
    end
  end

  setup { @previous_registry = EventEngine.schema_registry }

  teardown do
    EventEngine.schema_registry = @previous_registry
    EventEngine.reset_handlers!
  end

  test "boot registers the adapter as the definition port's publisher" do
    with_definition_port do |port|
      boot_catalog do
        assert_instance_of EventEngine::DefinitionPublisher, port.publisher
      end
    end
  end

  test "publishing through the port dispatches the built event to a registered handler" do
    with_definition_port do |port|
      boot_catalog do
        received = []
        EventEngine.register_handler(->(event) { received << event }, process_types: :all)

        port.publisher.publish(:cow_fed, domain: :sales, inputs: { cow: OpenStruct.new(weight: 500) })

        assert_equal 500, received.first.payload[:weight]
      end
    end
  end
end
