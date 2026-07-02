module EventEngine
  class HandlerRegistry
    def initialize
      @handlers = []
    end

    def register(handler, process_types:)
      @handlers << { handler: handler, process_types: process_types }
    end

    def dispatch(event)
      @handlers.each do |registration|
        process_types = registration[:process_types]
        registration[:handler].call(event) if process_types == :all || process_types.include?(event.process_type)
      end
      event
    end

    def clear!
      @handlers.clear
    end
  end
end
