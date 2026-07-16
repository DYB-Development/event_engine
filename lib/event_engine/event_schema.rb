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
      key = key_for(schema.domain, schema.event_name)
      version = schema.event_version

      @schemas_by_event[key] ||= {}
      guard_duplicate_event_name!(@schemas_by_event[key][version], schema)
      @schemas_by_event[key][version] = schema
    end

    def guard_duplicate_event_name!(existing, incoming)
      return unless existing

      raise DuplicateEventNameError,
            "duplicate (domain, event_name) " \
            "(#{incoming.domain.inspect}, #{incoming.event_name.inspect}): " \
            "already registered at version #{existing.event_version.inspect}"
    end

    # Returns all registered event names.
    #
    # @return [Array<Symbol>]
    def events
      @schemas_by_event.keys.map { |(_domain, event_name)| event_name }.uniq
    end

    # Returns sorted version numbers for a given event.
    #
    # @param event_name [Symbol]
    # @param domain [Symbol, nil] restricts resolution to a single domain
    # @return [Array<Integer>]
    def versions_for(event_name, domain: nil)
      version_sets_for(event_name, domain).flat_map(&:keys).uniq.sort
    end

    # Returns the schema for a specific event name and version.
    #
    # @param event_name [Symbol]
    # @param version [Integer]
    # @param domain [Symbol, nil] restricts resolution to a single domain
    # @return [EventDefinition::Schema, nil]
    def schema_for(event_name, version, domain: nil)
      set = version_sets_for(event_name, domain).find { |versions| versions.key?(version) }
      set && set[version]
    end

    # Returns the latest (highest version) schema for an event.
    #
    # @param event_name [Symbol]
    # @param domain [Symbol, nil] restricts resolution to a single domain
    # @return [EventDefinition::Schema, nil]
    def latest_for(event_name, domain: nil)
      merged = version_sets_for(event_name, domain).reduce({}, :merge)
      return nil if merged.empty?
      merged[merged.keys.max]
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
    # @return [Hash{Array(Symbol, Symbol) => Hash{Integer => EventDefinition::Schema}}]
    def schemas_by_event
      @schemas_by_event
    end

    private

    def key_for(domain, event_name)
      [domain, event_name]
    end

    def version_sets_for(event_name, domain = nil)
      @schemas_by_event.select do |(schema_domain, name), _versions|
        name == event_name && (domain.nil? || schema_domain == domain)
      end.values
    end
  end
end
