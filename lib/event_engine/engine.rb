module EventEngine
  class Engine < ::Rails::Engine
    isolate_namespace EventEngine

    initializer "event_engine.load_schema_and_helpers" do |app|
      EventEngine.configuration.schema_path = Rails.root.join("db", "event_schema.json").to_s

      app.config.after_initialize do
        schema_path = Rails.root.join("db", "event_schema.json")
        helpers_path = Rails.root.join("db", "event_engine_helpers.rb")

        if File.exist?(schema_path)
          Engine.send(:boot!, schema_path: schema_path, helpers_path: helpers_path)
        else
          Engine.send(:handle_missing_schema!, schema_path)
        end
      end
    end

    class << self
      private

      def boot!(schema_path:, helpers_path:)
        EventEngine.boot_from_schema!(
          schema_path: schema_path,
          registry: EventEngine::SchemaRegistry.new
        )

        load helpers_path if File.exist?(helpers_path)
      end

      def handle_missing_schema!(schema_path)
        if Rails.env.development? || Rails.env.test?
          Rails.logger.warn(
            "[EventEngine] Schema catalog not found at #{schema_path}. " \
            "Commit it, or build it from your packs' schema.json with: " \
            "bin/rails event_engine:schema:catalog"
          )
          return
        end

        raise <<~MSG
          EventEngine schema catalog missing.

          Expected to find:
            #{schema_path}

          Commit the catalog, or build it from your packs' schema.json:
            bin/rails event_engine:schema:catalog
        MSG
      end
    end
  end
end
