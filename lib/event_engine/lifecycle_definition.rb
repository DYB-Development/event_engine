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

      def process_type(value)
        @process_type = value
      end

      def lifecycle(*verbs)
        @verbs = verbs
      end

      def on(verb, &block)
        verb_overrides[verb] = block
      end

      def verb_overrides
        @verb_overrides ||= {}
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

      def declared_process_type
        @process_type
      end

      private

      def build_event(verb)
        template = self

        Class.new(EventDefinition) do
          event_name :"#{template.declared_subject}_#{verb}"
          event_type template.declared_event_type
          subject template.declared_subject
          process_type template.declared_process_type if template.declared_process_type

          template.inputs.each do |name, kind|
            kind == :required ? input(name) : optional_input(name)
          end

          template.payload_fields.each do |field|
            if field[:required]
              required_payload field[:name], from: field[:from], attr: field[:attr]
            else
              optional_payload field[:name], from: field[:from], attr: field[:attr]
            end
          end

          override = template.verb_overrides[verb]
          class_eval(&override) if override
        end
      end
    end
  end
end
