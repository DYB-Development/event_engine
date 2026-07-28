require "yaml"

module EventEngine
  class ProcessingRules
    def self.load(path)
      return new unless File.exist?(path.to_s)

      contents = YAML.safe_load_file(path.to_s) || {}

      new(
        default: contents["default"]&.to_sym,
        packs: symbolize(contents["packs"]),
        events: symbolize(contents["events"])
      )
    end

    def self.symbolize(section)
      (section || {}).to_h { |key, value| [ key.to_sym, value&.to_sym ] }
    end

    def initialize(default: nil, packs: {}, events: {})
      @default = default
      @packs = packs
      @events = events
    end

    def for(event_name:, pack:)
      @events[event_name] || @packs[pack] || @default
    end

    def any?
      !@default.nil? || @packs.any? || @events.any?
    end
  end
end
