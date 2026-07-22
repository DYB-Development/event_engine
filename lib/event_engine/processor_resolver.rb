module EventEngine
  class ProcessorResolver
    def initialize(configuration)
      @configuration = configuration
    end

    def resolve(event)
      @configuration.default_processor
    end
  end
end
