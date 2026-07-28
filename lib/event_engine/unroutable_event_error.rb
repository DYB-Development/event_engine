module EventEngine
  class UnroutableEventError < StandardError
    def initialize(event)
      super("no processing rule for event #{event.event_name.inspect} " \
            "(pack #{event.domain.inspect}); declare it in the rules file " \
            "under events, packs, or default")
    end
  end
end
