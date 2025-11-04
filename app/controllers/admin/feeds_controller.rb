class Admin::FeedsController < ApplicationController
  before_action :ensure_admin!
  before_action :set_feed, only: [:destroy]

  def index
    @feeds = Feed.includes(:subscriptions).order(updated_at: :desc)
    @orphaned_feeds = @feeds.select { |feed| feed.subscriptions.empty? }
  end

  def destroy
    subscriber_count = @feed.subscriptions.count

    if subscriber_count > 0
      redirect_to admin_feeds_path, alert: "Cannot delete feed with active subscribers."
      return
    end

    feed_title = @feed.title
    @feed.destroy
    redirect_to admin_feeds_path, notice: "Feed '#{feed_title}' has been deleted."
  end

  private

  def set_feed
    @feed = Feed.find(params[:id])
  end

  def ensure_admin!
    redirect_to dashboard_path, alert: "Access denied." unless Current.user&.admin?
  end
end
