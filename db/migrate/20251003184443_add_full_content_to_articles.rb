class AddFullContentToArticles < ActiveRecord::Migration[8.0]
  def change
    add_column :articles, :full_content, :text
  end
end
