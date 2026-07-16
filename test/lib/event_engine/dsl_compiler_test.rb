require "test_helper"

class DslCompilerTest < ActiveSupport::TestCase
  class CowFed < EventEngine::EventDefinition
    event_name :cow_fed
    event_type :domain

    input :cow
    required_payload :weight, from: :cow, attr: :weight
  end

  test "compiles EventDefinition classes into a SchemaRegistry" do
    registry = EventEngine::DslCompiler.compile([CowFed])

    assert_instance_of EventEngine::SchemaRegistry, registry
    assert_equal [:cow_fed], registry.events

    schema = registry.latest_for(:cow_fed)
    assert_equal :cow_fed, schema.event_name
    assert_equal :domain, schema.event_type
    assert_equal [:cow], schema.required_inputs
  end

  test "freezes compiled schema via finalize!" do
    registry = EventEngine::DslCompiler.compile([CowFed])

    registry.finalize!
    assert registry.event_schema.frozen?
  end

  test "raises when two definitions declare the same event_name in the same domain" do
    one_deal = Class.new(EventEngine::EventDefinition) do
      event_name :deal_won
      event_type :domain
      domain :sales
    end

    another_deal = Class.new(EventEngine::EventDefinition) do
      event_name :deal_won
      event_type :domain
      domain :sales
    end

    assert_raises(EventEngine::EventSchema::DuplicateEventNameError) do
      EventEngine::DslCompiler.compile([one_deal, another_deal])
    end
  end

  test "a local definition overrides a packaged definition sharing the same event_name" do
    packaged = Class.new(EventEngine::EventDefinition) do
      event_name :deal_won
      event_type :domain
      domain :sales
      input :account
    end

    local = Class.new(EventEngine::EventDefinition) do
      event_name :deal_won
      event_type :domain
      domain :sales
      input :buyer
    end

    origin_of = ->(definition) { definition == local ? :local : :packaged }
    registry = EventEngine::DslCompiler.compile([packaged, local], origin_of: origin_of)

    assert_equal [:buyer], registry.latest_for(:deal_won).required_inputs
  end

  test "raises when an input name collides with a reserved envelope key" do
    colliding = Class.new(EventEngine::EventDefinition) do
      event_name :cow_fed
      event_type :domain
      input :metadata
    end

    assert_raises(EventEngine::DslCompiler::ReservedInputNameError) do
      EventEngine::DslCompiler.compile([colliding])
    end
  end
end
