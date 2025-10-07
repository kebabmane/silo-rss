class CreateFeeds < ActiveRecord::Migration[8.0]
  def change
    create_table :feeds do |t|
      t.string :title
      t.string :feed_url, null: false
      t.string :site_url
      t.datetime :last_fetched_at

      t.timestamps
    end

    add_index :feeds, :feed_url, unique: true
  end
end
