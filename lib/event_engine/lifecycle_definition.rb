require "event_engine/event_definition"

module EventEngine
  class LifecycleDefinition
    include EventDefinition::Inputs
    include EventDefinition::Payloads

    class << self
      def subject(value)
        @subject = value
      end

      def event_type(value)
        @event_type = value
      end

      def lifecycle(*verbs)
        @verbs = verbs
      end

      def generated_events
        @generated_events ||= Array(@verbs).map { |verb| build_event(verb) }
      end

      def declared_subject
        @subject
      end

      def declared_event_type
        @event_type
      end

      private

      def build_event(verb)
        template = self

        Class.new(EventDefinition) do
          event_name :"#{template.declared_subject}_#{verb}"
          event_type template.declared_event_type
        end
      end
    end
  end
end
