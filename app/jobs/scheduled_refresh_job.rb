class ScheduledRefreshJob < ApplicationJob
  queue_as :default

  def perform
    # Process feeds in batches to avoid overwhelming the queue
    first_batch = true
    Feed.find_in_batches(batch_size: 50) do |batch|
      # Small delay between batches to prevent queue overflow
      sleep 0.5 unless first_batch
      first_batch = false

      batch.each do |feed|
        FeedRefreshJob.perform_later(feed.id)
      end
    end
  end
end
