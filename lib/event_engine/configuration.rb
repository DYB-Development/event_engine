module EventEngine
  class Configuration
    attr_accessor :logger

    attr_accessor :metadata_defaults

    attr_accessor :schema_path

    attr_accessor :publisher_schema_paths

    attr_accessor :default_processor

    def initialize
      @logger = defined?(Rails) ? Rails.logger : Logger.new($stdout)
      @schema_path = "db/event_schema.json"
      @publisher_schema_paths = []
    end
  end
end
