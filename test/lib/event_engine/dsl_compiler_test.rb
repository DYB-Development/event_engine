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

  test "raises when two definitions declare the same event_name" do
    sales_deal = Class.new(EventEngine::EventDefinition) do
      event_name :deal_won
      event_type :domain
      domain :sales
    end

    marketing_deal = Class.new(EventEngine::EventDefinition) do
      event_name :deal_won
      event_type :domain
      domain :marketing
    end

    assert_raises(EventEngine::EventSchema::DuplicateEventNameError) do
      EventEngine::DslCompiler.compile([sales_deal, marketing_deal])
    end
  end
end
