module EventEngine
  class Configuration
    attr_accessor :logger

    attr_accessor :metadata_defaults

    attr_accessor :schema_path

    def initialize
      @logger = defined?(Rails) ? Rails.logger : Logger.new($stdout)
      @schema_path = "db/event_schema.json"
    end
  end
end
