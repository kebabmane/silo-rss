class Admin::DashboardController < ApplicationController
  before_action :require_admin

  def index
    @total_users = User.count
    @total_feeds = Feed.count
    @total_articles = Article.count
    @orphaned_feeds_count = calculate_orphaned_feeds_count
    @recent_users = User.order(created_at: :desc).limit(5)
    @system_stats = {
      active_jobs: ActiveJob::Base.queue_adapter.instance_variable_get(:@enqueued_jobs)&.size || 0,
      database_size: calculate_database_size
    }
  end

  private

  def require_admin
    unless Current.user&.admin?
      redirect_to root_path, alert: "You must be an admin to access this page."
    end
  end

  def calculate_database_size
    # Get approximate database size
    result = ActiveRecord::Base.connection.execute(
      "SELECT pg_size_pretty(pg_database_size(current_database())) as size"
    ).first
    result ? result["size"] : "N/A"
  rescue
    "N/A"
  end

  def calculate_orphaned_feeds_count
    Feed.left_outer_joins(:subscriptions)
        .group("feeds.id")
        .having("COUNT(subscriptions.id) = 0")
        .count
  end
end
