class AddTokenExpirationToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :api_token_expires_at, :datetime
  end
end
