module EventEngine
  class InvalidRulesError < StandardError
    def initialize(names)
      super("the rules file names #{names.map(&:inspect).join(", ")}, " \
            "but no processor is registered under #{names.one? ? "that name" : "those names"}")
    end
  end
end
