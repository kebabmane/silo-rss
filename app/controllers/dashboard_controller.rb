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

    # Get articles for the selected feed/category or all articles
    articles_query = Article.joins(feed: :subscriptions)
                            .where(subscriptions: { user_id: Current.user.id })
                            .includes(:feed)
                            .recent

    # Apply filters
    if params[:feed_id].present?
      articles_query = articles_query.where(feed_id: params[:feed_id])
      @selected_feed = Current.user.feeds.find_by(id: params[:feed_id])
    end

    if params[:category].present?
      # Avoid duplicate joins - already joined above
      articles_query = articles_query.where(subscriptions: { category: params[:category] })
      @selected_category = params[:category]
    end

    # Default: show unread articles only
    @filter = params[:filter] || "unread"
    if @filter == "unread"
      # unread_for scope already excludes archived articles
      articles_query = articles_query.unread_for(Current.user)
    elsif @filter == "starred"
      articles_query = articles_query.starred_for(Current.user).all_unarchived_for(Current.user)
    elsif @filter == "archived"
      articles_query = articles_query.archived_for(Current.user)
    else
      articles_query = articles_query.all_unarchived_for(Current.user)
    end

    # Paginate articles - 20 per page for faster initial load
    @pagy, @articles = pagy(articles_query, items: 20)

    # Eager load article states for current user to prevent N+1 queries
    preload_article_states(@articles, Current.user)

    # Select first article if available
    if params[:article_id].present?
      @selected_article = Article
        .joins(feed: :subscriptions)
        .where(subscriptions: { user_id: Current.user.id })
        .includes(:feed)
        .find_by(id: params[:article_id])
    else
      @selected_article = @articles.first
    end
  end

  def more_articles
    # Fetch additional articles for infinite scrolling
    articles_query = Article.joins(feed: :subscriptions)
                            .where(subscriptions: { user_id: Current.user.id })
                            .includes(:feed)
                            .recent

    if params[:feed_id].present?
      articles_query = articles_query.where(feed_id: params[:feed_id])
    end

    if params[:category].present?
      articles_query = articles_query.where(subscriptions: { category: params[:category] })
    end

    filter = params[:filter] || "unread"
    if filter == "unread"
      articles_query = articles_query.unread_for(Current.user)
    elsif filter == "starred"
      articles_query = articles_query.starred_for(Current.user).all_unarchived_for(Current.user)
    elsif filter == "archived"
      articles_query = articles_query.archived_for(Current.user)
    else
      articles_query = articles_query.all_unarchived_for(Current.user)
    end

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

end
