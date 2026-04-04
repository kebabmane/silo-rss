class DropAiLlmTables < ActiveRecord::Migration[8.1]
  def up
    # Drop daily brief related tables
    drop_table :daily_brief_feed_filters, if_exists: true
    drop_table :daily_briefs, if_exists: true
    drop_table :daily_brief_schedules, if_exists: true

    # Drop LLM settings table
    drop_table :litellm_settings, if_exists: true
  end

  def down
    # Tables cannot be recovered - would need to recreate from old migrations
    raise ActiveRecord::IrreversibleMigration
  end
end
