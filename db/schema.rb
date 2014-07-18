# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20140717100456) do



  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "hstore"

  create_table "agreements", force: true do |t|
    t.integer  "manager_id"
    t.integer  "jobholder_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.hstore   "headcount_responsibilities"
    t.hstore   "budgetary_responsibilities", array: true
    t.hstore   "objectives",                 array: true
  end

  add_index "agreements", ["manager_id", "jobholder_id"], name: "index_agreements_on_manager_id_and_jobholder_id", using: :btree

  create_table "users", force: true do |t|
    t.text     "name"
    t.text     "email",           null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "staff_number"
    t.string   "password_digest"
    t.text     "grade"
    t.text     "organisation"

  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree

end
