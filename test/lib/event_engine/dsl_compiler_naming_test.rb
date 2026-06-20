require "test_helper"

class DslCompilerNamingTest < ActiveSupport::TestCase
  test "compile rejects a non-snake_case event name" do
    definition = Class.new(EventEngine::EventDefinition) do
      event_name :CowFed
      event_type :domain
    end

    assert_raises(EventEngine::DslCompiler::InvalidEventNameError) do
      EventEngine::DslCompiler.compile([definition])
    end
  end

  test "compile reports every invalid event name in one error" do
    camel = Class.new(EventEngine::EventDefinition) do
      event_name :CowFed
      event_type :domain
    end
    dotted = Class.new(EventEngine::EventDefinition) do
      event_name :"cow.fed"
      event_type :domain
    end

    error = assert_raises(EventEngine::DslCompiler::InvalidEventNameError) do
      EventEngine::DslCompiler.compile([camel, dotted])
    end

    assert_includes error.message, "cow.fed"
  end
end
