class CreateDailyBriefFeedFilters < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_brief_feed_filters do |t|
      t.references :daily_brief_schedule, null: false, foreign_key: true
      t.references :feed, null: false, foreign_key: true

      t.timestamps
    end

    add_index :daily_brief_feed_filters, [:daily_brief_schedule_id, :feed_id],
              unique: true, name: "index_daily_brief_feed_filters_unique"
  end
end
