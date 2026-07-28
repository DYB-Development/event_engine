require "yaml"

module EventEngine
  class RulesFile
    def self.sync(path:, event_names:)
      existing = File.exist?(path.to_s) ? (YAML.safe_load_file(path.to_s) || {}) : {}
      decided = existing["events"] || {}
      events = event_names.to_h { |name| [ name.to_s, decided[name.to_s] ] }

      File.write(path, YAML.dump(existing.merge("events" => events)))
      path
    end
  end
end
