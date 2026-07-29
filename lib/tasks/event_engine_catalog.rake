namespace :event_engine do
  desc "Render the catalog as markdown"
  task catalog: :environment do
    catalog = EventEngine::SchemaCatalog.new(
      schema_registry: EventEngine.file_schema_registry
    )

    puts catalog.to_markdown
  end
end
