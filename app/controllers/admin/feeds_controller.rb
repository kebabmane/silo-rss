class Admin::FeedsController < AdminController
  before_action :set_feed, only: [:destroy]

  def index
    # Load feeds with eager-loaded subscriptions to avoid N+1 queries
    # Note: For very large datasets (>10k feeds), add pagination with pagy gem
    @feeds = Feed.includes(:subscriptions).order(updated_at: :desc)

    # Add subscriber_count to each feed from already-loaded subscriptions
    @feeds.each do |feed|
      feed.define_singleton_method(:subscriber_count) { subscriptions.size }
    end

    # Get cached orphaned feeds count or calculate if not cached
    @orphaned_feeds_count = begin
      Rails.cache.fetch('orphaned_feeds_count', expires_in: 1.hour) do
        Feed.left_outer_joins(:subscriptions)
            .group("feeds.id")
            .having("COUNT(subscriptions.id) = 0")
            .count
            .size
      end
    rescue StandardError => e
      Rails.logger.debug("Error fetching orphaned feeds count: #{e.message}")
      0
    end
  end

  def destroy
    subscriber_count = @feed.subscriptions.count

    if subscriber_count > 0
      redirect_to admin_feeds_path, alert: "Cannot delete feed with active subscribers."
      return
    end

    feed_title = @feed.title
    @feed.destroy

    # Invalidate orphaned feeds cache
    begin
      Rails.cache.delete('orphaned_feeds_count')
    rescue StandardError => e
      Rails.logger.debug("Error deleting orphaned feeds cache: #{e.message}")
    end

    redirect_to admin_feeds_path, notice: "Feed '#{feed_title}' has been deleted."
  end

  private

  def set_feed
    @feed = Feed.find(params[:id])
  end
end
