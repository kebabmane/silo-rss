class AddDigestFieldsToDailyBriefs < ActiveRecord::Migration[8.0]
  def change
    add_column :daily_briefs, :digest_type, :string, default: "brief"
    add_column :daily_briefs, :sections, :json, default: []
    add_column :daily_briefs, :themes, :json, default: []
    add_column :daily_briefs, :reading_time_minutes, :integer
    add_column :daily_briefs, :generation_metadata, :json, default: {}
    add_column :daily_briefs, :article_ids, :json, default: []
  end
end
