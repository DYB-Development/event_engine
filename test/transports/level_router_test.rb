require "test_helper"

class LevelRouterTest < ActiveSupport::TestCase
  def test_routes_event_to_transport_mapped_for_its_level
    level_three = RecordingTransport.new
    router = EventEngine::Transports::LevelRouter.new(
      routes: { 3 => level_three },
      default: RecordingTransport.new
    )

    router.publish(FakeEvent.new(event_level: 3))

    assert_equal 1, level_three.published.size
  end

  private

  FakeEvent = Struct.new(:event_level, keyword_init: true)

  class RecordingTransport
    attr_reader :published

    def initialize
      @published = []
    end

    def publish(event)
      @published << event
      true
    end
  end
end
