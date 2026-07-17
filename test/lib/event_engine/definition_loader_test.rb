require "test_helper"

class DefinitionLoaderTest < ActiveSupport::TestCase
  test "eager load registers event definitions" do
    EventEngine::DefinitionLoader.ensure_loaded!

    assert EventEngine::EventDefinition.descendants.any?,
           "Expected at least one EventDefinition to be loaded"
  end

  test "eager loads definitions through an injectable loader instead of Rails.application" do
    called = false
    EventEngine::DefinitionLoader.reset!
    EventEngine::DefinitionLoader.loader = -> { called = true }

    EventEngine::DefinitionLoader.ensure_loaded!

    assert called
  ensure
    EventEngine::DefinitionLoader.reset!
  end

  test "ensure_loaded! materializes lifecycle families into descendants" do
    Class.new(EventEngine::LifecycleDefinition) do
      subject :loader_demo
      event_type :product
      lifecycle :started
    end

    EventEngine::DefinitionLoader.ensure_loaded!

    discoverable = EventEngine::EventDefinition.descendants.any? do |descendant|
      descendant.instance_variable_get(:@event_name) == :loader_demo_started
    end

    assert discoverable
  end
end
