require "test_helper"
require "tmpdir"

class EngineBootTest < ActiveSupport::TestCase
  include EventEngineTestHelpers

  class CowFed < EventEngine::EventDefinition
    event_name :cow_fed
    event_type :domain
    input :cow
    required_payload :weight, from: :cow, attr: :weight
  end

  test "engine boot loads the schema and requires the generated helpers" do
    helpers_snapshot = snapshot_event_engine_helpers
    previous_registry = EventEngine.active_registry
    dir = Dir.mktmpdir
    schema_path = File.join(dir, "event_schema.rb")

    EventEngine::EventSchemaDumper.dump!(definitions: [CowFed], path: schema_path)

    EventEngine::Engine.send(
      :load_schema_and_helpers,
      schema_path: schema_path
    )

    assert EventEngine.respond_to?(:cow_fed)
  ensure
    restore_event_engine_helpers(helpers_snapshot)
    EventEngine.active_registry = previous_registry
    FileUtils.remove_entry(dir) if dir
  end
end
