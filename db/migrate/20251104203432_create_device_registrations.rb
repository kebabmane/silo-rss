class CreateDeviceRegistrations < ActiveRecord::Migration[8.0]
  def change
    create_table :device_registrations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :device_token, null: false
      t.string :platform, null: false, default: "android"
      t.datetime :last_seen_at

      t.timestamps
    end

    # Ensure each device token is unique per user
    add_index :device_registrations, [:user_id, :device_token], unique: true
    add_index :device_registrations, :device_token
    add_index :device_registrations, [:user_id, :platform]
  end
end
