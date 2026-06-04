module EventEngine
  class HandlerRegistry
    def initialize
      @handlers = []
    end

    def register(handler, levels:)
      @handlers << { handler: handler, levels: levels }
    end

    def dispatch(event)
      @handlers.each do |registration|
        registration[:handler].call(event) if registration[:levels].include?(event.event_level)
      end
    end
  end
end
