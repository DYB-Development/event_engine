require "event_engine/event_definition/inputs"
require "event_engine/event_definition/payloads"
require "event_engine/event_definition/validation"
require "event_engine/event_definition/schemas"

module EventEngine
  class EventDefinition
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
      def event_name(value)
        @event_name = value
      end

      def event_type(value)
        @event_type = value
      end

      def process_type(value)
        @process_type = value
      end

      def subject(value)
        @subject = value
      end

      def domain(value)
        @domain = value
      end
    end
  end
end
