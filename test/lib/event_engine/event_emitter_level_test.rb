require "test_helper"
require "ostruct"

module EventEngine
  class EventEmitterLevelTest < ActiveSupport::TestCase
    class CowObserved < EventDefinition
      event_name :cow_observed
      event_type :system
      event_level 1

      input :cow
      required_payload :weight, from: :cow, attr: :weight
    end

    setup do
      compiled = DslCompiler.compile([CowObserved])
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
  end
end
