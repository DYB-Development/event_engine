require "test_helper"

class EventEngine::ProcessorRegistryTest < ActiveSupport::TestCase
  test "fetches a registered processor by name" do
    registry = EventEngine::ProcessorRegistry.new
    processor = ->(event) { event }
    registry.register(:subscribers, processor)

    assert_same processor, registry.fetch(:subscribers)
  end

  test "registering a taken name replaces the prior processor" do
    registry = EventEngine::ProcessorRegistry.new
    replacement = ->(event) { event }
    registry.register(:delivery, ->(event) { event })
    registry.register(:delivery, replacement)

    assert_same replacement, registry.fetch(:delivery)
  end
end
