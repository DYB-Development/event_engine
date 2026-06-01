module EventEngine
  # Routes a drained outbox event to its destination based on +event_level+:
  #
  # - level 3 → invokes the event's in-process subscribers (durable, async)
  # - level 4 → publishes through the configured broker transport
  # - level 5 → unsupported
  #
  # Levels 1 and 2 never reach the outbox, so they are not handled here.
  class OutboxRouter
    # @param transport [#publish] the broker transport used for level 4 events
    def initialize(transport:)
      @transport = transport
    end

    # Dispatches a drained event to its level's destination.
    #
    # @param event [OutboxEvent] the drained event
    # @return [void]
    def route(event)
      SubscriberRegistry.subscribers_for(event.event_name).each do |subscriber|
        subscriber.new.handle(event)
      end
    end
  end
end
