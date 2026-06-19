require "test_helper"

class SubjectRegistryMetadataTest < ActiveSupport::TestCase
  test "subject retains arbitrary declared metadata" do
    registry = EventEngine::SubjectRegistry.define do
      subject :export_csv, area: :reports, owner: :data_team
    end

    assert_equal({ area: :reports, owner: :data_team }, registry[:export_csv].metadata)
  end
end
