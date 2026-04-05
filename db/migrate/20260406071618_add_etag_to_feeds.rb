# frozen_string_literal: true

class AddEtagToFeeds < ActiveRecord::Migration[8.1]
  def change
    add_column :feeds, :etag, :string
    add_index :feeds, :etag
  end
end
