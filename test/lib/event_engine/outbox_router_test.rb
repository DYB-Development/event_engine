require "test_helper"

module EventEngine
  class OutboxRouterTest < ActiveSupport::TestCase
    teardown do
      SubscriberRegistry.clear!
    end

    FakeEvent = Struct.new(:event_name, :event_level, keyword_init: true)

    test "routes a level 3 event to its subscribers" do
      received = []
      Class.new(Subscriber) do
        subscribes_to :cow_milked
        define_method(:handle) { |event| received << event }
      end

      router = OutboxRouter.new(transport: nil)
      router.route(FakeEvent.new(event_name: :cow_milked, event_level: 3))

      assert_equal 1, received.size
    end
  end
end
