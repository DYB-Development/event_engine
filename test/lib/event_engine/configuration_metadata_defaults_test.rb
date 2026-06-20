require "test_helper"

class ConfigurationMetadataDefaultsTest < ActiveSupport::TestCase
  test "metadata_defaults is settable" do
    config = EventEngine::Configuration.new
    envelope = -> { { app_version: "1.0" } }

    config.metadata_defaults = envelope

    assert_equal envelope, config.metadata_defaults
  end
end
