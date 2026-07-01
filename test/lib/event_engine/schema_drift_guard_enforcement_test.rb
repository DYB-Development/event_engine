require "test_helper"
require "tempfile"

class SchemaDriftGuardEnforcementTest < ActiveSupport::TestCase
  class CowFed < EventEngine::EventDefinition
    event_name :cow_fed
    event_type :domain
    input :cow
    required_payload :weight, from: :cow, attr: :weight
  end

  class Horse < EventEngine::EventDefinition
    event_name :horse_fed
    event_type :domain
    input :horse
    required_payload :weight, from: :horse, attr: :weight
  end

  test "raises when DSL and schema file are out of sync" do
    file = Tempfile.new("event_schema.rb")

    # Baseline dump
    EventEngine::EventSchemaDumper.dump!(
      definitions: [CowFed],
      path: file.path
    )

    # Introduce drift
    CowFed.required_payload :age, from: :cow, attr: :age

    assert_raises(EventEngine::SchemaDriftGuard::DriftError) do
      EventEngine::SchemaDriftGuard.check!(
        schema_path: file.path,
        definitions: [CowFed]
      )
    end
  ensure
    file.unlink
  end

  test "drift error includes a readable diff of the added field" do
    file = Tempfile.new("event_schema.rb")

    EventEngine::EventSchemaDumper.dump!(
      definitions: [Horse],
      path: file.path
    )

    Horse.required_payload :age, from: :horse, attr: :age

    error = assert_raises(EventEngine::SchemaDriftGuard::DriftError) do
      EventEngine::SchemaDriftGuard.check!(
        schema_path: file.path,
        definitions: [Horse]
      )
    end

    assert_match(/\+.*age/, error.message)
  ensure
    file.unlink
  end

  test "raises when the JSON schema artifact is out of sync" do
    schema_file = Tempfile.new("event_schema.rb")
    json_file = Tempfile.new(["event_schema", ".json"])

    EventEngine::EventSchemaDumper.dump!(
      definitions: [CowFed],
      path: schema_file.path,
      json_path: json_file.path
    )

    File.write(json_file.path, "[]\n")

    assert_raises(EventEngine::SchemaDriftGuard::DriftError) do
      EventEngine::SchemaDriftGuard.check!(
        schema_path: schema_file.path,
        definitions: [CowFed],
        json_path: json_file.path
      )
    end
  ensure
    schema_file.unlink
    json_file.unlink
  end

  test "raises a does-not-exist error when the JSON schema artifact is missing" do
    schema_file = Tempfile.new("event_schema.rb")
    json_file = Tempfile.new(["event_schema", ".json"])
    json_path = json_file.path

    EventEngine::EventSchemaDumper.dump!(
      definitions: [CowFed],
      path: schema_file.path
    )

    json_file.unlink

    error = assert_raises(EventEngine::SchemaDriftGuard::DriftError) do
      EventEngine::SchemaDriftGuard.check!(
        schema_path: schema_file.path,
        definitions: [CowFed],
        json_path: json_path
      )
    end

    assert_match(/does not exist/, error.message)
  ensure
    schema_file.unlink
  end

  test "raises when the generated helpers file is out of sync" do
    schema_file = Tempfile.new("event_schema.rb")
    helpers_file = Tempfile.new("event_engine_helpers.rb")

    EventEngine::EventSchemaDumper.dump!(
      definitions: [CowFed],
      path: schema_file.path,
      helpers_path: helpers_file.path
    )

    File.write(helpers_file.path, "# stale helpers\n")

    assert_raises(EventEngine::SchemaDriftGuard::DriftError) do
      EventEngine::SchemaDriftGuard.check!(
        schema_path: schema_file.path,
        definitions: [CowFed],
        helpers_path: helpers_file.path
      )
    end
  ensure
    schema_file.unlink
    helpers_file.unlink
  end
end
