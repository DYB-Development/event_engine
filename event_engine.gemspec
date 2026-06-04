require_relative "lib/event_engine/version"

Gem::Specification.new do |spec|
  spec.name        = "event_engine"
  spec.version     = EventEngine::VERSION
  spec.authors     = ["tylercschneider"]
  spec.email       = ["tylercschneider@gmail.com"]
  spec.homepage    = "https://github.com/tylercschneider/event_engine"
  spec.summary     = "Schema-first event definitions and dispatch for Rails"
  spec.description = "The core of the EventEngine pipeline: define events with a Ruby DSL, compile to a canonical schema, and dispatch built events to registered handlers by level. Durable delivery, transports, the outbox, and the observability dashboard live in the companion gem event_engine-delivery."
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/tylercschneider/event_engine/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/tylercschneider/event_engine/issues"
  spec.metadata["documentation_uri"] = "https://github.com/tylercschneider/event_engine#readme"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md", "CHANGELOG.md"]
  end

  spec.add_dependency "rails", ">= 7.1.6", "< 9"
end
