module EventEngine
  class ProcessingRules
    def initialize(default: nil, packs: {}, events: {})
      @default = default
      @packs = packs
      @events = events
    end

    def for(event_name:, pack:)
      @events[event_name] || @packs[pack] || @default
    end
  end
end
