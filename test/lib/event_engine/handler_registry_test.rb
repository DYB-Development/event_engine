require "test_helper"

class EventEngine::HandlerRegistryTest < ActiveSupport::TestCase
  test "dispatches an event to a registered handler" do
    registry = EventEngine::HandlerRegistry.new
    received = []
    registry.register(->(event) { received << event }, levels: 1..4)

    registry.dispatch(EventEngine::Event.new(event_name: :thing_happened, event_level: 3, payload: {}))

    assert_equal 1, received.size
  end

  test "skips a handler whose levels exclude the event level" do
    registry = EventEngine::HandlerRegistry.new
    received = []
    registry.register(->(event) { received << event }, levels: [ 0 ])

    registry.dispatch(EventEngine::Event.new(event_name: :thing_happened, event_level: 3, payload: {}))

    assert_empty received
  end

  test "an :all handler receives an event of any level" do
    registry = EventEngine::HandlerRegistry.new
    received = []
    registry.register(->(event) { received << event }, levels: :all)

    registry.dispatch(EventEngine::Event.new(event_name: :thing_happened, event_level: 0, payload: {}))

    assert_equal 1, received.size
  end

  test "dispatch returns the event" do
    registry = EventEngine::HandlerRegistry.new
    event = EventEngine::Event.new(event_name: :thing_happened, event_level: 1, payload: {})

    assert_same event, registry.dispatch(event)
  end

  test "clear! removes registrations" do
    registry = EventEngine::HandlerRegistry.new
    received = []
    registry.register(->(event) { received << event }, levels: :all)
    registry.clear!

    registry.dispatch(EventEngine::Event.new(event_name: :thing_happened, event_level: 1, payload: {}))

    assert_empty received
  end
end
