module EventEngine
  class DslCompiler
    def self.compile(definitions)
      registry = SchemaRegistry.new
      violations = []

      Array(definitions).each do |definition|
        schema = definition.schema
        record_subject_violation(schema, violations)
        registry.register(schema)
      end

      raise_unknown_subjects(violations)

      registry
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
