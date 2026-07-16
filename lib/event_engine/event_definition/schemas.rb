module EventEngine
  class EventDefinition
    module Schemas
      def self.included(base)
        base.extend ClassMethods
      end

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

        def self.from_h(hash)
          h = hash.transform_keys(&:to_sym)

          new(
            event_name: h[:event_name]&.to_sym,
            event_version: h[:event_version],
            event_type: h[:event_type]&.to_sym,
            process_type: h[:process_type]&.to_sym,
            subject: h[:subject]&.to_sym,
            domain: h[:domain]&.to_sym,
            required_inputs: Array(h[:required_inputs]).map(&:to_sym),
            optional_inputs: Array(h[:optional_inputs]).map(&:to_sym),
            payload_fields: Array(h[:payload_fields]).map { |field| payload_field_from_h(field) }
          )
        end

        def self.payload_field_from_h(field)
          f = field.transform_keys(&:to_sym)

          {
            name: f[:name]&.to_sym,
            required: f[:required],
            from: f[:from]&.to_sym,
            attr: f[:attr]&.to_sym
          }
        end

        def fingerprint
          Digest::SHA256.hexdigest(
            canonical_representation
          )
        end

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

        def schema_errors
          errors = []
          validate_identity(errors)
          validate_process_type(errors)
          validate_payload_fields(errors)
          errors
        end

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

            seen[name] = true
          end
        end
      end
    end
  end
end
