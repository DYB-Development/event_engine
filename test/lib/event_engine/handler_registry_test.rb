require "test_helper"

class EventEngine::HandlerRegistryTest < ActiveSupport::TestCase
  test "dispatches an event to a registered handler" do
    registry = EventEngine::HandlerRegistry.new
    received = []
    registry.register(->(event) { received << event }, process_types: [ :durable, :broker ])

    registry.dispatch(EventEngine::Event.new(event_name: :thing_happened, process_type: :durable, payload: {}))

    assert_equal 1, received.size
  end

  test "skips a handler whose process_types exclude the event's process_type" do
    registry = EventEngine::HandlerRegistry.new
    received = []
    registry.register(->(event) { received << event }, process_types: [ :telemetry ])

    registry.dispatch(EventEngine::Event.new(event_name: :thing_happened, process_type: :durable, payload: {}))

    assert_empty received
  end

  test "an :all handler receives an event of any process_type" do
    registry = EventEngine::HandlerRegistry.new
    received = []
    registry.register(->(event) { received << event }, process_types: :all)

    registry.dispatch(EventEngine::Event.new(event_name: :thing_happened, process_type: :sourced, payload: {}))

    assert_equal 1, received.size
  end

  test "dispatch returns the event" do
    registry = EventEngine::HandlerRegistry.new
    event = EventEngine::Event.new(event_name: :thing_happened, process_type: :inline, payload: {})

    assert_same event, registry.dispatch(event)
  end

  test "clear! removes registrations" do
    registry = EventEngine::HandlerRegistry.new
    received = []
    registry.register(->(event) { received << event }, process_types: :all)
    registry.clear!

    registry.dispatch(EventEngine::Event.new(event_name: :thing_happened, process_type: :inline, payload: {}))

    assert_empty received
  end
end
