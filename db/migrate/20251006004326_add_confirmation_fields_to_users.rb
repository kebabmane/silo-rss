class AddConfirmationFieldsToUsers < ActiveRecord::Migration[8.0]
  class User < ActiveRecord::Base
    self.table_name = "users"
  end

  def up
    add_column :users, :confirmed_at, :datetime
    add_reference :users, :confirmed_by, foreign_key: { to_table: :users }
    add_index :users, :confirmed_at

    timestamp = Time.current
    User.reset_column_information
    User.update_all(confirmed_at: timestamp)
  end

  def down
    remove_index :users, :confirmed_at
    remove_reference :users, :confirmed_by, foreign_key: true
    remove_column :users, :confirmed_at
  end
end
