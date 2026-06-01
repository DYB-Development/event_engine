require "test_helper"

module EventEngine
  class OutboxRouterTest < ActiveSupport::TestCase
    teardown do
      SubscriberRegistry.clear!
    end

    def fake_event(event_name:, event_level:, payload: {})
      EventEngine::Event.new(event_name: event_name, event_level: event_level, payload: payload)
    end

    test "routes a level 3 event to its subscribers" do
      received = []
      Class.new(Subscriber) do
        subscribes_to :cow_milked
        define_method(:handle) { |event| received << event }
      end

      router = OutboxRouter.new(transport: nil)
      router.route(fake_event(event_name: :cow_milked, event_level: 3))

      assert_equal 1, received.size
    end

    test "routes a level 4 event to the broker transport" do
      transport = EventEngine::Transports::InMemoryTransport.new
      event = fake_event(event_name: :sale_processed, event_level: 4)

      OutboxRouter.new(transport: transport).route(event)

      assert_equal [event], transport.events
    end

    test "routes a legacy nil-level event to the broker transport" do
      transport = EventEngine::Transports::InMemoryTransport.new
      event = fake_event(event_name: :legacy_event, event_level: nil)

      OutboxRouter.new(transport: transport).route(event)

      assert_equal [event], transport.events
    end

    test "raises a clear error for a level 4 event when no transport is configured" do
      event = fake_event(event_name: :sale_processed, event_level: 4)

      assert_raises(EventEngine::OutboxRouter::MissingTransportError) do
        OutboxRouter.new(transport: nil).route(event)
      end
    end

    test "raises for a level 4 event when transport is the null transport" do
      event = fake_event(event_name: :sale_processed, event_level: 4)

      assert_raises(EventEngine::OutboxRouter::MissingTransportError) do
        OutboxRouter.new(transport: Transports::NullTransport.new).route(event)
      end
    end

    test "raises for an unsupported level 5 event" do
      event = fake_event(event_name: :ledger_entry, event_level: 5)

      assert_raises(EventEngine::OutboxRouter::UnsupportedLevelError) do
        OutboxRouter.new(transport: nil).route(event)
      end
    end
  end
end
