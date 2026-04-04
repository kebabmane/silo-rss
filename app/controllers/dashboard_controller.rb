class DashboardController < ApplicationController
  include ArticleStatePreloader

  def index
    @categories = Current.user.subscriptions.distinct.pluck(:category).compact.sort
    subscriptions = Current.user.subscriptions.includes(:feed).order(:category, :custom_name).to_a
    # Group subscriptions by category in memory to avoid N+1 queries
    @subscriptions_by_category = subscriptions.group_by(&:category)
    @subscriptions = subscriptions

    # Load suggested feeds for onboarding modal
    @suggested_feeds = SuggestedFeed.ordered
    @suggested_feeds_by_category = @suggested_feeds.group_by(&:category)

    # Use query object for article filtering
    articles_query = ArticleFilterQuery.new(
      user: Current.user,
      feed_id: params[:feed_id],
      category: params[:category],
      filter: params[:filter] || "unread"
    ).call

    @selected_feed = Current.user.feeds.find_by(id: params[:feed_id]) if params[:feed_id].present?
    @selected_category = params[:category] if params[:category].present?
    @filter = params[:filter] || "unread"

    # Paginate articles - 20 per page for faster initial load
    @pagy, @articles = pagy(articles_query, items: 20)

    # Eager load article states for current user to prevent N+1 queries
    preload_article_states(@articles, Current.user)

    # Select first article if available
    @selected_article = find_selected_article
    @previous_article, @next_article = find_adjacent_articles if @selected_article
  end

  def more_articles
    # Use query object for article filtering
    articles_query = ArticleFilterQuery.new(
      user: Current.user,
      feed_id: params[:feed_id],
      category: params[:category],
      filter: params[:filter] || "unread"
    ).call

    # Validate page parameter
    page = (params[:page] || 1).to_i
    page = 1 if page < 1

    @pagy, @articles = pagy(articles_query, items: 20, page: page)

    preload_article_states(@articles, Current.user)

    respond_to do |format|
      format.turbo_stream
    end
  rescue Pagy::OverflowError
    # Handle invalid page numbers (e.g., page exceeds total pages)
    @articles = []
    respond_to do |format|
      format.turbo_stream { render :more_articles }
    end
  end

  def mark_onboarding_completed
    Current.user.complete_onboarding!
    head :ok
  end

  private

  def find_adjacent_articles
    articles_query = ArticleFilterQuery.new(
      user: Current.user,
      feed_id: params[:feed_id],
      category: params[:category],
      filter: params[:filter] || "unread"
    ).call

    # Previous = newer article (published later, appears earlier in the list)
    previous = articles_query.where("published_at > ?", @selected_article.published_at).first

    # Next = older article (published earlier, appears later in the list)
    next_article = articles_query.where("published_at < ?", @selected_article.published_at).first

    [ previous, next_article ]
  end

  def find_selected_article
    if params[:article_id].present?
      Article
        .joins(feed: :subscriptions)
        .where(subscriptions: { user_id: Current.user.id })
        .includes(:feed)
        .find_by(id: params[:article_id])
    else
      @articles.first
    end
  end
end
