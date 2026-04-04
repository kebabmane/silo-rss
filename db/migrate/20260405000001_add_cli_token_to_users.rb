class AddCliTokenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :cli_token, :string
    add_column :users, :cli_token_digest, :string
    add_column :users, :cli_token_generated_at, :datetime

    add_index :users, :cli_token_digest, unique: true
  end
end
