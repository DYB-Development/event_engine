require "test_helper"
require "rake"

class EventEngineCatalogTaskTest < ActiveSupport::TestCase
  setup do
    Rake.application = Rake::Application.new
    load File.expand_path("../../lib/tasks/event_engine_catalog.rake", __dir__)
    Rake::Task.define_task(:environment)
  end

  test "defines the catalog task" do
    assert Rake::Task.task_defined?("event_engine:catalog")
  end
end
