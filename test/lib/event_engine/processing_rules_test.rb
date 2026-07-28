require "test_helper"
require "tempfile"

module EventEngine
  class ProcessingRulesTest < ActiveSupport::TestCase
    def rules_file(contents)
      file = Tempfile.new([ "event_rules", ".yml" ])
      file.write(contents)
      file.close
      file.path
    end

    test "falls back to the default rule" do
      rules = ProcessingRules.new(default: :inline)

      assert_equal :inline, rules.for(event_name: :cow_fed, pack: :sales)
    end

    test "prefers the pack rule over the default" do
      rules = ProcessingRules.new(default: :inline, packs: { sales: :background })

      assert_equal :background, rules.for(event_name: :cow_fed, pack: :sales)
    end

    test "prefers the event rule over the pack rule" do
      rules = ProcessingRules.new(default: :inline, packs: { sales: :background },
                                  events: { cow_fed: :durable })

      assert_equal :durable, rules.for(event_name: :cow_fed, pack: :sales)
    end

    test "loads the rules from a yaml file" do
      path = rules_file(<<~YAML)
        default: inline
        packs:
          sales: background
        events:
          cow_fed: durable
      YAML

      assert_equal :durable, ProcessingRules.load(path).for(event_name: :cow_fed, pack: :sales)
    end
  end
end
