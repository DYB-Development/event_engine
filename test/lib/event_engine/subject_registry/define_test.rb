require "test_helper"

class SubjectRegistryDefineTest < ActiveSupport::TestCase
  test "define registers a subject retrievable by name" do
    registry = EventEngine::SubjectRegistry.define do
      subject :export_csv
    end

    assert_equal :export_csv, registry[:export_csv].name
  end
end
