module EventEngine
  # Container for all event schemas, organized by event name and version.
  # This is the data structure loaded from the compiled +db/event_schema.rb+ file
  # and used by {SchemaRegistry} at runtime.
  class EventSchema
    class DuplicateEventNameError < StandardError; end

    # Creates an EventSchema using a block DSL (used by the schema file).
    #
    # @yieldparam schema [EventSchema]
    # @return [EventSchema]
    def self.define(&block)
      schema = new
      block.call(schema)
      schema
    end

    def initialize
      @schemas_by_event = {}
      @finalized = false
    end

    # Registers a schema for a specific event name and version.
    #
    # @param schema [EventDefinition::Schema]
    # @raise [FrozenError] if the schema has been finalized
    def register(schema)
      raise FrozenError, "EventSchema is finalized" if @finalized
      event_name = schema.event_name
      version = schema.event_version

      @schemas_by_event[event_name] ||= {}
      guard_duplicate_event_name!(@schemas_by_event[event_name][version], schema)
      @schemas_by_event[event_name][version] = schema
    end

    def guard_duplicate_event_name!(existing, incoming)
      return unless existing

      raise DuplicateEventNameError,
            "duplicate event_name #{incoming.event_name.inspect}: " \
            "already registered with domain #{existing.domain.inspect}, " \
            "cannot register again with domain #{incoming.domain.inspect}"
    end

    # Returns all registered event names.
    #
    # @return [Array<Symbol>]
    def events
      @schemas_by_event.keys
    end

    # Returns sorted version numbers for a given event.
    #
    # @param event_name [Symbol]
    # @return [Array<Integer>]
    def versions_for(event_name)
      versions = @schemas_by_event[event_name]
      return [] unless versions
      versions.keys.sort
    end

    # Returns the schema for a specific event name and version.
    #
    # @param event_name [Symbol]
    # @param version [Integer]
    # @return [EventDefinition::Schema, nil]
    def schema_for(event_name, version)
      @schemas_by_event.dig(event_name, version)
    end

    # Returns the latest (highest version) schema for an event.
    #
    # @param event_name [Symbol]
    # @return [EventDefinition::Schema, nil]
    def latest_for(event_name)
      versions = @schemas_by_event[event_name]
      return nil unless versions && !versions.empty?
      versions[versions.keys.max]
    end

    # Freezes the schema, preventing further registrations.
    #
    # @return [void]
    def finalize!
      @finalized = true
      @schemas_by_event.each_value(&:freeze)
      @schemas_by_event.freeze
      freeze
    end

    # Returns the internal hash of schemas keyed by event name and version.
    #
    # @return [Hash{Symbol => Hash{Integer => EventDefinition::Schema}}]
    def schemas_by_event
      @schemas_by_event
    end
  end
end
