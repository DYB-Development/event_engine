module EventEngine
  class PublishOutboxEventsJob < ApplicationJob
    queue_as :default

    def perform
      config = EventEngine.configuration
      raise "EventEngine transport not configured" unless config&.transport

      OutboxPublisher.new(
        router: OutboxRouter.new(transport: config.transport),
        batch_size: config.batch_size,
        max_attempts: config.max_attempts
      ).call
    end
  end
end
