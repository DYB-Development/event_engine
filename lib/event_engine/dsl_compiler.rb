module EventEngine
  class DslCompiler
    class InvalidEventNameError < StandardError; end
    class ReservedInputNameError < StandardError; end

    SNAKE_CASE = /\A[a-z][a-z0-9_]*\z/

    RESERVED_INPUT_NAMES = %i[
      event_version
      occurred_at
      metadata
      idempotency_key
      aggregate_type
      aggregate_id
      aggregate_version
    ].freeze

    def self.compile(definitions, origin_of: method(:origin_of), report: method(:warn))
      registry = SchemaRegistry.new
      subject_violations = []
      name_violations = []
      reserved_violations = []

      resolve_overrides(Array(definitions), origin_of, report).each do |definition|
        schema = definition.schema
        record_subject_violation(schema, subject_violations)
        record_name_violation(schema, name_violations)
        record_reserved_input_violation(schema, reserved_violations)
        registry.register(schema)
      end

      raise_invalid_event_names(name_violations)
      raise_reserved_input_names(reserved_violations)
      raise_unknown_subjects(subject_violations)

      registry
    end

    def self.resolve_overrides(definitions, origin_of, report)
      definitions.group_by { |definition| identity(definition) }.flat_map do |_identity, group|
        resolve_group(group, origin_of, report)
      end
    end

    def self.resolve_group(group, origin_of, report)
      return group if group.one?

      locals = group.select { |definition| origin_of.call(definition) == :local }
      return group unless locals.one?

      winner = locals.first
      (group - locals).each { |shadowed| report.call(override_notice(winner, shadowed)) }
      locals
    end

    def self.override_notice(winner, shadowed)
      schema = winner.schema

      "EventEngine: local definition #{winner.name || winner} overrides packaged event " \
        "#{schema.event_name.inspect} (domain #{schema.domain.inspect}) " \
        "from #{source_path(shadowed) || shadowed}"
    end

    def self.identity(definition)
      schema = definition.schema
      [schema.domain, schema.event_name]
    end

    def self.origin_of(definition)
      path = source_path(definition)
      local_path?(path) ? :local : :packaged
    end

    def self.source_path(definition)
      return nil unless definition.name

      Object.const_source_location(definition.name)&.first
    end

    def self.local_path?(path)
      return false unless path
      return false unless defined?(Rails) && Rails.respond_to?(:root) && Rails.root

      path.to_s.start_with?(Rails.root.to_s)
    end

    def self.record_name_violation(schema, violations)
      return if schema.event_name.to_s.match?(SNAKE_CASE)

      violations << schema.event_name.inspect
    end

    def self.raise_invalid_event_names(violations)
      return if violations.empty?

      raise InvalidEventNameError, "event names must be snake_case: #{violations.join(", ")}"
    end

    def self.record_reserved_input_violation(schema, violations)
      inputs = schema.required_inputs + schema.optional_inputs
      collisions = inputs & RESERVED_INPUT_NAMES
      return if collisions.empty?

      violations << "#{schema.event_name}: #{collisions.join(", ")}"
    end

    def self.raise_reserved_input_names(violations)
      return if violations.empty?

      raise ReservedInputNameError,
            "input names collide with reserved envelope keys: #{violations.join("; ")}"
    end

    def self.record_subject_violation(schema, violations)
      return if schema.subject.nil?
      return if EventEngine.subject_registry.registered?(schema.subject)

      violations << "#{schema.event_name}: unknown subject #{schema.subject.inspect}"
    end

    def self.raise_unknown_subjects(violations)
      return if violations.empty?

      raise SubjectRegistry::UnknownSubjectError, violations.join(", ")
    end
  end
end
