module EventEngine
  class EventEngineHelpersWriter
    HEADER = <<~RUBY.freeze
      # This file is authoritative in production.
      # It is generated from EventDefinitions via:
      #
      #   bin/rails event_engine:schema:dump
      #
      # Do not edit manually.

    RUBY

    ENVELOPE_KEYS = DslCompiler::RESERVED_INPUT_NAMES

    def self.write(path, event_schema)
      File.open(path, "w") do |io|
        io.write(HEADER)
        io.write("module EventEngine\n")

        events_by_domain(event_schema).each do |domain, event_names|
          write_domain_module(io, event_schema, domain, event_names)
        end

        io.write("end\n")
      end
    end

    def self.events_by_domain(event_schema)
      event_schema.schemas_by_event.keys
        .group_by { |(domain, _event_name)| domain }
        .transform_values { |pairs| pairs.map { |(_domain, event_name)| event_name }.sort }
    end

    def self.write_domain_module(io, event_schema, domain, event_names)
      io.write("  module #{module_name(domain)}\n")

      event_names.each do |event_name|
        write_helper(io, domain, event_schema.latest_for(event_name, domain: domain))
      end

      io.write("  end\n")
    end

    def self.module_name(domain)
      domain.to_s.camelize
    end

    def self.write_helper(io, domain, schema)
      inputs = schema.required_inputs + schema.optional_inputs

      io.write("    def self.#{schema.event_name}(#{signature(schema)})\n")
      io.write("      EventEngine.emit(\n")
      io.write("        #{schema.event_name.inspect},\n")
      io.write("        domain: #{domain.inspect},\n")
      io.write("        inputs: #{inputs_hash(inputs)},\n")
      io.write(envelope_delegation)
      io.write("      )\n")
      io.write("    end\n")
    end

    def self.signature(schema)
      required = schema.required_inputs.map { |name| "#{name}:" }
      optional = schema.optional_inputs.map { |name| "#{name}: nil" }
      envelope = ENVELOPE_KEYS.map { |name| "#{name}: nil" }

      (required + optional + envelope).join(", ")
    end

    def self.inputs_hash(inputs)
      return "{}" if inputs.empty?

      "{ #{inputs.map { |name| "#{name}: #{name}" }.join(", ")} }"
    end

    def self.envelope_delegation
      ENVELOPE_KEYS.map { |name| "        #{name}: #{name}" }.join(",\n") + "\n"
    end
  end
end
