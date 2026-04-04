class RemovePushNotificationTables < ActiveRecord::Migration[8.1]
  def up
    drop_table :device_registrations, if_exists: true
    drop_table :action_push_native_devices, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
