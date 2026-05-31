module EventEngine
  # In-memory registry mapping event names to their subscriber classes.
  # Populated at load time (subscribers self-register) and consulted when an
  # event is dispatched, so the framework can invoke each subscriber's
  # +handle(event)+ in the level's execution context.
  class SubscriberRegistry
    # Registers a subscriber class for an event.
    #
    # @param event_name [Symbol, String] the event to subscribe to
    # @param subscriber [Class] a class responding to +#handle(event)+
    # @return [void]
    def self.register(event_name, subscriber)
      registrations[event_name.to_sym] ||= []
      registrations[event_name.to_sym] << subscriber
    end

    # Returns the subscriber classes registered for an event.
    #
    # @param event_name [Symbol, String]
    # @return [Array<Class>]
    def self.subscribers_for(event_name)
      registrations[event_name.to_sym]
    end

    # Removes all registrations. Intended for test isolation.
    #
    # @return [void]
    def self.clear!
      @registrations = {}
    end

    def self.registrations
      @registrations ||= {}
    end
    private_class_method :registrations
  end
end
