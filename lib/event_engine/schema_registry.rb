module EventEngine
  # In-memory registry holding all event schemas by name and version.
  # Loaded once at boot from the compiled schema file.
  #
  # @example Look up a schema
  #   schema = registry.schema(:cow_fed)
  #   schema.event_version #=> 2
  #
  # @example Look up a specific version
  #   schema = registry.schema(:cow_fed, version: 1)
  class SchemaRegistry
    # Raised when looking up an event name or version that doesn't exist.
    class UnknownEventError < StandardError; end

    # Raised when the registry is accessed before loading or loaded twice.
    class RegistryFrozenError < StandardError; end

    # @param event_schema [EventSchema] initial schema (empty by default)
    def initialize(event_schema = EventSchema.new)
      @event_schema = event_schema
      @loaded = false
    end

    # Registers a schema into the underlying EventSchema store.
    #
    # @param schema [EventDefinition::Schema] the schema to register
    def register(schema)
      @event_schema.register(schema)
    end

    # Returns all registered event names.
    #
    # @return [Array<Symbol>]
    def events
      @event_schema.events
    end

    # Returns all version numbers for a given event.
    #
    # @param event_name [Symbol]
    # @return [Array<Integer>] sorted version numbers
    def versions_for(event_name)
      @event_schema.versions_for(event_name)
    end

    # Populates the registry from a loaded EventSchema. Can only be called once.
    #
    # @param schema [EventSchema] the compiled schema
    # @return [self]
    # @raise [RegistryFrozenError] if already loaded
    def load_from_schema!(schema)
      raise RegistryFrozenError, "EventRegistry already loaded" if loaded?
      @event_schema = schema

      @loaded = true
      self
    end

    # Clears the registry, allowing it to be reloaded.
    #
    # @return [void]
    def reset!
      @event_schema = {}
      @loaded = false
    end

    # Looks up a schema by event name and optional version.
    # Returns the latest version when no version is specified.
    #
    # @param event_name [Symbol]
    # @param version [Integer, nil] specific version, or nil for latest
    # @param domain [Symbol, nil] restricts resolution to a single domain
    # @return [EventDefinition::Schema]
    # @raise [RegistryFrozenError] if registry is not loaded
    # @raise [UnknownEventError] if event or version is not found
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

    # Returns the latest schema version for an event.
    #
    # @param event_name [Symbol]
    # @return [EventDefinition::Schema, nil]
    def latest_for(event_name)
      @event_schema.latest_for(event_name)
    end

    # Returns the underlying EventSchema store.
    #
    # @return [EventSchema]
    def event_schema
      @event_schema
    end

    # Freezes the underlying schema, preventing further modifications.
    #
    # @return [void]
    def finalize!
      @event_schema.finalize!
    end

    # Whether the registry has been loaded with schemas.
    #
    # @return [Boolean]
    def loaded?
      @loaded == true
    end
  end
end
