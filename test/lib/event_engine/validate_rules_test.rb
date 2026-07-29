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

    test "passes when every rule names a registered processor" do
      EventEngine.processing_rules = ProcessingRules.new(default: :subscribers)
      EventEngine.register_processor(:subscribers, ->(_event) {})

      assert EventEngine.validate_rules!
    end

    test "names every unregistered processor at once" do
      EventEngine.processing_rules = ProcessingRules.new(
        default: :ghost, packs: { marketing: :phantom }
      )

      error = assert_raises(InvalidRulesError) { EventEngine.validate_rules! }

      assert_includes error.message, "phantom"
    end
  end
end
