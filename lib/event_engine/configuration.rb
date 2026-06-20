module EventEngine
  # Holds configuration options for EventEngine core.
  #
  # @example
  #   EventEngine.configure do |config|
  #     config.logger = Rails.logger
  #   end
  class Configuration
    # @!attribute [rw] logger
    #   Logger instance for EventEngine messages.
    #   @return [Logger] defaults to +Rails.logger+
    attr_accessor :logger

    attr_accessor :metadata_defaults

    def initialize
      @logger = defined?(Rails) ? Rails.logger : Logger.new($stdout)
    end
  end
end
