require "test_helper"
require "ostruct"

module EventEngine
  class EventEmitterLevelTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    class CowObserved < EventDefinition
      event_name :cow_observed
      event_type :system
      event_level 1

      input :cow
      required_payload :weight, from: :cow, attr: :weight
    end

    class CowMooed < EventDefinition
      event_name :cow_mooed
      event_type :system
      event_level 2

      input :cow
      required_payload :weight, from: :cow, attr: :weight
    end

    class CowMilked < EventDefinition
      event_name :cow_milked
      event_type :system
      event_level 3

      input :cow
      required_payload :weight, from: :cow, attr: :weight
    end

    setup do
      compiled = DslCompiler.compile([CowObserved, CowMooed, CowMilked])
      compiled.finalize!

      event_schema = EventSchema.new
      compiled.events.each do |event|
        schema = compiled.latest_for(event).dup
        schema.event_version = 1
        event_schema.register(schema)
      end
      event_schema.finalize!

      @registry = SchemaRegistry.new
      @registry.reset!
      @registry.load_from_schema!(event_schema)
    end

    teardown do
      SubscriberRegistry.clear!
      clear_enqueued_jobs
      clear_performed_jobs
    end

    test "level 1 event does not write an outbox row" do
      cow = OpenStruct.new(weight: 500)

      assert_no_difference -> { OutboxEvent.count } do
        EventEmitter.emit(
          event_name: :cow_observed,
          data: { cow: cow },
          registry: @registry
        )
      end
    end

    test "level 1 event invokes each subscriber synchronously" do
      received = []
      Class.new(Subscriber) do
        subscribes_to :cow_observed
        define_method(:handle) { |event| received << event }
      end

      EventEmitter.emit(
        event_name: :cow_observed,
        data: { cow: OpenStruct.new(weight: 500) },
        registry: @registry
      )

      assert_equal 1, received.size
    end

    test "level 1 event has a symbol-keyed payload" do
      event = EventEmitter.emit(
        event_name: :cow_observed,
        data: { cow: OpenStruct.new(weight: 500) },
        registry: @registry
      )

      assert_equal({ weight: 500 }, event.payload)
    end

    test "level 1 emit returns a non-persisted event object" do
      result = EventEmitter.emit(
        event_name: :cow_observed,
        data: { cow: OpenStruct.new(weight: 500) },
        registry: @registry
      )

      assert_instance_of EventEngine::Event, result
    end

    test "level 2 event does not write an outbox row" do
      assert_no_difference -> { OutboxEvent.count } do
        EventEmitter.emit(
          event_name: :cow_mooed,
          data: { cow: OpenStruct.new(weight: 500) },
          registry: @registry
        )
      end
    end

    test "level 2 event enqueues a dispatch job" do
      assert_enqueued_with(job: DispatchSubscribersJob) do
        EventEmitter.emit(
          event_name: :cow_mooed,
          data: { cow: OpenStruct.new(weight: 500) },
          registry: @registry
        )
      end
    end

    test "level 2 emit returns a non-persisted event object" do
      result = EventEmitter.emit(
        event_name: :cow_mooed,
        data: { cow: OpenStruct.new(weight: 500) },
        registry: @registry
      )

      assert_instance_of EventEngine::Event, result
    end

    test "level 2 subscriber receives a symbol-keyed payload" do
      received = []
      Class.new(Subscriber) do
        subscribes_to :cow_mooed
        define_method(:handle) { |event| received << event.payload }
      end

      perform_enqueued_jobs do
        EventEmitter.emit(
          event_name: :cow_mooed,
          data: { cow: OpenStruct.new(weight: 500) },
          registry: @registry
        )
      end

      assert_equal({ weight: 500 }, received.first)
    end

    test "level 3 event writes an outbox row" do
      assert_difference -> { OutboxEvent.count }, 1 do
        EventEmitter.emit(
          event_name: :cow_milked,
          data: { cow: OpenStruct.new(weight: 500) },
          registry: @registry
        )
      end
    end

    test "level 3 event persists its level on the outbox row" do
      event = EventEmitter.emit(
        event_name: :cow_milked,
        data: { cow: OpenStruct.new(weight: 500) },
        registry: @registry
      )

      assert_equal 3, event.event_level
    end
  end
end
