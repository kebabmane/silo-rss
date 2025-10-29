class CreateSuggestedFeeds < ActiveRecord::Migration[8.0]
  def change
    create_table :suggested_feeds do |t|
      t.string :title
      t.string :feed_url
      t.string :category
      t.text :description
      t.integer :display_order

      t.timestamps
    end
  end
end
