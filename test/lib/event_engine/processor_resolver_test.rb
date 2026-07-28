require "test_helper"

class EventEngine::ProcessorResolverTest < ActiveSupport::TestCase
  def rules(**declared)
    EventEngine::ProcessingRules.new(**declared)
  end

  def event(event_name: :cow_fed, domain: :herd)
    EventEngine::Event.new(event_name: event_name, domain: domain)
  end

  test "resolves the default rule when nothing more specific matches" do
    resolver = EventEngine::ProcessorResolver.new(rules(default: :subscribers))

    assert_equal :subscribers, resolver.resolve(event)
  end

  test "resolves the pack rule ahead of the default" do
    resolver = EventEngine::ProcessorResolver.new(rules(default: :subscribers, packs: { herd: :telemetry }))

    assert_equal :telemetry, resolver.resolve(event)
  end

  test "resolves the event rule ahead of the pack rule" do
    resolver = EventEngine::ProcessorResolver.new(rules(packs: { herd: :telemetry }, events: { cow_fed: :ledger }))

    assert_equal :ledger, resolver.resolve(event)
  end

  test "raises when no rule and no default resolve" do
    assert_raises(EventEngine::UnroutableEventError) do
      EventEngine::ProcessorResolver.new(rules).resolve(event)
    end
  end

  test "the unroutable error names the event" do
    error = assert_raises(EventEngine::UnroutableEventError) do
      EventEngine::ProcessorResolver.new(rules).resolve(event(event_name: :barn_built))
    end

    assert_includes error.message, "barn_built"
  end

  test "does not route when nothing is declared" do
    refute_predicate EventEngine::ProcessorResolver.new(rules), :routes?
  end

  test "routes when a default rule is declared" do
    assert_predicate EventEngine::ProcessorResolver.new(rules(default: :subscribers)), :routes?
  end

  test "routes when only a pack rule is declared" do
    assert_predicate EventEngine::ProcessorResolver.new(rules(packs: { herd: :telemetry })), :routes?
  end

  test "routes when only an event rule is declared" do
    assert_predicate EventEngine::ProcessorResolver.new(rules(events: { cow_fed: :ledger })), :routes?
  end
end
