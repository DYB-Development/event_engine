require "test_helper"
require "rake"

module EventEngine
  class RailtieRakeTasksTest < ActiveSupport::TestCase
    test "the railtie loads the gem's rake tasks" do
      Rake.application = Rake::Application.new
      Rake::Task.define_task(:environment)

      EventEngine::Railtie.rake_tasks.each { |block| EventEngine::Railtie.instance_eval(&block) }

      assert Rake::Task.task_defined?("event_engine:catalog")
    end
  end
end
