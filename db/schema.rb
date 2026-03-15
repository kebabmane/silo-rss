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

ActiveRecord::Schema[8.0].define(version: 2026_03_15_000002) do
  create_table "action_push_native_devices", force: :cascade do |t|
    t.string "name"
    t.string "platform", null: false
    t.string "token", null: false
    t.string "owner_type"
    t.integer "owner_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id"], name: "index_action_push_native_devices_on_owner"
  end

  create_table "article_states", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "article_id", null: false
    t.boolean "read", default: false, null: false
    t.boolean "starred", default: false, null: false
    t.boolean "archived", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["article_id"], name: "index_article_states_on_article_id"
    t.index ["user_id", "article_id"], name: "index_article_states_on_user_id_and_article_id", unique: true
    t.index ["user_id", "read", "archived"], name: "index_article_states_on_user_read_archived"
    t.index ["user_id", "starred"], name: "index_article_states_on_user_starred", where: "starred = true"
    t.index ["user_id"], name: "index_article_states_on_user_id"
    t.index ["user_id"], name: "index_article_states_on_user_unread", where: "read = false"
  end

  create_table "articles", force: :cascade do |t|
    t.integer "feed_id", null: false
    t.string "title"
    t.text "content"
    t.string "url"
    t.string "guid"
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "full_content"
    t.index ["feed_id", "guid"], name: "index_articles_on_feed_id_and_guid", unique: true
    t.index ["feed_id", "published_at"], name: "index_articles_on_feed_id_and_published_at"
    t.index ["feed_id"], name: "index_articles_on_feed_id"
    t.index ["published_at"], name: "index_articles_on_published_at"
  end

  create_table "daily_brief_feed_filters", force: :cascade do |t|
    t.integer "daily_brief_schedule_id", null: false
    t.integer "feed_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["daily_brief_schedule_id", "feed_id"], name: "index_daily_brief_feed_filters_unique", unique: true
    t.index ["daily_brief_schedule_id"], name: "index_daily_brief_feed_filters_on_daily_brief_schedule_id"
    t.index ["feed_id"], name: "index_daily_brief_feed_filters_on_feed_id"
  end

  create_table "daily_brief_schedules", force: :cascade do |t|
    t.integer "user_id", null: false
    t.time "time_of_day", null: false
    t.json "days_of_week", default: [], null: false
    t.boolean "email_delivery", default: false, null: false
    t.boolean "include_all_feeds", default: true, null: false
    t.string "summary_length", default: "medium", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "digest_type", default: "brief", null: false
    t.index ["user_id", "active"], name: "index_daily_brief_schedules_on_user_id_and_active"
    t.index ["user_id"], name: "index_daily_brief_schedules_on_user_active", where: "active = true"
    t.index ["user_id"], name: "index_daily_brief_schedules_on_user_id"
  end

  create_table "daily_briefs", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "daily_brief_schedule_id", null: false
    t.text "content"
    t.integer "article_count", default: 0, null: false
    t.datetime "generated_at", null: false
    t.datetime "emailed_at"
    t.boolean "read", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "digest_type", default: "brief"
    t.json "sections", default: []
    t.json "themes", default: []
    t.integer "reading_time_minutes"
    t.json "generation_metadata", default: {}
    t.json "article_ids", default: []
    t.index ["daily_brief_schedule_id"], name: "index_daily_briefs_on_daily_brief_schedule_id"
    t.index ["generated_at"], name: "index_daily_briefs_on_generated_at"
    t.index ["user_id", "generated_at"], name: "index_daily_briefs_on_user_id_and_generated_at"
    t.index ["user_id"], name: "index_daily_briefs_on_user_id"
  end

  create_table "device_registrations", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "device_token", null: false
    t.string "platform", default: "android", null: false
    t.datetime "last_seen_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["device_token"], name: "index_device_registrations_on_device_token"
    t.index ["user_id", "device_token"], name: "index_device_registrations_on_user_id_and_device_token", unique: true
    t.index ["user_id", "platform"], name: "index_device_registrations_on_user_id_and_platform"
    t.index ["user_id"], name: "index_device_registrations_on_user_id"
  end

  create_table "feeds", force: :cascade do |t|
    t.string "title"
    t.string "feed_url", null: false
    t.string "site_url"
    t.datetime "last_fetched_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "articles_count", default: 0, null: false
    t.index ["feed_url"], name: "index_feeds_on_feed_url", unique: true
  end

  create_table "litellm_settings", force: :cascade do |t|
    t.string "server_url"
    t.string "api_key"
    t.string "default_model"
    t.integer "max_tokens", default: 4000
    t.decimal "temperature", precision: 3, scale: 2, default: "0.7"
    t.integer "timeout", default: 30
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "expires_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.string "key"
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "subscriptions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "feed_id", null: false
    t.string "category"
    t.string "custom_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feed_id"], name: "index_subscriptions_on_feed_id"
    t.index ["user_id", "category"], name: "index_subscriptions_on_user_id_and_category"
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "suggested_feeds", force: :cascade do |t|
    t.string "title"
    t.string "feed_url"
    t.string "category"
    t.text "description"
    t.integer "display_order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "api_token"
    t.datetime "api_token_expires_at"
    t.integer "subscriptions_count", default: 0, null: false
    t.string "password_reset_digest"
    t.datetime "password_reset_sent_at"
    t.boolean "admin", default: false, null: false
    t.string "api_token_digest"
    t.datetime "confirmed_at"
    t.integer "confirmed_by_id"
    t.string "time_zone", default: "Etc/UTC", null: false
    t.datetime "onboarding_completed_at"
    t.index ["admin"], name: "index_users_on_admin"
    t.index ["api_token"], name: "index_users_on_api_token", unique: true
    t.index ["api_token_digest"], name: "index_users_on_api_token_digest", unique: true
    t.index ["api_token_expires_at"], name: "index_users_on_api_token_expires_at"
    t.index ["confirmed_at"], name: "index_users_on_confirmed_at"
    t.index ["confirmed_by_id"], name: "index_users_on_confirmed_by_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["password_reset_digest"], name: "index_users_on_password_reset_digest", unique: true
  end

  add_foreign_key "article_states", "articles"
  add_foreign_key "article_states", "users"
  add_foreign_key "articles", "feeds"
  add_foreign_key "daily_brief_feed_filters", "daily_brief_schedules"
  add_foreign_key "daily_brief_feed_filters", "feeds"
  add_foreign_key "daily_brief_schedules", "users"
  add_foreign_key "daily_briefs", "daily_brief_schedules"
  add_foreign_key "daily_briefs", "users"
  add_foreign_key "device_registrations", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "subscriptions", "feeds"
  add_foreign_key "subscriptions", "users"
  add_foreign_key "users", "users", column: "confirmed_by_id"

  # Virtual tables (FTS5) are managed by config/initializers/fts5_setup.rb
end
