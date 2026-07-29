module EventEngine
  class ProcessorResolver
    def initialize(rules)
      @rules = rules
    end

    def routes?
      @rules.any?
    end

    def resolve(event)
      @rules.for(event_name: event.event_name, pack: event.domain) ||
        raise(UnroutableEventError.new(event))
    end
  end
end
