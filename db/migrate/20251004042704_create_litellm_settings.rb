class CreateLitellmSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :litellm_settings do |t|
      t.string :server_url
      t.string :api_key
      t.string :default_model
      t.integer :max_tokens, default: 4000
      t.decimal :temperature, precision: 3, scale: 2, default: 0.7
      t.integer :timeout, default: 30
      t.boolean :enabled, default: true, null: false

      t.timestamps
    end
  end
end
