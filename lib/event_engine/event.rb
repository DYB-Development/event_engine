module EventEngine
  # A non-persisted, in-memory representation of an emitted event with a
  # symbol-keyed payload. Passed to subscribers' +#handle(event)+ at every
  # in-process level (1-3), and returned by the emitter for levels 1 and 2.
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
    # Builds an Event from a record responding to the same members (e.g. an
    # OutboxEvent), normalizing the payload to symbol keys.
    #
    # @param record [#payload]
    # @return [Event]
    def self.from(record)
      attrs = members.to_h { |member| [member, record.public_send(member)] }
      attrs[:payload] = attrs[:payload].to_h.transform_keys(&:to_sym)
      new(**attrs)
    end
  end
end
