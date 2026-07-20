namespace :event_engine do
  namespace :schema do
    desc "Aggregate every published pack's schema.json into the committed catalog"
    task catalog: :environment do
      catalog_path = Rails.root.join(EventEngine.configuration.schema_path)

      EventEngine::SchemaCatalogBuilder.build(
        sources: EventEngine.configuration.publisher_schema_paths,
        catalog_path: catalog_path
      )

      puts "Wrote EventEngine catalog to #{catalog_path}"
    end
  end
end
