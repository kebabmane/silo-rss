class AddDigestTypeToSchedules < ActiveRecord::Migration[8.0]
  def change
    add_column :daily_brief_schedules, :digest_type, :string, default: "brief", null: false
  end
end
