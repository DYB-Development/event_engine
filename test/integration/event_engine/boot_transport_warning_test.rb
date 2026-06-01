require "test_helper"
require "tempfile"

class BootTransportWarningTest < ActiveSupport::TestCase
  class SaleProcessed < EventEngine::EventDefinition
    event_name :sale_processed
    event_type :domain
    event_level 4

    input :sale
    required_payload :total, from: :sale, attr: :total
  end

  test "boot warns when a level 4 event has no real transport" do
    schema_file = Tempfile.new("event_schema.rb")
    EventEngine::EventSchemaDumper.dump!(definitions: [SaleProcessed], path: schema_file.path)

    original = EventEngine.configuration.instance_variable_get(:@logger)
    original_transport = EventEngine.configuration.transport
    original_adapter = EventEngine.configuration.delivery_adapter
    io = StringIO.new
    EventEngine.configuration.instance_variable_set(:@logger, Logger.new(io))
    EventEngine.configuration.transport = EventEngine::Transports::NullTransport.new
    EventEngine.configuration.delivery_adapter = :inline

    EventEngine.boot_from_schema!(
      schema_path: schema_file.path,
      registry: EventEngine::SchemaRegistry.new
    )

    assert_match(/sale_processed/, io.string)
  ensure
    EventEngine.configuration.instance_variable_set(:@logger, original)
    EventEngine.configuration.transport = original_transport
    EventEngine.configuration.delivery_adapter = original_adapter
  end
end
