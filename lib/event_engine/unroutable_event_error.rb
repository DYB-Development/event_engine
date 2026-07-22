module EventEngine
  class UnroutableEventError < StandardError
    def initialize(event)
      super("no processor resolved for event #{event.event_name.inspect} " \
            "(domain #{event.domain.inspect}); configure default_processor, " \
            "domain_processors, or event_processors")
    end
  end
end
