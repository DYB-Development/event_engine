require "test_helper"

class DslCompilerSubjectTest < ActiveSupport::TestCase
  def teardown
    EventEngine.reset_subjects!
  end

  test "compile rejects a definition whose subject is not registered" do
    definition = Class.new(EventEngine::EventDefinition) do
      event_name :processed
      event_type :domain
      subject :unregistered
    end

    assert_raises(EventEngine::SubjectRegistry::UnknownSubjectError) do
      EventEngine::DslCompiler.compile([definition])
    end
  end
end
