module EventEngine
  class Railtie < Rails::Railtie
    rake_tasks do
      load "tasks/event_engine_tasks.rake"
    end
  end
end
