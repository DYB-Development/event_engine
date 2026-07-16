module EventEngine
  class EventDefinition
    module Payloads
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def optional_payload(name, from: nil, attr: nil)
          payload_fields << {
            name: name.to_sym,
            required: false,
            from: from,
            attr: attr
          }
        end

        def required_payload(name, from: nil, attr: nil)
          payload_fields << {
            name: name.to_sym,
            required: true,
            from: from,
            attr: attr
          }
        end

        def payload_fields
          @payload_fields ||= []
        end
      end
    end
  end
end
