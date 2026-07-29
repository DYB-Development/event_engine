module EventEngine
  class UnroutedEventsError < StandardError
    def initialize(event_names)
      super("no processing rule routes #{event_names.map(&:inspect).join(", ")}; " \
            "declare #{event_names.one? ? "it" : "them"} in the rules file " \
            "under events, packs, or default")
    end
  end
end
