require "test_helper"

class EventEngine::ModuleDispatchTest < ActiveSupport::TestCase
  def teardown
    EventEngine.reset_handlers!
  end

  test "dispatches through a handler registered on the module" do
    received = []
    EventEngine.register_handler(->(event) { received << event }, process_types: :all)

    EventEngine.dispatch(EventEngine::Event.new(event_name: :thing_happened, process_type: :inline, payload: {}))

    assert_equal 1, received.size
  end
end
