namespace :event_engine do
  desc "Render the event schema and subjects as a markdown catalog"
  task catalog: :environment do
    catalog = EventEngine::SchemaCatalog.new(
      schema_registry: EventEngine.file_schema_registry,
      subject_registry: EventEngine.subject_registry
    )

    puts catalog.to_markdown
  end
end
