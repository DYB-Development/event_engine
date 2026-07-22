module EventEngine
  class ProcessorResolver
    def initialize(configuration)
      @configuration = configuration
    end

    def resolve(event)
      domain_processor(event) || @configuration.default_processor
    end

    private

    def domain_processor(event)
      @configuration.domain_processors[event.domain]
    end
  end
end
