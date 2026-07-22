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

  test "resolves the event rule ahead of the domain rule" do
    config = configuration
    config.domain_processors = { herd: :telemetry }
    config.event_processors = { cow_fed: :ledger }

    assert_equal :ledger, EventEngine::ProcessorResolver.new(config).resolve(event)
  end

  test "raises when no rule and no default resolve" do
    assert_raises(EventEngine::UnroutableEventError) do
      EventEngine::ProcessorResolver.new(configuration).resolve(event)
    end
  end

  test "the unroutable error names the event" do
    error = assert_raises(EventEngine::UnroutableEventError) do
      EventEngine::ProcessorResolver.new(configuration).resolve(event(event_name: :barn_built))
    end

    assert_includes error.message, "barn_built"
  end

  test "does not route when nothing is configured" do
    refute_predicate EventEngine::ProcessorResolver.new(configuration), :routes?
  end

  test "routes when a default processor is configured" do
    config = configuration
    config.default_processor = :subscribers

    assert_predicate EventEngine::ProcessorResolver.new(config), :routes?
  end

  test "routes when only a domain rule is configured" do
    config = configuration
    config.domain_processors = { herd: :telemetry }

    assert_predicate EventEngine::ProcessorResolver.new(config), :routes?
  end

  test "routes when only an event rule is configured" do
    config = configuration
    config.event_processors = { cow_fed: :ledger }

    assert_predicate EventEngine::ProcessorResolver.new(config), :routes?
  end
end
