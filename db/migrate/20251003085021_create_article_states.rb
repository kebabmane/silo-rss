class CreateArticleStates < ActiveRecord::Migration[8.0]
  def change
    create_table :article_states do |t|
      t.references :user, null: false, foreign_key: true
      t.references :article, null: false, foreign_key: true
      t.boolean :read, default: false, null: false
      t.boolean :starred, default: false, null: false
      t.boolean :archived, default: false, null: false

      t.timestamps
    end

    add_index :article_states, [ :user_id, :article_id ], unique: true
  end
end
