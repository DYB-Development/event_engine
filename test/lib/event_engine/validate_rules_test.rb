require "test_helper"

module EventEngine
  class ValidateRulesTest < ActiveSupport::TestCase
    teardown do
      EventEngine.processing_rules = nil
      EventEngine.reset_processors!
    end

    test "names a rule whose processor is not registered" do
      EventEngine.processing_rules = ProcessingRules.new(events: { cow_fed: :ghost })

      error = assert_raises(InvalidRulesError) { EventEngine.validate_rules! }

      assert_includes error.message, "ghost"
    end
  end
end
