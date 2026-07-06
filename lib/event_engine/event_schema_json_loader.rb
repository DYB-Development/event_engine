require "json"

module EventEngine
  class EventSchemaJsonLoader
    def self.load(path)
      registry = SchemaRegistry.new
      return registry unless File.exist?(path)

      contents = File.read(path.to_s)
      return registry if contents.strip.empty?

      JSON.parse(contents).each do |attributes|
        registry.register(EventDefinition::Schema.from_h(attributes))
      end

      registry
    end
  end
end
