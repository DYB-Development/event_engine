module EventEngine
  class Configuration
    attr_accessor :logger

    attr_accessor :metadata_defaults

    attr_accessor :schema_path

    attr_accessor :resolver

    def initialize
      @logger = defined?(Rails) ? Rails.logger : Logger.new($stdout)
      @schema_path = "db/event_schema.json"
      @resolver = DefaultResolver.new
    end
  end
end
