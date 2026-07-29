module EventEngine
  class SchemaCatalog
    def initialize(schema_registry:)
      @schema_registry = schema_registry
    end

    def to_markdown
      (["# Event Catalog"] + event_sections).join("\n\n") + "\n"
    end

    private

    def event_sections
      @schema_registry.events.map do |event|
        section(@schema_registry.latest_for(event))
      end
    end

    def section(schema)
      ([
        "## #{schema.event_name} (v#{schema.event_version})",
        "- Type: #{schema.event_type}",
        subject_line(schema)
      ] + payload_lines(schema)).compact.join("\n")
    end

    def payload_lines(schema)
      return [] if schema.payload_fields.empty?

      ["- Payload:"] + schema.payload_fields.map do |field|
        "  - #{field[:name]} (#{field[:required] ? "required" : "optional"})"
      end
    end

    def subject_line(schema)
      return nil unless schema.subject

      "- Subject: #{schema.subject}"
    end
  end
end
