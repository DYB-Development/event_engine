module EventEngine
  module DefinitionLoader
    class << self
      attr_writer :loader

      def ensure_loaded!
        eager_load_definitions!
        LifecycleDefinition.materialize_all!
      end

      def eager_load_definitions!
        return if loaded?

        loader.call

        @loaded = true
      end

      def loader
        @loader ||= rails_eager_loader
      end

      def loaded?
        @loaded ||= false
      end

      def reset!
        @loaded = false
        @loader = nil
      end

      private

      def rails_eager_loader
        lambda do
          unless defined?(Rails) && Rails.application
            raise "EventEngine requires a Rails application to load definitions"
          end

          Rails.application.eager_load!
        end
      end
    end
  end
end
