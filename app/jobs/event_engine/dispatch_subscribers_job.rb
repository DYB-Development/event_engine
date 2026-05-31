module EventEngine
  # Invokes an event's subscribers in a background worker. Used for level 2
  # events, which run subscribers asynchronously without touching the outbox.
  class DispatchSubscribersJob < ApplicationJob
    queue_as :default

    # @param event_name [String, Symbol] the emitted event's name
    # @param attrs [Hash] the event attributes used to rebuild the Event
    def perform(event_name, attrs)
      event = Event.new(**attrs.symbolize_keys)
      SubscriberRegistry.subscribers_for(event_name).each { |subscriber| subscriber.new.handle(event) }
    end
  end
end
