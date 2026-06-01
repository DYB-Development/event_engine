require "test_helper"

module EventEngine
  class OutboxPublisherRoutingTest < ActiveSupport::TestCase
    teardown do
      SubscriberRegistry.clear!
    end

    def build_event(**overrides)
      OutboxEvent.create!(
        {
          event_name: "cow.milked",
          event_type: "domain",
          event_version: 1,
          payload: { amount: 5 },
          occurred_at: Time.current
        }.merge(overrides)
      )
    end

    test "drains a level 3 event to its subscribers" do
      received = []
      Class.new(Subscriber) do
        subscribes_to :"cow.milked"
        define_method(:handle) { |event| received << event }
      end
      build_event(event_level: 3)

      OutboxPublisher.new(router: OutboxRouter.new(transport: EventEngine::Transports::InMemoryTransport.new)).call

      assert_equal 1, received.size
    end
  end
end
