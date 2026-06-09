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

ActiveRecord::Schema[8.1].define(version: 2026_03_24_094642) do
  create_table "organizations", force: :cascade do |t|
    t.integer "category"
    t.string "city"
    t.datetime "created_at", null: false
    t.string "department"
    t.string "email"
    t.datetime "email_sent_at"
    t.string "name"
    t.string "source"
    t.datetime "unsubscribed_at"
    t.datetime "updated_at", null: false
  end

  create_table "town_halls", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "department"
    t.string "email"
    t.string "name"
    t.datetime "updated_at", null: false
  end
end
