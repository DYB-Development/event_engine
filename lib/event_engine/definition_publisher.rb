module EventEngine
  class DefinitionPublisher
    def publish(event_name, domain:, inputs:, **envelope)
      EventEngine.emit(event_name, domain: domain, inputs: inputs, idempotency_key: envelope[:idempotency_key])
    end
  end
end
