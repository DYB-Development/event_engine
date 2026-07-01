module EventEngine
  class EventEngineHelpersWriter
    def self.write(path, event_schema)
      File.open(path, "w") do |io|
        event_schema.events.each do |event_name|
          io.write("def #{event_name}\nend\n")
        end
      end
    end
  end
end
