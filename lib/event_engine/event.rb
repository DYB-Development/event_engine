module EventEngine
  # A non-persisted, in-memory representation of an emitted event.
  # Passed to subscribers' +#handle(event)+ and returned by the emitter for
  # levels that do not write to the outbox (level 1).
  Event = Struct.new(
    :event_name,
    :event_type,
    :event_version,
    :payload,
    :metadata,
    :occurred_at,
    :idempotency_key,
    :aggregate_type,
    :aggregate_id,
    :aggregate_version,
    keyword_init: true
  )
end
