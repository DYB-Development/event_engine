module EventEngine
  # Routes a drained outbox event to its destination based on +event_level+.
  class OutboxRouter
    # Raised when routing an event whose level has no supported destination.
    class UnsupportedLevelError < StandardError; end

    # Raised when a level 4 event is routed but no transport is configured.
    class MissingTransportError < StandardError; end

    # @param transport [#publish] the broker transport used for level 4 events
    def initialize(transport:)
      @transport = transport
    end

    # Dispatches a drained event to its level's destination.
    #
    # @param event [OutboxEvent] the drained event
    # @return [void]
    def route(event)
      case event.event_level
      when 3 then notify_subscribers(event)
      when 4 then deliver_to_broker(event)
      when 5 then raise UnsupportedLevelError, "event_level 5 (event sourcing) is not supported"
      else publish(event)
      end
    end

    private

    def notify_subscribers(record)
      event = Event.from(record)
      SubscriberRegistry.subscribers_for(event.event_name).each do |subscriber|
        subscriber.new.handle(event)
      end
    end

    def deliver_to_broker(event)
      if transport_missing?
        raise MissingTransportError,
              "event_level 4 event '#{event.event_name}' requires a transport, but none is configured"
      end

      publish(event)
    end

    def transport_missing?
      @transport.nil? || (@transport.respond_to?(:null?) && @transport.null?)
    end

    def publish(event)
      @transport.publish(event)
    end
  end
end
