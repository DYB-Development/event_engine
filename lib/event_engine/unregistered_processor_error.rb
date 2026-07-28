module EventEngine
  class UnregisteredProcessorError < StandardError
    def initialize(name, event)
      super("the rule for event #{event.event_name.inspect} (pack #{event.domain.inspect}) " \
            "names processor #{name.inspect}, but no processor is registered under that name")
    end
  end
end
