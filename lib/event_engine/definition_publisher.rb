module EventEngine
  class DefinitionPublisher
    class EventNotInCatalogError < StandardError; end

    def publish(event_name, domain:, inputs:, **envelope)
      EventEngine.emit(event_name, domain: domain, inputs: inputs, **envelope)
    rescue SchemaRegistry::UnknownEventError
      raise EventNotInCatalogError, missing_event_message(event_name, domain)
    end

    private

    def missing_event_message(event_name, domain)
      <<~MSG
        EventEngine has no schema for #{event_name} in domain #{domain.inspect}.

        Its pack's schema.json is missing from the committed catalog. Rebuild it with:
          bin/rails event_engine:schema:catalog
      MSG
    end
  end
end
