class FeedRefreshJob < ApplicationJob
  queue_as :default

  # Retry on network errors with exponential backoff
  retry_on StandardError, wait: :polynomially_longer, attempts: 3 do |_job, _error|
    Rails.logger.warn "[FeedRefreshJob] Retrying after error: #{_error.message}"
  end

  def perform(feed_id)
    feed = Feed.find_by(id: feed_id)
    return unless feed

    Rails.logger.info "[FeedRefreshJob] Refreshing feed: #{feed.title} (ID: #{feed.id})"

    begin
      articles = FeedFetcherService.new(feed).fetch
      new_count = articles.count { |a| a.created_at > 5.minutes.ago } rescue 0
      Rails.logger.info "[FeedRefreshJob] Successfully refreshed #{feed.title}: #{articles.count} articles (#{new_count} new)"
    rescue => e
      Rails.logger.error "[FeedRefreshJob] Failed to refresh #{feed.title}: #{e.class} - #{e.message}"
      raise # Re-raise to trigger retry
    end
  end
end
