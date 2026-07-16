module EventEngine
  class EventBuilder
    def self.build(schema:, data:)
      validate_inputs!(schema, data)

      payload = {}

      schema.payload_fields.each do |field|
        input = data[field[:from]]
        next if input.nil? && !field[:required]

        value = field[:attr] ? input.public_send(field[:attr]) : input
        payload[field[:name]] = value
      end

      {
        event_name: schema.event_name,
        event_type: schema.event_type,
        event_version: schema.event_version,
        payload: payload
      }
    end

    private

    def self.validate_inputs!(schema, data)
      data_keys = data.keys.map(&:to_sym)

      missing = schema.required_inputs - data_keys
      raise ArgumentError, "missing required input: #{missing.join(', ')}" if missing.any?

      allowed = schema.required_inputs + schema.optional_inputs
      unknown = data_keys - allowed
      raise ArgumentError, "unknown input: #{unknown.join(', ')}" if unknown.any?
    end
  end
end
