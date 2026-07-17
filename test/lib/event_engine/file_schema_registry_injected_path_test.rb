require "test_helper"
require "json"
require "tmpdir"

class FileSchemaRegistryInjectedPathTest < ActiveSupport::TestCase
  def cow_fed_schema
    EventEngine::EventDefinition::Schema.new(
      event_name: :cow_fed,
      event_version: 1,
      event_type: :domain,
      required_inputs: [:cow],
      optional_inputs: [],
      payload_fields: [{ name: :weight, required: true, from: :cow, attr: :weight }]
    )
  end

  test "reads the schema from an injected path rather than Rails.root" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "event_schema.json")
      File.write(path, JSON.pretty_generate([cow_fed_schema.to_h]))

      registry = EventEngine.file_schema_registry(schema_path: path)

      assert_equal [1], registry.versions_for(:cow_fed)
    end
  end
end
