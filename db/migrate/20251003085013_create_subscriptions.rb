class CreateSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :feed, null: false, foreign_key: true
      t.string :category
      t.string :custom_name

      t.timestamps
    end
  end
end
