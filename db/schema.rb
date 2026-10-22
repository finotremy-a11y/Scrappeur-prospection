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

ActiveRecord::Schema[8.1].define(version: 2026_10_19_112000) do
  create_table "organizations", force: :cascade do |t|
    t.integer "category"
    t.string "city"
    t.string "cms_detected"
    t.datetime "created_at", null: false
    t.string "department"
    t.json "discovery_data", default: {}, null: false
    t.string "email"
    t.datetime "email_sent_at"
    t.boolean "has_conversion_keywords"
    t.boolean "has_form"
    t.integer "http_status"
    t.boolean "is_https"
    t.integer "lead_score"
    t.decimal "load_time_sec", precision: 8, scale: 3
    t.string "name"
    t.string "phone"
    t.string "source"
    t.datetime "unsubscribed_at"
    t.datetime "updated_at", null: false
    t.string "website"
    t.index ["website"], name: "index_organizations_on_website"
  end

  create_table "town_halls", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "department"
    t.string "email"
    t.string "name"
    t.datetime "updated_at", null: false
  end
end
