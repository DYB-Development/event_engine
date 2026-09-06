require "json"

module EventEngine
  class EventSchemaJsonLoader
    def self.load(path)
      schema = EventSchema.new
      return schema unless File.exist?(path)

      contents = File.read(path.to_s)
      return schema if contents.strip.empty?

      JSON.parse(contents).each do |attributes|
        schema.register(CatalogEntry.from_h(attributes))
      end

      schema
    end
  end
end
