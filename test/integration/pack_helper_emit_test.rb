require "test_helper"
require "ostruct"
require "tempfile"
require "json"

PACK_HELPER_SOURCE = <<~GEN.freeze
  module EventEngine
    def self.cow_fed(cow:, event_version: nil, occurred_at: nil, metadata: nil, idempotency_key: nil, aggregate_type: nil, aggregate_id: nil, aggregate_version: nil)
      EventEngine::Definition.publisher.publish(
        :cow_fed,
        domain: :cattle,
        inputs: { cow: cow },
        event_version: event_version,
        occurred_at: occurred_at,
        metadata: metadata,
        idempotency_key: idempotency_key,
        aggregate_type: aggregate_type,
        aggregate_id: aggregate_id,
        aggregate_version: aggregate_version
      )
    end
  end
GEN

class PackHelperEmitTest < ActiveSupport::TestCase
  def entry(version)
    ::EventEngine::CatalogEntry.new(
      event_name: :cow_fed,
      event_version: version,
      event_type: :domain,
      domain: :cattle,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: [{ name: :weight, required: true, from: :cow, attr: :weight }]
    )
  end

  setup do
    @previous_registry = ::EventEngine.schema_registry
    ::EventEngine.const_set(:Definition, Module.new { class << self; attr_accessor :publisher; end })
    Object.class_eval(PACK_HELPER_SOURCE)

    @catalog = Tempfile.new(["catalog", ".json"])
    @catalog.write(JSON.pretty_generate([entry(1).to_h, entry(2).to_h]))
    @catalog.close

    ::EventEngine.boot_from_schema!(
      schema_path: @catalog.path,
      registry: ::EventEngine::SchemaRegistry.new
    )
    ::EventEngine.register_definition_publisher!
  end

  teardown do
    ::EventEngine.schema_registry = @previous_registry
    ::EventEngine.send(:remove_const, :Definition)
    ::EventEngine.reset_handlers!
    @catalog.unlink
  end

  test "a pack helper builds the requested version when event_version is given" do
    event = ::EventEngine.cow_fed(cow: OpenStruct.new(weight: 500), event_version: 1)

    assert_equal 1, event.event_version
  end
end
