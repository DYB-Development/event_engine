require "test_helper"

module EventEngine
  class EmitProcessTypeTest < ActiveSupport::TestCase
    class ContractOnlySchema
      def event_name = :cow_fed
      def event_type = :domain
      def event_version = 1
      def subject = nil
      def domain = :sales
      def required_inputs = []
      def optional_inputs = []
      def payload_fields = []
    end

    setup do
      @registry = EventEngine.schema_registry
      EventEngine.schema_registry = Class.new do
        def schema(*, **) = ContractOnlySchema.new
      end.new
    end

    teardown do
      EventEngine.schema_registry = @registry
      EventEngine.reset_handlers!
    end

    test "emits an event whose schema carries no process_type" do
      assert_nothing_raised { EventEngine.emit(:cow_fed, inputs: {}) }
    end
  end
end
