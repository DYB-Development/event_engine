module EventEngine
  class ProcessorRegistry
    def initialize
      @processors = {}
    end

    def register(name, processor)
      @processors[name] = processor
    end

    def fetch(name)
      @processors[name]
    end

    def clear!
      @processors.clear
    end
  end
end
