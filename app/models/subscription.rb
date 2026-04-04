class Subscription < ApplicationRecord
  belongs_to :user, counter_cache: true
  belongs_to :feed

  validates :user_id, uniqueness: { scope: :feed_id }
  normalizes :category, with: ->(value) { value&.strip.presence }
  normalizes :custom_name, with: ->(value) { value&.strip.presence }

  # Invalidate orphaned feeds cache when subscriptions change
  after_create :invalidate_orphaned_feeds_cache
  after_destroy :invalidate_orphaned_feeds_cache

  # Return display name (custom name if set, otherwise feed title)
  def display_name
    custom_name.presence || feed.title
  end

  private

  def invalidate_orphaned_feeds_cache
    Rails.cache.delete("orphaned_feeds_count")
  rescue StandardError => e
    Rails.logger.debug("Error invalidating orphaned feeds cache: #{e.message}")
  end
end
