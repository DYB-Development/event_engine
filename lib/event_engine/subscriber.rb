module EventEngine
  # Base class for event subscribers. Subclasses declare the event they handle
  # with +subscribes_to+ and implement +#handle(event)+. Declaring the
  # subscription self-registers the subclass in the {SubscriberRegistry} at load
  # time, so no explicit wiring is needed.
  #
  # @example
  #   class SendWelcomeEmail < EventEngine::Subscriber
  #     subscribes_to :user_registered
  #
  #     def handle(event)
  #       # ...
  #     end
  #   end
  class Subscriber
    # Registers this subscriber class for an event.
    #
    # @param event_name [Symbol, String] the event to subscribe to
    # @return [void]
    def self.subscribes_to(event_name)
      SubscriberRegistry.register(event_name, self)
    end

    # Handles a dispatched event. Subclasses must override this.
    #
    # @param event [Object] the dispatched event
    # @raise [NotImplementedError] if the subclass does not implement it
    def handle(event)
      raise NotImplementedError, "#{self.class} must implement #handle"
    end
  end
end
