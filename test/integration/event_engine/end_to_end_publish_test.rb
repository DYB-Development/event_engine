require "test_helper"

class EventEngine::EndToEndPublishTest < ActiveSupport::TestCase
  test "event is delivered and marked published" do
    event = EventEngine::OutboxEvent.create!(
      event_type: "OrderCreated",
      event_name: "order.created",
      event_version: 1,
      occurred_at: Time.current,
      payload: { filler: "x" }
    )

    transport = EventEngine::Transports::InMemoryTransport.new
    publisher = EventEngine::OutboxPublisher.new(router: EventEngine::OutboxRouter.new(transport: transport))

    publisher.call

    assert_equal [event], transport.events
    assert_not_nil event.reload.published_at
  end
end
