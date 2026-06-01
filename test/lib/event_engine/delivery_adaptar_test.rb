require "test_helper"

class DeliveryAdapterTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  include ActiveJob::TestHelper

  setup do
    @original_delivery_adapter = EventEngine.configuration.delivery_adapter
  end

  teardown do
    EventEngine.configuration.delivery_adapter = @original_delivery_adapter
  end

  test "inline adapter publishes immediately" do
    called = false

    EventEngine.configure do |config|
      config.delivery_adapter = :inline
    end

    EventEngine::Delivery.enqueue do
      called = true
    end

    assert called
  end

  test "inline adapter defers publishing when inside a transaction" do
    called = false

    EventEngine.configure do |config|
      config.delivery_adapter = :inline
    end

    ActiveRecord::Base.transaction do
      EventEngine::Delivery.enqueue do
        called = true
      end

      assert_not called, "Should not publish inside transaction"
    end

    assert called, "Should publish after commit"
  end

  test "inline adapter does not publish on rollback" do
    called = false

    EventEngine.configure do |config|
      config.delivery_adapter = :inline
    end

    ActiveRecord::Base.transaction do
      EventEngine::Delivery.enqueue do
        called = true
      end

      raise ActiveRecord::Rollback
    end

    assert_not called, "Should not publish on rollback"
  end

  test "active_job adapter enqueues PublishOutboxEventsJob" do
    EventEngine.configure do |config|
      config.delivery_adapter = :active_job
    end

    assert_enqueued_with(job: EventEngine::PublishOutboxEventsJob) do
      EventEngine::Delivery.enqueue
    end
  end
end
