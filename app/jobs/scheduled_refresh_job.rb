class ScheduledRefreshJob < ApplicationJob
  queue_as :default

  # Only refresh feeds that haven't been fetched in the last 30 minutes
  # This prevents unnecessary API calls and respects RSS provider rate limits
  REFRESH_THRESHOLD = 30.minutes

  def perform
    feeds_to_refresh = stale_feeds

    if feeds_to_refresh.any?
      Rails.logger.info "[ScheduledRefreshJob] Refreshing #{feeds_to_refresh.count} stale feeds (threshold: #{REFRESH_THRESHOLD.inspect})"

      feeds_to_refresh.find_each(batch_size: 50) do |feed|
        FeedRefreshJob.perform_later(feed.id)
      end
    else
      Rails.logger.info "[ScheduledRefreshJob] No stale feeds to refresh (all feeds fetched within last #{REFRESH_THRESHOLD.inspect})"
    end
  end

  private

  def stale_feeds
    Feed.where("last_fetched_at IS NULL OR last_fetched_at < ?", REFRESH_THRESHOLD.ago)
  end
end
