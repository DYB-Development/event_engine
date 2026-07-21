require "test_helper"
require "ostruct"

module EventEngine
  class PassthroughPayloadTest < ActiveSupport::TestCase
    def user_defined_event_schema
      EventDefinition::Schema.new(
        event_name: :user_defined_event,
        event_version: 1,
        event_type: :domain,
        required_inputs: [:account, :event_type_name, :payload],
        optional_inputs: [],
        payload_fields: [
          { name: :account_id, required: true, from: :account, attr: :id },
          { name: :event_type_name, required: true, from: :event_type_name },
          { name: :payload, required: true, from: :payload }
        ]
      )
    end

    test "passthrough payload uses input value directly when attr is omitted" do
      account = OpenStruct.new(id: 123)

      attrs = EventBuilder.build(
        schema: user_defined_event_schema,
        data: {
          account: account,
          event_type_name: "custom_event",
          payload: { foo: "bar", count: 42 }
        }
      )

      assert_equal 123, attrs[:payload][:account_id]
      assert_equal "custom_event", attrs[:payload][:event_type_name]
      assert_equal({ foo: "bar", count: 42 }, attrs[:payload][:payload])
    end
  end
end
