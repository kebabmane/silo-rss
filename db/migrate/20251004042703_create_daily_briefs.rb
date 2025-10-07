class CreateDailyBriefs < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_briefs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :daily_brief_schedule, null: false, foreign_key: true
      t.text :content
      t.integer :article_count, default: 0, null: false
      t.datetime :generated_at, null: false
      t.datetime :emailed_at
      t.boolean :read, default: false, null: false

      t.timestamps
    end

    add_index :daily_briefs, [:user_id, :generated_at]
    add_index :daily_briefs, :generated_at
  end
end
