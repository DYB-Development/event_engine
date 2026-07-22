require "test_helper"

class EventEngine::ModuleProcessorRegistrationTest < ActiveSupport::TestCase
  def teardown
    EventEngine.reset_processors!
  end

  test "fetches a processor registered on the module" do
    processor = ->(event) { event }
    EventEngine.register_processor(:subscribers, processor)

    assert_same processor, EventEngine.processor_registry.fetch(:subscribers)
  end
end
