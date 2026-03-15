class AddUniqueIndexToSettingsKey < ActiveRecord::Migration[8.0]
  def change
    add_index :settings, :key, unique: true, if_not_exists: true
  end
end
