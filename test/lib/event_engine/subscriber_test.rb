require "test_helper"

module EventEngine
  class SubscriberTest < ActiveSupport::TestCase
    teardown do
      SubscriberRegistry.clear!
    end

    test "subscribes_to registers the subclass for the event" do
      subscriber = Class.new(Subscriber) do
        subscribes_to :cow_fed
      end

      assert_includes SubscriberRegistry.subscribers_for(:cow_fed), subscriber
    end

    test "handle raises NotImplementedError until a subclass implements it" do
      subscriber = Class.new(Subscriber)

      assert_raises(NotImplementedError) do
        subscriber.new.handle(:any_event)
      end
    end
  end
end
