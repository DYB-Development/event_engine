require "test_helper"
require "minitest/mock"

module EventEngine
  class OutboxPublisherTest < ActiveSupport::TestCase
    test "publisher does nothing when there are no unpublished events" do
      transport = Minitest::Mock.new

      publisher = EventEngine::OutboxPublisher.new(router: OutboxRouter.new(transport: transport))
      publisher.call

      transport.verify
      assert_equal 0, EventEngine::OutboxEvent.where(published_at: nil).count
    end

    test "publishes unpublished events and marks them published" do
      event = EventEngine::OutboxEvent.create!(
        event_type: "order.created",
        event_name: "order.created",
        event_version: 1,
        occurred_at: Time.current,
        payload: {filler: "x"}
      )

      transport = Minitest::Mock.new
      transport.expect :publish, true, [event]

      EventEngine::OutboxPublisher.new(router: OutboxRouter.new(transport: transport)).call

      assert_not_nil event.reload.published_at
      transport.verify
    end

    test "does not mark event published when transport raises" do
      event = EventEngine::OutboxEvent.create!(
        event_type: "OrderCreated",
        event_name: "order.created",
        event_version: 1,
        occurred_at: Time.current,
        payload: { filler: "x" }
      )

      transport = Minitest::Mock.new
      transport.expect :publish, nil do |_event|
        raise StandardError, "delivery failed"
      end

      EventEngine::OutboxPublisher.new(router: OutboxRouter.new(transport: transport)).call

      assert_nil event.reload.published_at
      transport.verify
    end

    test "increments attempts when delivery fails" do
      event = EventEngine::OutboxEvent.create!(
        event_type: "OrderCreated",
        event_name: "order.created",
        event_version: 1,
        occurred_at: Time.current,
        payload: { filler: "x" }
      )

      transport = Minitest::Mock.new
      transport.expect :publish, nil do |_event|
        raise StandardError, "boom"
      end

      EventEngine::OutboxPublisher.new(router: OutboxRouter.new(transport: transport)).call

      assert_equal 1, event.reload.attempts
    end

    test "publishes only up to the batch size" do
      e1 = EventEngine::OutboxEvent.create!(event_type: "A", event_name: "a", event_version: 1, occurred_at: Time.current, payload: { x: 1 })
      e2 = EventEngine::OutboxEvent.create!(event_type: "A", event_name: "a", event_version: 1, occurred_at: Time.current, payload: { x: 2 })
      e3 = EventEngine::OutboxEvent.create!(event_type: "A", event_name: "a", event_version: 1, occurred_at: Time.current, payload: { x: 3 })

      transport = EventEngine::Transports::InMemoryTransport.new
      publisher = EventEngine::OutboxPublisher.new(router: OutboxRouter.new(transport: transport), batch_size: 2)

      publisher.call

      assert_equal [e1, e2], transport.events
      assert_nil e3.reload.published_at
    end

    test "skips events that exceeded max attempts" do
      skipped = EventEngine::OutboxEvent.create!(
        event_type: "A",
        event_name: "a",
        event_version: 1,
        occurred_at: Time.current,
        payload: { x: 1 },
        attempts: 5
      )

      published = EventEngine::OutboxEvent.create!(
        event_type: "A",
        event_name: "a",
        event_version: 1,
        occurred_at: Time.current,
        payload: { x: 2 },
        attempts: 0
      )

      transport = EventEngine::Transports::InMemoryTransport.new

      EventEngine::OutboxPublisher.new(
        router: OutboxRouter.new(transport: transport),
        batch_size: 10,
        max_attempts: 5
      ).call

      assert_equal [published], transport.events
      assert_nil skipped.reload.published_at
    end

    test "dead-letters event after exceeding max attempts" do
      event = EventEngine::OutboxEvent.create!(
        event_type: "A",
        event_name: "a",
        event_version: 1,
        occurred_at: Time.current,
        payload: { x: 1 },
        attempts: 4
      )

      transport = Minitest::Mock.new
      transport.expect :publish, nil do |_|
        raise StandardError, "boom"
      end

      EventEngine::OutboxPublisher.new(
        router: OutboxRouter.new(transport: transport),
        max_attempts: 5
      ).call

      event.reload
      assert event.dead_lettered?
      assert_nil event.published_at
    end

    test "processes only a single batch per call" do
      e1 = EventEngine::OutboxEvent.create!(
        event_type: "A",
        event_name: "a",
        event_version: 1,
        occurred_at: Time.current,
        payload: { x: 1 }
      )

      e2 = EventEngine::OutboxEvent.create!(
        event_type: "A",
        event_name: "a",
        event_version: 1,
        occurred_at: Time.current,
        payload: { x: 2 }
      )

      e3 = EventEngine::OutboxEvent.create!(
        event_type: "A",
        event_name: "a",
        event_version: 1,
        occurred_at: Time.current,
        payload: { x: 3 }
      )

      transport = EventEngine::Transports::InMemoryTransport.new

      publisher = EventEngine::OutboxPublisher.new(
        router: OutboxRouter.new(transport: transport),
        batch_size: 2
      )

      publisher.call

      assert_equal [e1, e2], transport.events
      assert_nil e3.reload.published_at
    end

    test "persists error context on failure" do
      event = EventEngine::OutboxEvent.create!(
        event_type: "A",
        event_name: "a",
        event_version: 1,
        occurred_at: Time.current,
        payload: { x: 1 }
      )

      transport = Minitest::Mock.new
      transport.expect :publish, nil do |_|
        raise ArgumentError, "invalid payload format"
      end

      EventEngine::OutboxPublisher.new(router: OutboxRouter.new(transport: transport)).call

      event.reload
      assert_equal "invalid payload format", event.last_error_message
      assert_equal "ArgumentError", event.last_error_class
    end

    test "dead-lettered event retains error context" do
      event = EventEngine::OutboxEvent.create!(
        event_type: "A",
        event_name: "a",
        event_version: 1,
        occurred_at: Time.current,
        payload: { x: 1 },
        attempts: 4
      )

      transport = Minitest::Mock.new
      transport.expect :publish, nil do |_|
        raise RuntimeError, "connection reset"
      end

      EventEngine::OutboxPublisher.new(
        router: OutboxRouter.new(transport: transport),
        max_attempts: 5
      ).call

      event.reload
      assert event.dead_lettered?
      assert_equal "connection reset", event.last_error_message
      assert_equal "RuntimeError", event.last_error_class
    end

    test "failure of one event does not prevent publishing other events in the same batch" do
      failing = EventEngine::OutboxEvent.create!(
        event_type: "A",
        event_name: "a",
        event_version: 1,
        occurred_at: Time.current,
        payload: { x: "fail" }
      )

      succeeding = EventEngine::OutboxEvent.create!(
        event_type: "A",
        event_name: "a",
        event_version: 1,
        occurred_at: Time.current,
        payload: { x: "ok" }
      )

      transport = Minitest::Mock.new

      transport.expect :publish, nil do |event|
        raise StandardError, "boom" if event == failing
        true
      end

      transport.expect :publish, true do |event|
        event == succeeding
      end

      EventEngine::OutboxPublisher.new(
        router: OutboxRouter.new(transport: transport),
        batch_size: 10,
        max_attempts: 3
      ).call

      failing.reload
      succeeding.reload

      assert_equal 1, failing.attempts
      assert_nil failing.published_at

      assert_not_nil succeeding.published_at

      transport.verify
    end

    test "accepts a custom locking strategy" do
      event = EventEngine::OutboxEvent.create!(
        event_type: "A",
        event_name: "a",
        event_version: 1,
        occurred_at: Time.current,
        payload: { x: 1 }
      )

      transport = EventEngine::Transports::InMemoryTransport.new
      strategy = EventEngine::LockingStrategy::NullStrategy.new

      EventEngine::OutboxPublisher.new(
        router: OutboxRouter.new(transport: transport),
        locking_strategy: strategy
      ).call

      assert_not_nil event.reload.published_at
    end

    test "uses NullStrategy by default for SQLite" do
      event = EventEngine::OutboxEvent.create!(
        event_type: "A",
        event_name: "a",
        event_version: 1,
        occurred_at: Time.current,
        payload: { x: 1 }
      )

      transport = EventEngine::Transports::InMemoryTransport.new

      EventEngine::OutboxPublisher.new(router: OutboxRouter.new(transport: transport)).call

      assert_not_nil event.reload.published_at
    end
  end
end
