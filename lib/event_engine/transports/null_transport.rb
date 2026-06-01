module EventEngine
  module Transports
    # Default transport that discards events with a warning log.
    # Used when no transport is explicitly configured.
    class NullTransport
      # Logs a warning that the event was discarded.
      #
      # @param event [OutboxEvent]
      # @return [true]
      def publish(event)
        logger.warn("[EventEngine::NullTransport] Event '#{event.event_name}' discarded. No transport configured.")
        true
      end

      # @return [Boolean] true, since this transport does not deliver anywhere
      def null?
        true
      end

      private

      def logger
        EventEngine.configuration.logger
      end
    end
  end
end
