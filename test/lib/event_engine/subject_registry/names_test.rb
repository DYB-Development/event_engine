require "test_helper"

class SubjectRegistryNamesTest < ActiveSupport::TestCase
  test "names lists every declared subject" do
    registry = EventEngine::SubjectRegistry.define do
      subject :export_csv
      subject :feeding
    end

    assert_equal [:export_csv, :feeding], registry.names
  end
end
