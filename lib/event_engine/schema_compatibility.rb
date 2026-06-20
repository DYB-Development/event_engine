module EventEngine
  class SchemaCompatibility
    def self.violations(old_registry:, new_registry:)
      new_registry.events.flat_map do |event|
        previous = old_registry.latest_for(event)
        next [] unless previous

        current = new_registry.latest_for(event)
        new(old: previous, new: current).breaking_changes.map do |change|
          "#{event}: #{change}"
        end
      end
    end

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
