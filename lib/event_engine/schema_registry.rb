module EventEngine
  class SchemaRegistry
    class UnknownEventError < StandardError; end

    class RegistryFrozenError < StandardError; end

    def initialize(event_schema = EventSchema.new)
      @event_schema = event_schema
      @loaded = false
    end

    def register(schema)
      @event_schema.register(schema)
    end

    def events
      @event_schema.events
    end

    def versions_for(event_name, domain: nil)
      @event_schema.versions_for(event_name, domain: domain)
    end

    def load_from_schema!(schema)
      raise RegistryFrozenError, "EventRegistry already loaded" if loaded?
      @event_schema = schema

      @loaded = true
      self
    end

    def reset!
      @event_schema = {}
      @loaded = false
    end

    def schema(event_name, version: nil, domain: nil)
      raise RegistryFrozenError, "EventRegistry not loaded" unless loaded?

      schema =
        if version
          @event_schema.schema_for(event_name, version, domain: domain)
        else
          @event_schema.latest_for(event_name, domain: domain)
        end

      unless schema
        raise UnknownEventError,
              "Unknown #{version ? "version #{version} for " : ""}event: #{event_name}"
      end

      schema
    end

    def latest_for(event_name, domain: nil)
      @event_schema.latest_for(event_name, domain: domain)
    end

    def event_schema
      @event_schema
    end

    def finalize!
      @event_schema.finalize!
    end

    def loaded?
      @loaded == true
    end
  end
end
