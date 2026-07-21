require "test_helper"

module EventEngine
  class DefinitionPublisherRegistrationTest < ActiveSupport::TestCase
    def port_double
      Class.new { attr_accessor :publisher }.new
    end

    test "registering installs the adapter as the port's publisher" do
      port = port_double

      EventEngine.register_definition_publisher!(port)

      assert_instance_of DefinitionPublisher, port.publisher
    end

    test "registering is a no-op when no pack has loaded the definition port" do
      assert_nil EventEngine.register_definition_publisher!
    end
  end
end
