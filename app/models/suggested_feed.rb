class SuggestedFeed < ApplicationRecord
  validates :title, :feed_url, :category, presence: true
  validates :feed_url, uniqueness: true
  validates :display_order, numericality: { only_integer: true }, allow_nil: true

  scope :ordered, -> { order(display_order: :asc, created_at: :asc) }
  scope :by_category, ->(category) { where(category: category) }

  def self.categories
    distinct.pluck(:category).sort
  end
end
