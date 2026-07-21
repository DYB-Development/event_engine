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
  end
end
