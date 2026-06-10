require "bundler/setup"

APP_RAKEFILE = File.expand_path("test/dummy/Rakefile", __dir__)
load "rails/tasks/engine.rake"

require "bundler/gem_tasks"

task test: "app:test"
task default: :test

require "event_engine/the_local"
require "the_local/rake"
