# frozen_string_literal: true

ActiveRecord::Schema[8.1].define(version: 2026_04_05_000001) do
  create_table "article_states", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "article_id", null: false
    t.boolean "read", default: false
    t.boolean "starred", default: false
    t.boolean "archived", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "article_id" ], name: "index_article_states_on_article_id"
    t.index [ "user_id", "article_id" ], name: "index_article_states_on_user_id_and_article_id", unique: true
    t.index [ "user_id" ], name: "index_article_states_on_user_id"
  end

  create_table "articles", force: :cascade do |t|
    t.integer "feed_id", null: false
    t.string "title"
    t.text "content"
    t.string "url"
    t.string "guid", null: false
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "full_content"
    t.index [ "feed_id", "published_at" ], name: "index_articles_on_feed_id_and_published_at"
    t.index [ "feed_id" ], name: "index_articles_on_feed_id"
    t.index [ "guid", "feed_id" ], name: "index_articles_on_guid_and_feed_id", unique: true
  end

  create_table "feeds", force: :cascade do |t|
    t.string "title", null: false
    t.string "feed_url", null: false
    t.string "site_url"
    t.datetime "last_fetched_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "articles_count", default: 0
    t.integer "subscriptions_count", default: 0
    t.index [ "feed_url" ], name: "index_feeds_on_feed_url", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "expires_at"
    t.index [ "user_id" ], name: "index_sessions_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "key" ], name: "index_settings_on_key", unique: true
  end

  create_table "subscriptions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "feed_id", null: false
    t.string "category"
    t.string "custom_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "feed_id" ], name: "index_subscriptions_on_feed_id"
    t.index [ "user_id", "category" ], name: "index_subscriptions_on_user_id_and_category"
    t.index [ "user_id", "feed_id" ], name: "index_subscriptions_on_user_id_and_feed_id", unique: true
    t.index [ "user_id" ], name: "index_subscriptions_on_user_id"
  end

  create_table "suggested_feeds", force: :cascade do |t|
    t.string "title", null: false
    t.string "feed_url", null: false
    t.string "site_url"
    t.string "category"
    t.text "description"
    t.integer "display_order", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "feed_url" ], name: "index_suggested_feeds_on_feed_url", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "api_token"
    t.string "time_zone", default: "UTC"
    t.datetime "confirmed_at"
    t.integer "confirmed_by_id"
    t.string "password_reset_digest"
    t.datetime "password_reset_sent_at"
    t.boolean "admin", default: false
    t.string "api_token_digest"
    t.datetime "api_token_expires_at"
    t.datetime "onboarding_completed_at"
    t.integer "subscriptions_count", default: 0
    t.string "cli_token"
    t.string "cli_token_digest"
    t.datetime "cli_token_generated_at"
    t.index [ "api_token_digest" ], name: "index_users_on_api_token_digest"
    t.index [ "cli_token_digest" ], name: "index_users_on_cli_token_digest", unique: true
    t.index [ "confirmed_by_id" ], name: "index_users_on_confirmed_by_id"
    t.index [ "email_address" ], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "article_states", "articles"
  add_foreign_key "article_states", "users"
  add_foreign_key "articles", "feeds"
  add_foreign_key "sessions", "users"
  add_foreign_key "subscriptions", "feeds"
  add_foreign_key "subscriptions", "users"
  add_foreign_key "users", "users", column: "confirmed_by_id"
end
