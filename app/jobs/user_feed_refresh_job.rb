# frozen_string_literal: true

class UserFeedRefreshJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.includes(feeds: :subscriptions).find_by(id: user_id)
    return unless user

    user.feeds.distinct.find_each do |feed|
      FeedRefreshJob.perform_later(feed.id)
    end
  end
end
