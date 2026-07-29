require "test_helper"

module EventEngine
  class UnregisteredProcessorTest < ActiveSupport::TestCase
    teardown do
      EventEngine.processing_rules = nil
      EventEngine.reset_processors!
    end

    test "names the processor a rule asked for but nothing registered" do
      EventEngine.processing_rules = ProcessingRules.new(default: :delivery)
      event = Event.new(event_name: :cow_fed, domain: :herd, payload: {})

      error = assert_raises(UnregisteredProcessorError) { EventEngine.process(event) }

      assert_includes error.message, "delivery"
    end
  end
end
