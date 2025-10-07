class FeedRefreshJob < ApplicationJob
  queue_as :default

  def perform(feed_id)
    feed = Feed.find_by(id: feed_id)
    return unless feed

    FeedFetcherService.new(feed).fetch
    nil
  end
end
