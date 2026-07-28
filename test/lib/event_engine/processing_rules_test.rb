require "test_helper"

module EventEngine
  class ProcessingRulesTest < ActiveSupport::TestCase
    test "falls back to the default rule" do
      rules = ProcessingRules.new(default: :inline)

      assert_equal :inline, rules.for(event_name: :cow_fed, pack: :sales)
    end
  end
end
