require "test_helper"

class EventBuilderVersionTest < ActiveSupport::TestCase
  def build_schema(version:)
    EventEngine::CatalogEntry.new(
      event_name: :cow_fed,
      event_version: version,
      event_type: :domain,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: [{ name: :weight, from: :cow, attr: :weight }]
    )
  end

  test "builder output includes event_version from schema" do
    cow = Struct.new(:weight).new(500)
    schema = build_schema(version: 2)

    attrs = EventEngine::EventBuilder.build(
      schema: schema,
      data: { cow: cow }
    )

    assert_equal 2, attrs[:event_version]
  end
end
