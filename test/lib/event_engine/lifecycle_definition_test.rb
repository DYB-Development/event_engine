require "test_helper"

module EventEngine
  class LifecycleDefinitionTest < ActiveSupport::TestCase
    test "lifecycle generates a snake_case event per verb" do
      definition = Class.new(EventEngine::LifecycleDefinition) do
        subject :export_csv
        event_type :product
        lifecycle :started, :completed, :failed
      end

      names = definition.generated_events.map { |event| event.schema.event_name }

      assert_equal [:export_csv_started, :export_csv_completed, :export_csv_failed], names
    end

    test "every generated event carries the declared subject" do
      definition = Class.new(EventEngine::LifecycleDefinition) do
        subject :export_csv
        event_type :product
        lifecycle :started, :completed, :failed
      end

      subjects = definition.generated_events.map { |event| event.schema.subject }

      assert_equal [:export_csv, :export_csv, :export_csv], subjects
    end

    test "every generated event carries the declared process_type" do
      definition = Class.new(EventEngine::LifecycleDefinition) do
        subject :export_csv
        event_type :product
        process_type :broker
        lifecycle :started, :completed, :failed
      end

      process_types = definition.generated_events.map { |event| event.schema.process_type }

      assert_equal [:broker, :broker, :broker], process_types
    end

    test "shared required inputs appear on every generated event" do
      definition = Class.new(EventEngine::LifecycleDefinition) do
        subject :export_csv
        event_type :product
        input :export
        lifecycle :started, :completed, :failed
      end

      required_inputs = definition.generated_events.map { |event| event.schema.required_inputs }

      assert_equal [[:export], [:export], [:export]], required_inputs
    end

    test "shared payload fields appear on every generated event" do
      definition = Class.new(EventEngine::LifecycleDefinition) do
        subject :export_csv
        event_type :product
        input :export
        required_payload :format, from: :export, attr: :format
        lifecycle :started, :completed, :failed
      end

      payload_fields = definition.generated_events.map { |event| event.schema.payload_fields }

      assert_equal [[{ name: :format, required: true, from: :export, attr: :format }]] * 3, payload_fields
    end

    test "a generated event dumps identically to a hand-written equivalent" do
      family = Class.new(EventEngine::LifecycleDefinition) do
        subject :export_csv
        event_type :product
        input :export
        optional_input :requester
        required_payload :format, from: :export, attr: :format
        optional_payload :requested_by, from: :requester, attr: :name
        lifecycle :completed
      end

      hand_written = Class.new(EventEngine::EventDefinition) do
        event_name :export_csv_completed
        event_type :product
        subject :export_csv
        input :export
        optional_input :requester
        required_payload :format, from: :export, attr: :format
        optional_payload :requested_by, from: :requester, attr: :name
      end

      assert_equal hand_written.schema.to_ruby, family.generated_events.first.schema.to_ruby
    end

    test "an on-verb block layers a payload field onto that verb" do
      definition = Class.new(EventEngine::LifecycleDefinition) do
        subject :export_csv
        event_type :product
        input :export
        input :error
        required_payload :format, from: :export, attr: :format
        lifecycle :started, :failed

        on :failed do
          required_payload :error_class, from: :error, attr: :class
        end
      end

      failed = definition.generated_events.last
      field_names = failed.schema.payload_fields.map { |field| field[:name] }

      assert_equal [:format, :error_class], field_names
    end

    test "an on-verb block leaves other verbs untouched" do
      definition = Class.new(EventEngine::LifecycleDefinition) do
        subject :export_csv
        event_type :product
        input :export
        input :error
        required_payload :format, from: :export, attr: :format
        lifecycle :started, :failed

        on :failed do
          required_payload :error_class, from: :error, attr: :class
        end
      end

      started = definition.generated_events.first
      field_names = started.schema.payload_fields.map { |field| field[:name] }

      assert_equal [:format], field_names
    end

    test "an on-verb block can declare a verb-specific input" do
      definition = Class.new(EventEngine::LifecycleDefinition) do
        subject :export_csv
        event_type :product
        input :export
        lifecycle :started, :failed

        on :failed do
          input :error
        end
      end

      failed = definition.generated_events.last

      assert_equal [:export, :error], failed.schema.required_inputs
    end

    test "generated events are discoverable as EventDefinition descendants" do
      definition = Class.new(EventEngine::LifecycleDefinition) do
        subject :export_csv
        event_type :product
        lifecycle :started, :completed, :failed
      end

      assert definition.generated_events.all? { |event|
        EventEngine::EventDefinition.descendants.include?(event)
      }
    end
  end
end
