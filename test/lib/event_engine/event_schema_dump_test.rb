require "test_helper"
require "tempfile"
require "json"

class EventSchemaDumpTest < ActiveSupport::TestCase
  class CowFed < EventEngine::EventDefinition
    event_name :cow_fed
    event_type :domain
    domain :sales
    input :cow
    required_payload :weight, from: :cow, attr: :weight
  end

  class PigWeighed < EventEngine::EventDefinition
    event_name :pig_weighed
    event_type :domain
    domain :ops
    input :pig
    required_payload :weight, from: :pig, attr: :weight
  end

  def read_versions(path)
    File.read(path).scan(/event_version:\s*(\d+)/).flatten.map(&:to_i)
  end

  test "dump writes initial version when schema file does not exist" do
    file = Tempfile.new("event_schema.rb")
    path = file.path
    file.unlink # ensure non-existent
 
    EventEngine::EventSchemaDumper.dump!(
      definitions: [CowFed],
      path: path
    )

    versions = read_versions(path)
    assert_equal [1], versions
  ensure
    file.unlink if File.exist?(path)
  end

  test "dump does not create new version when schema unchanged" do
    file = Tempfile.new("event_schema.rb")
    EventEngine::EventSchemaDumper.dump!(
      definitions: [CowFed],
      path: file.path
    )

    EventEngine::EventSchemaDumper.dump!(
      definitions: [CowFed],
      path: file.path
    )

    versions = read_versions(file.path)
    assert_equal [1], versions
  ensure
    file.unlink
  end

  test "dump reads prior versions from the JSON artifact" do
    schema_file = Tempfile.new("event_schema.rb")
    schema_path = schema_file.path
    schema_file.unlink # the Ruby artifact carries no prior history
    json_file = Tempfile.new(["event_schema", ".json"])

    prior = CowFed.schema.dup
    prior.event_version = 5
    json_file.write(JSON.pretty_generate([prior.to_h]))
    json_file.close

    EventEngine::EventSchemaDumper.dump!(
      definitions: [CowFed],
      path: schema_path,
      json_path: json_file.path
    )

    assert_equal [5], read_versions(schema_path)
  ensure
    File.delete(schema_path) if File.exist?(schema_path)
    json_file.unlink
  end

  test "dump writes the neutral JSON artifact when a json path is given" do
    schema_file = Tempfile.new("event_schema.rb")
    json_file = Tempfile.new(["event_schema", ".json"])

    EventEngine::EventSchemaDumper.dump!(
      definitions: [CowFed],
      path: schema_file.path,
      json_path: json_file.path
    )

    assert_includes File.read(json_file.path), %("event_name": "cow_fed")
  ensure
    schema_file.unlink
    json_file.unlink
  end

  test "dump scoped to a domain writes only that domain's events to the JSON slice" do
    schema_file = Tempfile.new("event_schema.rb")
    json_file = Tempfile.new(["event_schema", ".json"])

    EventEngine::EventSchemaDumper.dump!(
      definitions: [CowFed, PigWeighed],
      path: schema_file.path,
      json_path: json_file.path,
      domain: :sales
    )

    event_names = JSON.parse(File.read(json_file.path)).map { |event| event["event_name"] }
    assert_equal ["cow_fed"], event_names
  ensure
    schema_file.unlink
    json_file.unlink
  end

  test "dump writes generated helpers when a helpers path is given" do
    schema_file = Tempfile.new("event_schema.rb")
    helpers_file = Tempfile.new("event_engine_helpers.rb")

    EventEngine::EventSchemaDumper.dump!(
      definitions: [CowFed],
      path: schema_file.path,
      helpers_path: helpers_file.path
    )

    assert_includes File.read(helpers_file.path), "def self.cow_fed"
  ensure
    schema_file.unlink
    helpers_file.unlink
  end
end
