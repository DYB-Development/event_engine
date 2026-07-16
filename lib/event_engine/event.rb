module EventEngine
  Event = Struct.new(
    :event_name,
    :event_type,
    :event_version,
    :process_type,
    :subject,
    :domain,
    :payload,
    :metadata,
    :occurred_at,
    :idempotency_key,
    :aggregate_type,
    :aggregate_id,
    :aggregate_version,
    keyword_init: true
  ) do
    def self.from(record)
      attrs = members.to_h { |member| [member, record.public_send(member)] }
      attrs[:payload] = attrs[:payload].to_h.transform_keys(&:to_sym)
      new(**attrs)
    end
  end
end
