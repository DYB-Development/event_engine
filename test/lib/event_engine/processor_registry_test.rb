require "test_helper"

class EventEngine::ProcessorRegistryTest < ActiveSupport::TestCase
  test "fetches a registered processor by name" do
    registry = EventEngine::ProcessorRegistry.new
    processor = ->(event) { event }
    registry.register(:subscribers, processor)

    assert_same processor, registry.fetch(:subscribers)
  end
end
