# frozen_string_literal: true

class Feed < ApplicationRecord
  has_many :articles, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :users, through: :subscriptions

  validates :feed_url, presence: true, uniqueness: true
  validates :title, presence: true

  # Scopes
  scope :for_user, ->(user) {
    joins(:subscriptions).where(subscriptions: { user_id: user.id })
  }
  scope :sync_since, ->(timestamp) {
    return all if timestamp.blank?

    where("feeds.updated_at > ?", timestamp)
  }

  # Invalidate orphaned feeds cache when feeds are created or destroyed
  after_create :invalidate_orphaned_feeds_cache
  after_destroy :invalidate_orphaned_feeds_cache

  private

  def invalidate_orphaned_feeds_cache
    Rails.cache.delete("orphaned_feeds_count")
  rescue StandardError => e
    Rails.logger.debug("Error invalidating orphaned feeds cache: #{e.message}")
  end
end
