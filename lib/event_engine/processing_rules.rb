module EventEngine
  class ProcessingRules
    def initialize(default: nil)
      @default = default
    end

    def for(event_name:, pack:)
      @default
    end
  end
end
