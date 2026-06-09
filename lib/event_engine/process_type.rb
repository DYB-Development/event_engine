module EventEngine
  module ProcessType
    ALL = %i[inline background durable broker telemetry sourced].freeze

    PROCESSORS = {
      inline: :subscribers,
      background: :subscribers,
      durable: :delivery,
      broker: :delivery,
      telemetry: :telemetry,
      sourced: :sourcing
    }.freeze

    def self.all
      ALL
    end

    def self.processor_for(type)
      PROCESSORS[type]
    end

    def self.known?(type)
      ALL.include?(type)
    end
  end
end
