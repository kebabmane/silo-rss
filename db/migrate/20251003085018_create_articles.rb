class CreateArticles < ActiveRecord::Migration[8.0]
  def change
    create_table :articles do |t|
      t.references :feed, null: false, foreign_key: true
      t.string :title
      t.text :content
      t.string :url
      t.string :guid
      t.datetime :published_at

      t.timestamps
    end

    add_index :articles, [ :feed_id, :guid ], unique: true
    add_index :articles, :published_at
  end
end
