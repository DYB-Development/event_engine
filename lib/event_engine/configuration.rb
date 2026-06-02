module EventEngine
  # Holds all configuration options for EventEngine.
  #
  # @example
  #   EventEngine.configure do |config|
  #     config.delivery_adapter = :inline
  #     config.transport = EventEngine::Transports::InMemoryTransport.new
  #     config.batch_size = 100
  #     config.max_attempts = 5
  #   end
  class Configuration
    # Raised when configuration fails validation.
    class InvalidConfigurationError < StandardError; end

    # @!attribute [rw] delivery_adapter
    #   How events are published after writing to the outbox.
    #   @return [Symbol] +:inline+ (default), +:active_job+, or +:manual+

    # @!attribute [rw] transport
    #   The transport used to publish events. Must respond to +#publish(event)+.
    #   @return [#publish] defaults to {Transports::NullTransport}

    # @!attribute [rw] batch_size
    #   Max events per publish batch.
    #   @return [Integer] defaults to 100

    # @!attribute [rw] max_attempts
    #   Max publish attempts before dead-lettering.
    #   @return [Integer] defaults to 5

    # @!attribute [rw] retention_period
    #   How long to keep published events before cleanup. +nil+ disables cleanup.
    #   @return [ActiveSupport::Duration, nil] defaults to nil

    # @!attribute [rw] dashboard_auth
    #   Callable for dashboard access control. Receives the controller instance.
    #   @return [Proc, nil] defaults to nil (dashboard returns 403)

    # @!attribute [rw] logger
    #   Logger instance for EventEngine messages.
    #   @return [Logger] defaults to +Rails.logger+

    # @!attribute [rw] cloud_api_key
    #   API key for EventEngine Cloud. When set, the Cloud Reporter activates.
    #   @return [String, nil] defaults to nil (reporter inactive)

    # @!attribute [rw] cloud_endpoint
    #   Cloud API endpoint URL.
    #   @return [String] defaults to "https://api.eventengine.dev/v1/ingest"

    # @!attribute [rw] cloud_environment
    #   Environment label sent to Cloud (e.g. "production", "staging").
    #   @return [String, nil] defaults to nil

    # @!attribute [rw] cloud_app_name
    #   Application name sent to Cloud.
    #   @return [String, nil] defaults to nil

    # @!attribute [rw] cloud_batch_size
    #   Max entries per Cloud Reporter batch before auto-flush.
    #   @return [Integer] defaults to 50

    # @!attribute [rw] cloud_flush_interval
    #   Seconds between scheduled Cloud Reporter flushes.
    #   @return [Integer] defaults to 10

    attr_accessor :delivery_adapter, :transport, :batch_size, :max_attempts, :retention_period, :dashboard_auth, :logger,
                  :cloud_api_key, :cloud_endpoint, :cloud_environment, :cloud_app_name, :cloud_batch_size, :cloud_flush_interval

    VALID_DELIVERY_ADAPTERS = %i[inline active_job manual].freeze

    def initialize
      @delivery_adapter = :inline
      @transport = Transports::NullTransport.new
      @batch_size = 100
      @max_attempts = 5
      @retention_period = nil
      @dashboard_auth = nil
      @logger = defined?(Rails) ? Rails.logger : Logger.new($stdout)
      @cloud_api_key = nil
      @cloud_endpoint = "https://api.eventengine.dev/v1/ingest"
      @cloud_environment = nil
      @cloud_app_name = nil
      @cloud_batch_size = 50
      @cloud_flush_interval = 10
    end

    # Whether the Cloud Reporter should be active.
    #
    # @return [Boolean] true when {#cloud_api_key} is present
    def cloud_enabled?
      cloud_api_key.present?
    end

    # Validates the configuration. Raises on invalid settings.
    #
    # @raise [InvalidConfigurationError] if any setting is invalid
    # @return [void]
    def validate!
      unless VALID_DELIVERY_ADAPTERS.include?(delivery_adapter)
        raise InvalidConfigurationError,
          "Invalid delivery_adapter: #{delivery_adapter.inspect}. Must be one of: #{VALID_DELIVERY_ADAPTERS.join(', ')}"
      end

      if delivery_adapter == :active_job && (transport.nil? || transport.is_a?(Transports::NullTransport))
        raise InvalidConfigurationError,
          "Transport must be configured when using :active_job delivery adapter. " \
          "Set config.transport in your EventEngine initializer."
      end

      if transport && !transport.respond_to?(:publish)
        raise InvalidConfigurationError,
          "Transport must respond to #publish"
      end

      unless batch_size.is_a?(Integer) && batch_size > 0
        raise InvalidConfigurationError,
          "batch_size must be a positive integer, got: #{batch_size.inspect}"
      end

      unless max_attempts.is_a?(Integer) && max_attempts > 0
        raise InvalidConfigurationError,
          "max_attempts must be a positive integer, got: #{max_attempts.inspect}"
      end
    end
  end
end
