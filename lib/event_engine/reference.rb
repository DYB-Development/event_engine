module EventEngine
  # Single source of truth for the EventEngine API reference. The companion
  # Claude Code subagents (and any future doc generator) read from here so they
  # can never disagree about how the gem is used.
  module Reference
    DIR = File.expand_path("reference", __dir__)

    def self.content
      read("guide.md")
    end

    def self.read(name)
      File.read(File.join(DIR, name)).chomp
    end
  end
end
