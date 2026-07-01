module EventEngine
  # Generates a committed file of real helper methods (one +def+ per event)
  # from a compiled EventSchema. Each generated method is a thin, typed
  # delegator to {EventEngine.emit}, so helpers are visible to grep,
  # jump-to-definition, and autocomplete instead of being metaprogrammed at boot.
  class EventHelperWriter
    HEADER = <<~RUBY.freeze
      # This file is authoritative in production.
      # It is generated from EventDefinitions via:
      #
      #   bin/rails event_engine:schema:dump
      #
      # Do not edit manually.

    RUBY

    def self.write(path, event_schema)
      File.write(path, generate(event_schema))
    end

    def self.generate(event_schema)
      methods = event_schema.events.sort.map do |event_name|
        method_source(event_schema.latest_for(event_name))
      end

      <<~RUBY
        #{HEADER}module EventEngine
          class << self
        #{methods.join("\n")}
          end
        end
      RUBY
    end

    def self.method_source(schema)
      params = signature_params(schema)
      <<-RUBY.chomp
    def #{schema.event_name}(#{params.join(", ")})
      emit(:#{schema.event_name}, inputs: #{inputs_hash(schema)}, #{envelope_forwarding})
    end
      RUBY
    end

    def self.signature_params(schema)
      required = schema.required_inputs.map { |input| "#{input}:" }
      optional = schema.optional_inputs.map { |input| "#{input}: nil" }
      envelope = ENVELOPE_KEYS.map { |key| "#{key}: nil" }
      required + optional + envelope
    end

    def self.inputs_hash(schema)
      inputs = schema.required_inputs + schema.optional_inputs
      return "{}" if inputs.empty?

      "{ #{inputs.map { |input| "#{input}: #{input}" }.join(", ")} }"
    end

    def self.envelope_forwarding
      ENVELOPE_KEYS.map { |key| "#{key}: #{key}" }.join(", ")
    end
  end
end
