require "event_engine/event_definition/inputs"
require "event_engine/event_definition/payloads"
require "event_engine/event_definition/validation"
require "event_engine/event_definition/schemas"

module EventEngine
  # Base class for defining events using the EventEngine DSL.
  #
  # Subclass this to declare an event's name, type, inputs, and payload fields.
  # Definitions are compiled into a schema file at development time and are
  # not used at runtime.
  #
  # @example Define an event
  #   class CowFed < EventEngine::EventDefinition
  #     input :cow
  #     optional_input :farmer
  #
  #     event_name :cow_fed
  #     event_type :domain
  #
  #     required_payload :weight, from: :cow, attr: :weight
  #     optional_payload :farmer_name, from: :farmer, attr: :name
  #   end
  class EventDefinition
    # Payload field names reserved by the outbox schema.
    RESERVED_PAYLOAD_FIELDS = %i[
      event_name
      event_type
      event_version
      occurred_at
      created_at
      updated_at
      published_at
      metadata
      idempotency_key
      attempts
      dead_lettered_at
      aggregate_type
      aggregate_id
      aggregate_version
    ].freeze

    include Inputs
    include Payloads
    include Validation
    include Schemas

    class << self
      # Sets the event name for this definition.
      #
      # @param value [Symbol] the event name (e.g. +:cow_fed+)
      def event_name(value)
        @event_name = value
      end

      # Sets the event type for this definition.
      #
      # @param value [Symbol] the event type (e.g. +:domain+, +:integration+)
      def event_type(value)
        @event_type = value
      end

      # Sets the event level for this definition.
      #
      # The level positions the event on the event-system maturity ladder
      # (1 = in-memory/sync ... 5 = event-sourced) and is interpreted by the
      # routing layer to dispatch to the appropriate transport.
      #
      # @param value [Integer] the event level (1..5)
      def event_level(value)
        @event_level = value
      end
    end
  end
end
