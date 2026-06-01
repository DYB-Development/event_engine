require "test_helper"
require "ostruct"

module EventEngine
  class InstrumentationTest < ActiveSupport::TestCase
    class CowFed < EventDefinition
      event_name :cow_fed
      event_type :domain

      input :cow
      required_payload :weight, from: :cow, attr: :weight
    end

    setup do
      compiled = DslCompiler.compile([CowFed])
      compiled.finalize!

      event_schema = EventSchema.new
      compiled.events.each do |event_name|
        schema = compiled.latest_for(event_name).dup
        schema.event_version = 1
        event_schema.register(schema)
      end
      event_schema.finalize!

      @registry = EventEngine::SchemaRegistry.new
      @registry.reset!
      @registry.load_from_schema!(event_schema)

      @notifications = []
    end

    teardown do
      ActiveSupport::Notifications.unsubscribe(@subscriber) if @subscriber
    end

    test "emitting an event publishes event_engine.event_emitted notification" do
      @subscriber = ActiveSupport::Notifications.subscribe("event_engine.event_emitted") do |name, start, finish, id, payload|
        @notifications << {
          name: name,
          start: start,
          finish: finish,
          payload: payload
        }
      end

      cow = OpenStruct.new(weight: 500)

      event = EventEmitter.emit(
        event_name: :cow_fed,
        data: { cow: cow },
        registry: @registry
      )

      assert_equal 1, @notifications.size

      notification = @notifications.first
      assert_equal "event_engine.event_emitted", notification[:name]
      assert_equal "cow_fed", notification[:payload][:event_name]
      assert_equal 1, notification[:payload][:event_version]
      assert_equal event.id, notification[:payload][:event_id]
      assert_not_nil notification[:payload][:idempotency_key]
    end

    test "publishing an event publishes event_engine.event_published notification" do
      @subscriber = ActiveSupport::Notifications.subscribe("event_engine.event_published") do |name, start, finish, id, payload|
        @notifications << { name: name, payload: payload }
      end

      event = OutboxEvent.create!(
        event_name: "cow_fed",
        event_type: "domain",
        event_version: 1,
        payload: { weight: 500 },
        occurred_at: Time.current,
        idempotency_key: SecureRandom.uuid
      )

      transport = Transports::InMemoryTransport.new
      publisher = OutboxPublisher.new(router: OutboxRouter.new(transport: transport))
      publisher.call

      assert_equal 1, @notifications.size

      notification = @notifications.first
      assert_equal "event_engine.event_published", notification[:name]
      assert_equal "cow_fed", notification[:payload][:event_name]
      assert_equal 1, notification[:payload][:event_version]
      assert_equal event.id, notification[:payload][:event_id]
    end

    test "dead-lettering an event publishes event_engine.event_dead_lettered notification" do
      @subscriber = ActiveSupport::Notifications.subscribe("event_engine.event_dead_lettered") do |name, start, finish, id, payload|
        @notifications << { name: name, payload: payload }
      end

      event = OutboxEvent.create!(
        event_name: "cow_fed",
        event_type: "domain",
        event_version: 1,
        payload: { weight: 500 },
        occurred_at: Time.current,
        idempotency_key: SecureRandom.uuid,
        attempts: 2
      )

      failing_transport = FailingTransport.new
      publisher = OutboxPublisher.new(router: OutboxRouter.new(transport: failing_transport), max_attempts: 3)
      publisher.call

      assert_equal 1, @notifications.size

      notification = @notifications.first
      assert_equal "event_engine.event_dead_lettered", notification[:name]
      assert_equal "cow_fed", notification[:payload][:event_name]
      assert_equal 1, notification[:payload][:event_version]
      assert_equal event.id, notification[:payload][:event_id]
      assert_equal 3, notification[:payload][:attempts]
      assert_equal "FailingTransport error", notification[:payload][:error_message]
      assert_equal "RuntimeError", notification[:payload][:error_class]
    end

    test "batch publishing publishes event_engine.publish_batch notification" do
      @subscriber = ActiveSupport::Notifications.subscribe("event_engine.publish_batch") do |name, start, finish, id, payload|
        @notifications << { name: name, payload: payload }
      end

      3.times do |i|
        OutboxEvent.create!(
          event_name: "cow_fed",
          event_type: "domain",
          event_version: 1,
          payload: { weight: 500 + i },
          occurred_at: Time.current,
          idempotency_key: SecureRandom.uuid
        )
      end

      transport = Transports::InMemoryTransport.new
      publisher = OutboxPublisher.new(router: OutboxRouter.new(transport: transport))
      publisher.call

      assert_equal 1, @notifications.size

      notification = @notifications.first
      assert_equal "event_engine.publish_batch", notification[:name]
      assert_equal 3, notification[:payload][:count]
    end
  end

  class FailingTransport
    def publish(_event)
      raise "FailingTransport error"
    end
  end
end
