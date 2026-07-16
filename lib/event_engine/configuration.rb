module EventEngine
  class Configuration
    attr_accessor :logger

    attr_accessor :metadata_defaults

    def initialize
      @logger = defined?(Rails) ? Rails.logger : Logger.new($stdout)
    end
  end
end
