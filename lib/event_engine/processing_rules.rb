module EventEngine
  class ProcessingRules
    def initialize(default: nil, packs: {})
      @default = default
      @packs = packs
    end

    def for(event_name:, pack:)
      @packs[pack] || @default
    end
  end
end
