require "json"

module EventEngine
  class SchemaCatalogBuilder
    def self.build(sources:, catalog_path:)
      entries = sources.flat_map { |source| read(source) }

      File.write(catalog_path, "#{JSON.pretty_generate(entries)}\n")
    end

    def self.read(source)
      contents = File.read(source.to_s)
      return [] if contents.strip.empty?

      JSON.parse(contents)
    end
  end
end
