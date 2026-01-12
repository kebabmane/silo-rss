class ScheduledRefreshJob < ApplicationJob
  queue_as :default

  def perform
    Feed.find_each(batch_size: 50) do |feed|
      FeedRefreshJob.perform_later(feed.id)
    end
  end
end
