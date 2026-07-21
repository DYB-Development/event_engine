module EventEngine
  class EventSchema
    class DuplicateEventNameError < StandardError; end

    def initialize
      @schemas_by_event = {}
      @finalized = false
    end

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

    def events(domain: nil)
      @schemas_by_event.keys
        .select { |(schema_domain, _name)| domain.nil? || schema_domain == domain }
        .map { |(_domain, event_name)| event_name }
        .uniq
    end

    def versions_for(event_name, domain: nil)
      version_sets_for(event_name, domain).flat_map(&:keys).uniq.sort
    end

    def schema_for(event_name, version, domain: nil)
      set = version_sets_for(event_name, domain).find { |versions| versions.key?(version) }
      set && set[version]
    end

    def latest_for(event_name, domain: nil)
      merged = version_sets_for(event_name, domain).reduce({}, :merge)
      return nil if merged.empty?
      merged[merged.keys.max]
    end

    def finalize!
      @finalized = true
      @schemas_by_event.each_value(&:freeze)
      @schemas_by_event.freeze
      freeze
    end

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
