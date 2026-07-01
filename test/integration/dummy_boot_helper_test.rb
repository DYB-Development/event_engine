require "test_helper"
require "ostruct"

class DummyBootHelperTest < ActiveSupport::TestCase
  test "the dummy app boots with a generated helper for its committed event" do
    assert_respond_to EventEngine, :widget_created
  end

  test "the generated helper emits the committed event with its payload" do
    event = EventEngine.widget_created(widget: OpenStruct.new(sku: "W-1"))

    assert_equal "W-1", event.payload[:sku]
  end
end
