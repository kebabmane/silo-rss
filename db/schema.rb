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

ActiveRecord::Schema[8.1].define(version: 2026_04_06_071618) do
  create_table "article_states", force: :cascade do |t|
    t.boolean "archived", default: false, null: false
    t.integer "article_id", null: false
    t.datetime "created_at", null: false
    t.boolean "read", default: false, null: false
    t.boolean "starred", default: false, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index [ "article_id" ], name: "index_article_states_on_article_id"
    t.index [ "user_id", "article_id" ], name: "index_article_states_on_user_id_and_article_id", unique: true
    t.index [ "user_id", "read", "archived" ], name: "index_article_states_on_user_read_archived"
    t.index [ "user_id", "starred" ], name: "index_article_states_on_user_starred", where: "starred = true"
    t.index [ "user_id" ], name: "index_article_states_on_user_id"
    t.index [ "user_id" ], name: "index_article_states_on_user_unread", where: "read = false"
  end

  create_table "articles", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "feed_id", null: false
    t.text "full_content"
    t.string "guid"
    t.datetime "published_at"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index [ "feed_id", "guid" ], name: "index_articles_on_feed_id_and_guid", unique: true
    t.index [ "feed_id", "published_at" ], name: "index_articles_on_feed_id_and_published_at"
    t.index [ "feed_id" ], name: "index_articles_on_feed_id"
    t.index [ "published_at" ], name: "index_articles_on_published_at"
  end

  create_table "feeds", force: :cascade do |t|
    t.integer "articles_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "etag"
    t.string "feed_url", null: false
    t.datetime "last_fetched_at"
    t.string "site_url"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index [ "etag" ], name: "index_feeds_on_etag"
    t.index [ "feed_url" ], name: "index_feeds_on_feed_url", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index [ "user_id" ], name: "index_sessions_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key"
    t.datetime "updated_at", null: false
    t.string "value"
    t.index [ "key" ], name: "index_settings_on_key", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index [ "concurrency_key", "priority", "job_id" ], name: "index_solid_queue_blocked_executions_for_release"
    t.index [ "expires_at", "concurrency_key" ], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index [ "job_id" ], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index [ "job_id" ], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index [ "process_id", "job_id" ], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index [ "job_id" ], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index [ "active_job_id" ], name: "index_solid_queue_jobs_on_active_job_id"
    t.index [ "class_name" ], name: "index_solid_queue_jobs_on_class_name"
    t.index [ "finished_at" ], name: "index_solid_queue_jobs_on_finished_at"
    t.index [ "queue_name", "finished_at" ], name: "index_solid_queue_jobs_for_filtering"
    t.index [ "scheduled_at", "finished_at" ], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index [ "queue_name" ], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index [ "last_heartbeat_at" ], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index [ "name", "supervisor_id" ], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index [ "supervisor_id" ], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index [ "job_id" ], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index [ "priority", "job_id" ], name: "index_solid_queue_poll_all"
    t.index [ "queue_name", "priority", "job_id" ], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index [ "job_id" ], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index [ "task_key", "run_at" ], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index [ "key" ], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index [ "static" ], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index [ "job_id" ], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index [ "scheduled_at", "priority", "job_id" ], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index [ "expires_at" ], name: "index_solid_queue_semaphores_on_expires_at"
    t.index [ "key", "value" ], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index [ "key" ], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "subscriptions", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.string "custom_name"
    t.integer "feed_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index [ "feed_id" ], name: "index_subscriptions_on_feed_id"
    t.index [ "user_id", "category" ], name: "index_subscriptions_on_user_id_and_category"
    t.index [ "user_id" ], name: "index_subscriptions_on_user_id"
  end

  create_table "suggested_feeds", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "display_order"
    t.string "feed_url"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.string "api_token"
    t.string "api_token_digest"
    t.datetime "api_token_expires_at"
    t.string "cli_token"
    t.string "cli_token_digest"
    t.datetime "cli_token_generated_at"
    t.datetime "confirmed_at"
    t.integer "confirmed_by_id"
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.datetime "onboarding_completed_at"
    t.string "password_digest", null: false
    t.string "password_reset_digest"
    t.datetime "password_reset_sent_at"
    t.integer "subscriptions_count", default: 0, null: false
    t.string "time_zone", default: "Etc/UTC", null: false
    t.datetime "updated_at", null: false
    t.index [ "admin" ], name: "index_users_on_admin"
    t.index [ "api_token" ], name: "index_users_on_api_token", unique: true
    t.index [ "api_token_digest" ], name: "index_users_on_api_token_digest", unique: true
    t.index [ "api_token_expires_at" ], name: "index_users_on_api_token_expires_at"
    t.index [ "cli_token_digest" ], name: "index_users_on_cli_token_digest", unique: true
    t.index [ "confirmed_at" ], name: "index_users_on_confirmed_at"
    t.index [ "confirmed_by_id" ], name: "index_users_on_confirmed_by_id"
    t.index [ "email_address" ], name: "index_users_on_email_address", unique: true
    t.index [ "password_reset_digest" ], name: "index_users_on_password_reset_digest", unique: true
  end

  add_foreign_key "article_states", "articles"
  add_foreign_key "article_states", "users"
  add_foreign_key "articles", "feeds"
  add_foreign_key "sessions", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "subscriptions", "feeds"
  add_foreign_key "subscriptions", "users"
  add_foreign_key "users", "users", column: "confirmed_by_id"
end
