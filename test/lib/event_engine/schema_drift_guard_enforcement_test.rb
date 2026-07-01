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

  test "raises when the generated helpers file is out of sync" do
    file = Tempfile.new("event_schema.rb")
    EventEngine::EventSchemaDumper.dump!(
      definitions: [CowFed],
      path: file.path
    )
    helpers_path = EventEngine::EventSchemaDumper.default_helpers_path(file.path)
    File.write(helpers_path, "# stale helpers\n")

    assert_raises(EventEngine::SchemaDriftGuard::DriftError) do
      EventEngine::SchemaDriftGuard.check!(
        schema_path: file.path,
        definitions: [CowFed]
      )
    end
  ensure
    file.unlink
    File.delete(helpers_path) if helpers_path && File.exist?(helpers_path)
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
end
