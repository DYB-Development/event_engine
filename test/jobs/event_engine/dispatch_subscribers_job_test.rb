require "test_helper"

module EventEngine
  class DispatchSubscribersJobTest < ActiveSupport::TestCase
    teardown do
      SubscriberRegistry.clear!
    end

    test "invokes subscribers for the event" do
      received = []
      Class.new(Subscriber) do
        subscribes_to :cow_mooed
        define_method(:handle) { |event| received << event }
      end

      DispatchSubscribersJob.perform_now(:cow_mooed, { event_name: :cow_mooed, payload: { weight: 500 } })

      assert_equal 1, received.size
    end
  end
end
