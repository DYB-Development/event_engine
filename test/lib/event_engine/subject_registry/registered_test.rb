require "test_helper"

class SubjectRegistryRegisteredTest < ActiveSupport::TestCase
  test "registered? is false for an undeclared subject" do
    registry = EventEngine::SubjectRegistry.define do
      subject :export_csv
    end

    refute registry.registered?(:unknown_subject)
  end
end
