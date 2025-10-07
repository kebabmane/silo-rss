class AddCounterCaches < ActiveRecord::Migration[8.0]
  def change
    # Add counter cache for articles count on feeds
    add_column :feeds, :articles_count, :integer, default: 0, null: false

    # Add counter cache for subscriptions count on users
    add_column :users, :subscriptions_count, :integer, default: 0, null: false

    # Backfill existing counts
    reversible do |dir|
      dir.up do
        Feed.find_each do |feed|
          Feed.reset_counters(feed.id, :articles)
        end

        User.find_each do |user|
          User.reset_counters(user.id, :subscriptions)
        end
      end
    end
  end
end
