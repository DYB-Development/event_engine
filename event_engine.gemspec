require_relative "lib/event_engine/version"

Gem::Specification.new do |spec|
  spec.name        = "event_engine"
  spec.version     = EventEngine::VERSION
  spec.authors     = ["tylercschneider"]
  spec.email       = ["tylercschneider@gmail.com"]
  spec.homepage    = "https://eventengine.co"
  spec.summary     = "The Rails host runtime for the schema-first EventEngine pipeline"
  spec.description = "The runtime of the EventEngine pipeline: load the committed schema catalog aggregated from domain packs, build validated events, and dispatch them to registered handlers by process_type. Events are declared with event_engine-event_definition; durable delivery, transports, and the dashboard live in event_engine-delivery."
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.2.0"

  repo_url = "https://github.com/DYB-Development/event_engine"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.add_dependency "railties", ">= 7.1.6", "< 9"
  spec.add_dependency "activesupport", ">= 7.1.6", "< 9"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = repo_url
  spec.metadata["changelog_uri"] = "#{repo_url}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{repo_url}/issues"
  spec.metadata["documentation_uri"] = "#{repo_url}#readme"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md", "CHANGELOG.md"]
  end

end
