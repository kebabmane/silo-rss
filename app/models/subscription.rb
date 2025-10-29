class Subscription < ApplicationRecord
  belongs_to :user, counter_cache: true
  belongs_to :feed

  validates :user_id, uniqueness: { scope: :feed_id }
  normalizes :category, with: ->(value) { value&.strip.presence }

  # Return display name (custom name if set, otherwise feed title)
  def display_name
    custom_name.presence || feed.title
  end
end
