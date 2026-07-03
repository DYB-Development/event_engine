module EventEngine
  class EventDefinition
    # Provides schema generation and fingerprinting for event definitions.
    module Schemas
      def self.included(base)
        base.extend ClassMethods
      end

      # Immutable representation of a compiled event schema.
      # Holds the event identity, inputs, and payload field definitions.
      # Used both at development time (compilation) and runtime (registry).
      class Schema < Struct.new(
        :event_name,
        :event_version,
        :event_type,
        :process_type,
        :subject,
        :domain,
        :required_inputs,
        :optional_inputs,
        :payload_fields,
        keyword_init: true
      )

        # Reconstructs a Schema from the plain hash produced by {#to_h}.
        # The derived +fingerprint+ key is ignored; it is not a struct member.
        #
        # @param hash [Hash]
        # @return [Schema]
        def self.from_h(hash)
          new(**hash.reject { |key, _| key.to_sym == :fingerprint })
        end

        # Returns a SHA256 fingerprint of the schema's canonical representation.
        # Used to detect schema changes and trigger version bumps.
        #
        # @return [String] hex-encoded SHA256 digest
        def fingerprint
          Digest::SHA256.hexdigest(
            canonical_representation
          )
        end

        # Serializes the schema to a plain-data hash for the neutral JSON artifact.
        #
        # @return [Hash]
        def to_h
          {
            event_name: event_name,
            event_version: event_version,
            event_type: event_type,
            process_type: process_type,
            subject: subject,
            domain: domain,
            required_inputs: required_inputs,
            optional_inputs: optional_inputs,
            payload_fields: payload_fields.map { |field| payload_field_h(field) },
            fingerprint: fingerprint
          }
        end

        # Serializes the schema to a Ruby source string for the schema file.
        #
        # @return [String]
        def to_ruby
          <<~RUBY.strip
            EventEngine::EventDefinition::Schema.new(
              event_name: #{event_name.inspect},
              event_version: #{event_version.inspect},
              event_type: #{event_type.inspect},
              process_type: #{process_type.inspect},
              subject: #{subject.inspect},
              domain: #{domain.inspect},
              required_inputs: #{required_inputs.inspect},
              optional_inputs: #{optional_inputs.inspect},
              payload_fields: [#{payload_fields.map { |h| ruby_hash(h) }.join(", ")}]
            )
          RUBY
        end

        private

        def canonical_representation
          {
            event_name: event_name.to_s,
            event_type: event_type.to_s,
            required_inputs: required_inputs.map(&:to_s).sort,
            optional_inputs: optional_inputs.map(&:to_s).sort,
            payload_fields: payload_fields
              .map { |h| h.transform_values { |v| v.to_s } }
              .sort_by { |h| h[:name].to_s }
          }.to_json
        end

        def payload_field_h(field)
          {
            name: field[:name],
            from: field[:from],
            attr: field[:attr],
            required: field[:required]
          }
        end

        def ruby_hash(hash)
          inner = hash.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
          "{#{inner}}"
        end
      end

      module ClassMethods
        # Builds and returns a {Schema} from this definition's DSL declarations.
        #
        # @return [Schema]
        # @raise [ArgumentError] if the definition has validation errors
        def schema
          errors = schema_errors
          raise ArgumentError, errors.join(", ") if errors.any?

          required = inputs.select { |_, v| v== :required }.keys
          optional = inputs.select { |_, v| v== :optional }.keys

          Schema.new(
            event_name: @event_name,
            event_type: @event_type,
            process_type: @process_type,
            subject: @subject,
            domain: @domain,
            required_inputs: required,
            optional_inputs: optional,
            payload_fields: payload_fields
          )
        end

        # Returns validation errors for this definition, if any.
        #
        # @return [Array<String>]
        def schema_errors
          errors = []
          validate_identity(errors)
          validate_process_type(errors)
          validate_payload_fields(errors)
          errors
        end

        # Whether this definition has a valid schema (no errors).
        #
        # @return [Boolean]
        def valid_schema?
          schema_errors.empty?
        end

        private

        def validate_identity(errors)
          errors << "event_name is required" unless @event_name
          errors << "event_type is required" unless @event_type
        end

        def validate_process_type(errors)
          return if @process_type.nil? || ProcessType.known?(@process_type)
          errors << "process_type is unknown: #{@process_type.inspect}"
        end

        def validate_payload_fields(errors)
          seen = {}

          payload_fields.each do |field|
            name = field[:name]

            if seen[name]
              errors << "duplicate payload field: #{name}"
            end

            if RESERVED_PAYLOAD_FIELDS.include?(name)
              errors << "payload field uses reserved name: #{name}"
            end

            if field[:from].nil?
              errors << "payload field #{name} must have a from:"
            end

            unless inputs.key?(field[:from])
              errors << "payload field #{name} references unknown input: #{field[:from]}"
            end

            # attr: is optional - when omitted, input value is used directly (passthrough)

            seen[name] = true
          end
        end
      end
    end
  end
end
