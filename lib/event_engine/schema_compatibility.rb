module EventEngine
  class SchemaCompatibility
    def initialize(old:, new:)
      @old = old
      @new = new
    end

    def breaking_changes
      removed_required_fields + newly_required_fields
    end

    private

    def removed_required_fields
      (required_names(@old) - field_names(@new)).map do |name|
        "required payload field removed: #{name}"
      end
    end

    def newly_required_fields
      (optional_names(@old) & required_names(@new)).map do |name|
        "payload field became required: #{name}"
      end
    end

    def field_names(schema)
      schema.payload_fields.map { |field| field[:name] }
    end

    def required_names(schema)
      schema.payload_fields.select { |field| field[:required] }.map { |field| field[:name] }
    end

    def optional_names(schema)
      schema.payload_fields.reject { |field| field[:required] }.map { |field| field[:name] }
    end
  end
end
