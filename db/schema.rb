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

ActiveRecord::Schema[7.0].define(version: 2023_05_06_062402) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_stat_statements"
  enable_extension "plpgsql"

  create_table "active_admin_comments", id: :serial, force: :cascade do |t|
    t.string "namespace", limit: 255
    t.text "body"
    t.string "resource_id", limit: 255, null: false
    t.string "resource_type", limit: 255, null: false
    t.integer "author_id"
    t.string "author_type", limit: 255
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author_type_and_author_id"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource_type_and_resource_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "clubs", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["name"], name: "index_clubs_on_name", unique: true
  end

  create_table "cups", id: :serial, force: :cascade do |t|
    t.date "start_on", null: false
    t.date "end_on"
    t.datetime "deadline", precision: nil, null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "junior_fees_chf", null: false
    t.integer "junior_fees_eur", null: false
    t.integer "adult_fees_chf", null: false
    t.integer "adult_fees_eur", null: false
    t.date "published_on"
    t.integer "year"
    t.datetime "canceled_at"
    t.datetime "registerable_at"
    t.text "description_en"
    t.text "description_fr"
    t.bigint "product_junior_id"
    t.bigint "product_adult_id"
    t.index ["product_adult_id"], name: "index_cups_on_product_adult_id"
    t.index ["product_junior_id"], name: "index_cups_on_product_junior_id"
    t.index ["start_on"], name: "index_cups_on_start_on", unique: true
  end

  create_table "documents", force: :cascade do |t|
    t.string "name", null: false
    t.string "category_type", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_type", "category_id"], name: "index_documents_on_category"
    t.index ["name", "category_type", "category_id"], name: "index_documents_on_name_and_category_type_and_category_id", unique: true
  end

  create_table "events", id: :serial, force: :cascade do |t|
    t.integer "cup_id", null: false
    t.string "name_en", limit: 255, null: false
    t.string "name_fr", limit: 255, null: false
    t.datetime "start_on", precision: nil, null: false
    t.integer "duration"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.string "name_de"
    t.index ["cup_id"], name: "index_events_on_cup_id"
  end

  create_table "fights", id: :serial, force: :cascade do |t|
    t.integer "individual_category_id", null: false
    t.integer "team_category_id"
    t.integer "winner_id"
    t.integer "parent_fight_1_id"
    t.integer "parent_fight_2_id"
    t.string "fighter_type", limit: 255
    t.integer "fighter_1_id", null: false
    t.integer "fighter_2_id", null: false
    t.integer "number", null: false
    t.string "score", limit: 255
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["fighter_1_id"], name: "index_fights_on_fighter_1_id"
    t.index ["fighter_2_id"], name: "index_fights_on_fighter_2_id"
    t.index ["individual_category_id", "number"], name: "index_fights_on_individual_category_id_and_number", unique: true
    t.index ["individual_category_id"], name: "index_fights_on_individual_category_id"
    t.index ["number"], name: "index_fights_on_number"
    t.index ["parent_fight_1_id"], name: "index_fights_on_parent_fight_1_id"
    t.index ["parent_fight_2_id"], name: "index_fights_on_parent_fight_2_id"
    t.index ["team_category_id"], name: "index_fights_on_team_category_id"
    t.index ["winner_id"], name: "index_fights_on_winner_id"
  end

  create_table "headlines", id: :serial, force: :cascade do |t|
    t.string "title_fr", limit: 255, null: false
    t.string "title_en", limit: 255, null: false
    t.text "content_fr", null: false
    t.text "content_en", null: false
    t.integer "cup_id", null: false
    t.boolean "shown", default: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.string "title_de"
    t.text "content_de"
    t.index ["cup_id"], name: "index_headlines_on_cup_id"
  end

  create_table "individual_categories", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.integer "pool_size"
    t.integer "out_of_pool"
    t.integer "min_age"
    t.integer "max_age"
    t.text "description_en"
    t.text "description_fr"
    t.integer "cup_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.text "description_de"
    t.index ["cup_id", "name"], name: "index_individual_categories_on_cup_id_and_name", unique: true
    t.index ["cup_id"], name: "index_individual_categories_on_cup_id"
  end

  create_table "kenshis", id: :serial, force: :cascade do |t|
    t.string "first_name", limit: 255, null: false
    t.string "last_name", limit: 255, null: false
    t.boolean "female"
    t.integer "cup_id", null: false
    t.integer "user_id", null: false
    t.date "dob", null: false
    t.integer "club_id", null: false
    t.string "email", limit: 255
    t.string "grade", limit: 255, null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.text "remarks"
    t.index ["club_id"], name: "index_kenshis_on_club_id"
    t.index ["cup_id", "first_name", "last_name"], name: "index_kenshis_on_cup_id_and_first_name_and_last_name", unique: true
    t.index ["cup_id"], name: "index_kenshis_on_cup_id"
    t.index ["grade"], name: "index_kenshis_on_grade"
    t.index ["last_name"], name: "index_kenshis_on_last_name"
    t.index ["user_id"], name: "index_kenshis_on_user_id"
  end

  create_table "participations", id: :serial, force: :cascade do |t|
    t.integer "category_id", null: false
    t.string "category_type", limit: 255
    t.integer "team_id"
    t.integer "kenshi_id", null: false
    t.integer "pool_number"
    t.integer "pool_position"
    t.boolean "ronin"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "rank"
    t.boolean "fighting_spirit", default: false
    t.index ["category_id", "category_type"], name: "index_participations_on_category_id_and_category_type"
    t.index ["kenshi_id"], name: "index_participations_on_kenshi_id"
    t.index ["pool_number"], name: "index_participations_on_pool_number"
    t.index ["rank"], name: "index_participations_on_rank"
    t.index ["team_id"], name: "index_participations_on_team_id"
  end

  create_table "products", id: :serial, force: :cascade do |t|
    t.string "name_en", limit: 255, null: false
    t.string "name_fr", limit: 255, null: false
    t.text "description_en"
    t.text "description_fr"
    t.integer "fee_chf", null: false
    t.integer "fee_eu", null: false
    t.integer "event_id"
    t.integer "cup_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.string "name_de"
    t.text "description_de"
    t.integer "quota"
    t.index ["cup_id", "name_en"], name: "index_products_on_cup_id_and_name_en", unique: true
    t.index ["cup_id", "name_fr"], name: "index_products_on_cup_id_and_name_fr", unique: true
    t.index ["cup_id"], name: "index_products_on_cup_id"
    t.index ["event_id"], name: "index_products_on_event_id"
  end

  create_table "purchases", id: :serial, force: :cascade do |t|
    t.integer "kenshi_id", null: false
    t.integer "product_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["kenshi_id"], name: "index_purchases_on_kenshi_id"
    t.index ["product_id"], name: "index_purchases_on_product_id"
  end

  create_table "team_categories", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.integer "pool_size"
    t.integer "out_of_pool"
    t.integer "min_age"
    t.integer "max_age"
    t.text "description_en"
    t.text "description_fr"
    t.integer "cup_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.text "description_de"
    t.index ["cup_id", "name"], name: "index_team_categories_on_cup_id_and_name", unique: true
    t.index ["cup_id"], name: "index_team_categories_on_cup_id"
  end

  create_table "teams", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.integer "team_category_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "rank"
    t.index ["rank"], name: "index_teams_on_rank"
    t.index ["team_category_id", "name"], name: "index_teams_on_team_category_id_and_name", unique: true
    t.index ["team_category_id"], name: "index_teams_on_team_category_id"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "email", limit: 255, default: "", null: false
    t.string "encrypted_password", limit: 255, default: "", null: false
    t.string "reset_password_token", limit: 255
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.string "current_sign_in_ip", limit: 255
    t.string "last_sign_in_ip", limit: 255
    t.string "confirmation_token", limit: 255
    t.datetime "confirmed_at", precision: nil
    t.datetime "confirmation_sent_at", precision: nil
    t.string "unconfirmed_email", limit: 255
    t.boolean "admin", default: false
    t.string "first_name", limit: 255, null: false
    t.string "last_name", limit: 255, null: false
    t.boolean "female"
    t.date "dob"
    t.integer "club_id"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.string "provider", limit: 255
    t.string "uid", limit: 255
    t.index ["club_id"], name: "index_users_on_club_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "videos", force: :cascade do |t|
    t.string "url", null: false
    t.string "name", null: false
    t.string "category_type", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_type", "category_id"], name: "index_videos_on_category"
    t.index ["name", "category_type", "category_id"], name: "index_videos_on_name_and_category_type_and_category_id", unique: true
    t.index ["url"], name: "index_videos_on_url", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "cups", "products", column: "product_adult_id"
  add_foreign_key "cups", "products", column: "product_junior_id"
  add_foreign_key "events", "cups"
  add_foreign_key "headlines", "cups"
  add_foreign_key "individual_categories", "cups"
  add_foreign_key "kenshis", "clubs"
  add_foreign_key "kenshis", "cups"
  add_foreign_key "kenshis", "users"
  add_foreign_key "participations", "kenshis"
  add_foreign_key "participations", "teams"
  add_foreign_key "products", "cups"
  add_foreign_key "products", "events"
  add_foreign_key "purchases", "kenshis"
  add_foreign_key "purchases", "products"
  add_foreign_key "team_categories", "cups"
  add_foreign_key "teams", "team_categories"
  add_foreign_key "users", "clubs"
end
