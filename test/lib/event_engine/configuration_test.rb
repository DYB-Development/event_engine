require "test_helper"
require "minitest/mock"

module EventEngine
  class ConfigurationTest < ActiveSupport::TestCase
    setup do
      @config = Configuration.new
    end

    test "transport defaults to NullTransport" do
      assert_instance_of EventEngine::Transports::NullTransport, @config.transport
    end

    test "retention_period defaults to nil" do
      assert_nil @config.retention_period
    end

    test "retention_period can be set to a duration" do
      @config.retention_period = 30.days

      assert_equal 30.days, @config.retention_period
    end

    test "dashboard_auth defaults to nil" do
      assert_nil @config.dashboard_auth
    end

    test "dashboard_auth can be set to a callable" do
      auth_check = ->(controller) { controller.current_user&.admin? }
      @config.dashboard_auth = auth_check

      assert_equal auth_check, @config.dashboard_auth
    end

    test "cloud_api_key defaults to nil" do
      assert_nil @config.cloud_api_key
    end

    test "cloud_endpoint defaults to production API" do
      assert_equal "https://api.eventengine.dev/v1/ingest", @config.cloud_endpoint
    end

    test "cloud_batch_size defaults to 50" do
      assert_equal 50, @config.cloud_batch_size
    end

    test "cloud_flush_interval defaults to 10" do
      assert_equal 10, @config.cloud_flush_interval
    end

    test "cloud_environment defaults to nil" do
      assert_nil @config.cloud_environment
    end

    test "cloud_app_name defaults to nil" do
      assert_nil @config.cloud_app_name
    end

    test "cloud_enabled? is false when no api key" do
      assert_equal false, @config.cloud_enabled?
    end

    test "cloud_enabled? is true when api key is set" do
      @config.cloud_api_key = "ee_test_abc123"
      assert_equal true, @config.cloud_enabled?
    end

    test "validate! raises when transport does not respond to publish" do
      @config.transport = Object.new

      error = assert_raises(Configuration::InvalidConfigurationError) do
        @config.validate!
      end

      assert_match(/Transport must respond to #publish/, error.message)
    end

    test "validate! accepts a transport that responds to publish" do
      transport = Object.new
      transport.define_singleton_method(:publish) { |_event| }
      @config.transport = transport

      assert_nothing_raised { @config.validate! }
    end

    test "validate! accepts nil transport" do
      @config.transport = nil

      assert_nothing_raised { @config.validate! }
    end

    test "validate! accepts the manual delivery adapter" do
      @config.delivery_adapter = :manual

      assert_nothing_raised { @config.validate! }
    end

    test "validate! is called during boot_from_schema!" do
      EventEngine.configure do |c|
        c.delivery_adapter = :active_job
        c.transport = nil
      end

      schema_file = Tempfile.new("event_schema.rb")
      schema_file.write("EventEngine::EventSchema.define {}\n")
      schema_file.rewind

      assert_raises(Configuration::InvalidConfigurationError) do
        EventEngine.boot_from_schema!(
          schema_path: schema_file.path,
          registry: EventEngine::SchemaRegistry.new
        )
      end
    ensure
      schema_file&.unlink
      EventEngine.configure do |c|
        c.delivery_adapter = :inline
        c.transport = nil
      end
    end
  end
end
