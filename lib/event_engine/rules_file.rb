require "yaml"

module EventEngine
  class RulesFile
    def self.sync(path:, event_names:)
      events = event_names.to_h { |name| [ name.to_s, nil ] }

      File.write(path, YAML.dump({ "events" => events }))
      path
    end
  end
end
