require "digest"
require "json"

module EventEngine
  class EventDefinition
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
    end
  end
end
