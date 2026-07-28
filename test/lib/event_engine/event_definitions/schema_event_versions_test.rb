require "test_helper"

class SchemaEventVersionTest < ActiveSupport::TestCase
  test "schema allows event_version to be nil at construction" do
    schema = EventEngine::CatalogEntry.new(
      event_name: :cow_fed,
      event_version: nil,
      event_type: :domain,
      required_inputs: [],
      optional_inputs: [],
      payload_fields: []
    )

    assert_nil schema.event_version
  end
end
