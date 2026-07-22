module EventEngine
  class ProcessorResolver
    def initialize(configuration)
      @configuration = configuration
    end

    def routes?
      !@configuration.default_processor.nil? ||
        @configuration.domain_processors.any? ||
        @configuration.event_processors.any?
    end

    def resolve(event)
      event_processor(event) || domain_processor(event) || @configuration.default_processor ||
        raise(UnroutableEventError.new(event))
    end

    private

    def event_processor(event)
      @configuration.event_processors[event.event_name]
    end

    def domain_processor(event)
      @configuration.domain_processors[event.domain]
    end
  end
end
