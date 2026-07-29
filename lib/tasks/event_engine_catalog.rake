namespace :event_engine do
  desc "Build the committed catalog from every pack, and keep the rules file in step"
  task catalog: :environment do
    catalog_path = Rails.root.join(EventEngine.configuration.schema_path)

    EventEngine::SchemaCatalogBuilder.build(
      sources: EventEngine.schema_sources,
      catalog_path: catalog_path
    )

    puts "Wrote EventEngine catalog to #{catalog_path}"

    rules_path = Rails.root.join(EventEngine.configuration.rules_path)

    EventEngine::RulesFile.sync(
      path: rules_path,
      event_names: JSON.parse(File.read(catalog_path)).map { |entry| entry["event_name"] }
    )

    puts "Wrote EventEngine processing rules to #{rules_path}"
  end
end
