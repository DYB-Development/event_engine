module EventEngine
  class Engine < ::Rails::Engine
    isolate_namespace EventEngine

    initializer "event_engine.load_schema_and_install_helpers" do |app|
      app.config.after_initialize do
        schema_path = Rails.root.join("db", "event_schema.rb")

        if File.exist?(schema_path)
          Engine.send(
            :load_schema_and_install_helpers,
            schema_path: schema_path
          )
        else
          Engine.send(
            :handle_missing_schema!,
            schema_path
          )
        end
      end
    end

    class << self
      private

      def load_schema_and_install_helpers(schema_path:)
        EventEngine.boot_from_schema!(
          schema_path: schema_path,
          registry: EventEngine::SchemaRegistry.new
        )
      end

      def handle_missing_schema!(schema_path)
        if Rails.env.development? || Rails.env.test?
          Rails.logger.warn(
            "[EventEngine] Schema file not found at #{schema_path}. " \
            "Run: bin/rails event_engine:schema:dump"
          )
          return
        end

        raise <<~MSG
          EventEngine schema file missing.

          Expected to find:
            #{schema_path}

          Run:
            bin/rails event_engine:schema:dump

          And commit the generated file.
        MSG
      end
    end
  end
end
