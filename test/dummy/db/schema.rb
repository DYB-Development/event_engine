# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_12_000004) do
  create_table "event_engine_outbox_events", force: :cascade do |t|
    t.string "aggregate_id"
    t.string "aggregate_type"
    t.integer "aggregate_version"
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "dead_lettered_at"
    t.string "event_name", null: false
    t.integer "event_level"
    t.string "event_type", null: false
    t.integer "event_version", null: false
    t.string "idempotency_key"
    t.string "last_error_class"
    t.text "last_error_message"
    t.json "metadata"
    t.datetime "occurred_at", null: false
    t.json "payload", null: false
    t.datetime "published_at"
    t.datetime "updated_at", null: false
    t.index ["aggregate_type", "aggregate_id"], name: "idx_outbox_events_aggregate"
    t.index ["created_at"], name: "index_event_engine_outbox_events_on_created_at"
    t.index ["dead_lettered_at"], name: "index_event_engine_outbox_events_on_dead_lettered_at"
    t.index ["idempotency_key"], name: "index_event_engine_outbox_events_on_idempotency_key", unique: true
    t.index ["published_at", "dead_lettered_at", "created_at"], name: "idx_outbox_events_publishable"
    t.index ["published_at"], name: "index_event_engine_outbox_events_on_published_at"
  end
end
