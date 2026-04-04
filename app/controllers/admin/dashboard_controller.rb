class Admin::DashboardController < AdminController
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

  def calculate_database_size
    # For SQLite, get the actual database file size from configuration
    config = Rails.configuration.database_configuration[Rails.env]
    db_path = config&.dig("database")

    return "N/A" unless db_path

    # Handle both absolute and relative paths
    full_path = if Pathname.new(db_path).absolute?
                  db_path
    else
                  File.join(Rails.root, db_path)
    end

    if File.exist?(full_path)
      size_bytes = File.size(full_path)
      format_bytes(size_bytes)
    else
      "N/A"
    end
  rescue => e
    Rails.logger.debug("Error calculating database size: #{e.message}")
    "N/A"
  end

  def format_bytes(bytes)
    return "0 B" if bytes == 0

    units = [ "B", "KB", "MB", "GB" ]
    size = bytes.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end

    "#{size.round(2)} #{units[unit_index]}"
  end

  def calculate_orphaned_feeds_count
    # Use cached count to reduce database queries
    Rails.cache.fetch("orphaned_feeds_count", expires_in: 1.hour) do
      Feed.left_outer_joins(:subscriptions)
          .group("feeds.id")
          .having("COUNT(subscriptions.id) = 0")
          .count
          .size
    end
  end
end
