require "test_helper"

class EventEngine::DefaultResolverTest < ActiveSupport::TestCase
  test "call returns the event it was handed" do
    event = EventEngine::Event.new(event_name: :thing_happened, payload: {})

    assert_same event, EventEngine::DefaultResolver.new.call(event)
  end
end
