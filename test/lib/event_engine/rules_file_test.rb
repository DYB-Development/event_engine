require "test_helper"
require "tmpdir"

module EventEngine
  class RulesFileTest < ActiveSupport::TestCase
    def in_tmp
      Dir.mktmpdir { |dir| yield File.join(dir, "event_rules.yml") }
    end

    test "lists every catalog event so each one needs a decision" do
      in_tmp do |path|
        RulesFile.sync(path: path, event_names: %i[lead_created cow_fed])

        assert_equal({ "lead_created" => nil, "cow_fed" => nil }, YAML.safe_load_file(path)["events"])
      end
    end

    test "keeps a rule that has already been decided" do
      in_tmp do |path|
        File.write(path, YAML.dump({ "events" => { "lead_created" => "durable" } }))

        RulesFile.sync(path: path, event_names: %i[lead_created cow_fed])

        assert_equal "durable", YAML.safe_load_file(path).dig("events", "lead_created")
      end
    end

    test "keeps the pack rules" do
      in_tmp do |path|
        File.write(path, YAML.dump({ "packs" => { "marketing" => "background" } }))

        RulesFile.sync(path: path, event_names: %i[lead_created])

        assert_equal({ "marketing" => "background" }, YAML.safe_load_file(path)["packs"])
      end
    end
  end
end
