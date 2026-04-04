class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Composite index for subscriptions filtered by user and category
    add_index :subscriptions, [ :user_id, :category ], name: "index_subscriptions_on_user_id_and_category"

    # Composite index for articles ordered by feed and publication date
    add_index :articles, [ :feed_id, :published_at ], name: "index_articles_on_feed_id_and_published_at"

    # Composite index for article states filtered by user, read status, and archived status
    add_index :article_states, [ :user_id, :read, :archived ], name: "index_article_states_on_user_read_archived"

    # Partial index for starred articles by user
    add_index :article_states, [ :user_id, :starred ], where: "starred = true", name: "index_article_states_on_user_starred"

    # Index for API token expiration checks
    add_index :users, :api_token_expires_at, name: "index_users_on_api_token_expires_at"

    # Partial index for unread articles by user
    add_index :article_states, :user_id, where: "read = false", name: "index_article_states_on_user_unread"

    # Partial index for active daily brief schedules
    add_index :daily_brief_schedules, :user_id, where: "active = true", name: "index_daily_brief_schedules_on_user_active"
  end
end
