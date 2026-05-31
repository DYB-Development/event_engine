module EventEngine
  module Transports
    # Routes each event to a transport based on its declared +event_level+.
    # Falls back to a default transport when the level has no mapping.
    #
    # @example
    #   router = EventEngine::Transports::LevelRouter.new(
    #     routes: {
    #       1 => EventEngine::Transports::InMemoryTransport.new,
    #       4 => EventEngine::Transports::Kafka.new(producer: producer)
    #     },
    #     default: EventEngine::Transports::OutboxTransport.new
    #   )
    #   router.publish(event)
    class LevelRouter
      # @param routes [Hash{Integer => #publish}] level-to-transport mapping
      # @param default [#publish] transport used when a level is unmapped
      def initialize(routes:, default:)
        @routes = routes
        @default = default
      end

      # Dispatches the event to the transport mapped for its +event_level+,
      # or to the default transport when the level is unmapped.
      #
      # @param event [OutboxEvent]
      # @return [Object] the chosen transport's return value
      def publish(event)
        transport_for(event).publish(event)
      end

      private

      def transport_for(event)
        @routes.fetch(event.event_level)
      end
    end
  end
end
