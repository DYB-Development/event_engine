class AddEventLevelToEventEngineOutboxEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :event_engine_outbox_events, :event_level, :integer
  end
end
