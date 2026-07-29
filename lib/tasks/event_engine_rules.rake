namespace :event_engine do
  namespace :rules do
    desc "Check that every processing rule names a registered processor"
    task check: :environment do
      EventEngine.validate_rules!

      puts "EventEngine rules OK: #{EventEngine.processing_rules.processor_names.map(&:inspect).join(", ")}"
    end
  end
end
