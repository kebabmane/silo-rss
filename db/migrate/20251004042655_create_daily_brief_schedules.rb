class CreateDailyBriefSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_brief_schedules do |t|
      t.references :user, null: false, foreign_key: true
      t.time :time_of_day, null: false
      t.json :days_of_week, default: [], null: false
      t.boolean :email_delivery, default: false, null: false
      t.boolean :include_all_feeds, default: true, null: false
      t.string :summary_length, default: "medium", null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :daily_brief_schedules, [:user_id, :active]
  end
end
