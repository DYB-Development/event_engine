require "test_helper"

class EventEngine::ProcessorResolverTest < ActiveSupport::TestCase
  def configuration
    EventEngine::Configuration.new
  end

  def event(event_name: :cow_fed, domain: :herd)
    EventEngine::Event.new(event_name: event_name, domain: domain)
  end

  test "resolves the default processor when no rule matches" do
    config = configuration
    config.default_processor = :subscribers

    assert_equal :subscribers, EventEngine::ProcessorResolver.new(config).resolve(event)
  end

  test "resolves the domain rule ahead of the default" do
    config = configuration
    config.default_processor = :subscribers
    config.domain_processors = { herd: :telemetry }

    assert_equal :telemetry, EventEngine::ProcessorResolver.new(config).resolve(event)
  end
end
