require "test_helper"

class EventSchemaImmutabilityTest < ActiveSupport::TestCase
  def build_schema(event_name:, version:)
    EventEngine::CatalogEntry.new(
      event_name: event_name,
      event_version: version,
      event_type: :domain,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: [{ name: :weight, from: :cow, attr: :weight }]
    )
  end

  test "finalize! freezes schema and prevents further registration" do
    es = EventEngine::EventSchema.new
    es.register(build_schema(event_name: :cow_fed, version: 1))

    es.finalize!

    assert es.frozen?

    assert_raises(FrozenError) do
      es.register(build_schema(event_name: :cow_fed, version: 2))
    end
  end

  test "query methods still work after finalize" do
    es = EventEngine::EventSchema.new
    v1 = build_schema(event_name: :cow_fed, version: 1)
    es.register(v1)

    es.finalize!

    assert_equal [:cow_fed], es.events
    assert_equal [1], es.versions_for(:cow_fed)
    assert_equal v1, es.latest_for(:cow_fed)
  end
end
