require "test_helper"

class SchemaToRubyTest < ActiveSupport::TestCase
  test "schema emits deterministic ruby constructor" do
    schema = EventEngine::EventDefinition::Schema.new(
      event_name: "cow.fed",
      event_version: 1,
      event_type: "domain",
      event_level: 3,
      process_type: :durable,
      required_inputs: [:cow],
      optional_inputs: [:barn],
      payload_fields: [
        { name: :cow_id, from: :cow, attr: :id }
      ]
    )

    ruby = schema.to_ruby

    expected = <<~RUBY.strip
      EventEngine::EventDefinition::Schema.new(
        event_name: "cow.fed",
        event_version: 1,
        event_type: "domain",
        event_level: 3,
        process_type: :durable,
        required_inputs: [:cow],
        optional_inputs: [:barn],
        payload_fields: [{name: :cow_id, from: :cow, attr: :id}]
      )
    RUBY

    assert_equal expected, ruby
  end
end
