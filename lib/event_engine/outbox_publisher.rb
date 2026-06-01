module EventEngine
  # Reads unpublished events from the outbox and sends them through the
  # configured transport. Handles retries and dead-lettering on failure.
  #
  # Fires +ActiveSupport::Notifications+ for published events, dead letters,
  # and batch completion.
  class OutboxPublisher
    # @param transport [#publish] the transport to publish through
    # @param batch_size [Integer, nil] max events per batch (nil for unlimited)
    # @param max_attempts [Integer, nil] max attempts before dead-lettering
    def initialize(transport:, batch_size: nil, max_attempts: nil, locking_strategy: nil)
      @transport = transport
      @router = OutboxRouter.new(transport: transport)
      @batch_size = batch_size
      @max_attempts = max_attempts
      @locking_strategy = locking_strategy || LockingStrategy.for_current_adapter
    end

    # Fetches and publishes a batch of unpublished events.
    #
    # @return [void]
    def call
      OutboxEvent.transaction do
        events = batch
        events.each do |event|
          publish_event(event)
        end

        ActiveSupport::Notifications.instrument("event_engine.publish_batch", {
          count: events.size
        })
      end
    end

    private

    def batch
      scope = OutboxEvent.unpublished
                         .active
                         .ordered

      scope = scope.retryable(@max_attempts) if @max_attempts
      scope = scope.limit(@batch_size) if @batch_size
      scope = @locking_strategy.apply(scope)

      scope.to_a
    end

    def publish_event(event)
      @router.route(event)
      event.update!(published_at: Time.current)

      ActiveSupport::Notifications.instrument("event_engine.event_published", {
        event_name: event.event_name,
        event_version: event.event_version,
        event_id: event.id
      })
    rescue => e
      handle_failure(event, e)
    end

    def handle_failure(event, error)
      event.increment!(:attempts)
      event.update!(
        last_error_message: error.message.truncate(10_000),
        last_error_class: error.class.name
      )

      return unless @max_attempts
      return unless event.attempts >= @max_attempts

      event.update!(dead_lettered_at: Time.current)

      ActiveSupport::Notifications.instrument("event_engine.event_dead_lettered", {
        event_name: event.event_name,
        event_version: event.event_version,
        event_id: event.id,
        attempts: event.attempts,
        error_message: error.message,
        error_class: error.class.name
      })

      Rails.logger.error(
        "[EventEngine] Dead-lettered event: event_id=#{event.id}, " \
        "event_name=#{event.event_name}, attempts=#{event.attempts}, " \
        "error=#{error.message}"
      )
    end
  end
end
