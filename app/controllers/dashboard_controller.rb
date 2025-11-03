class DashboardController < ApplicationController
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
      articles_query = articles_query.left_joins(:article_states)
                                    .where("article_states.id IS NULL OR (article_states.user_id = ? AND article_states.read = ?)", Current.user.id, false)
    elsif @filter == "starred"
      articles_query = articles_query.joins(:article_states)
                                    .where(article_states: { user_id: Current.user.id, starred: true })
    elsif @filter == "archived"
      articles_query = articles_query.joins(:article_states)
                                    .where(article_states: { user_id: Current.user.id, archived: true })
    end

    # Always exclude archived from default views unless explicitly filtered
    unless @filter == "archived"
      articles_query = articles_query.left_joins(:article_states)
                                    .where("article_states.id IS NULL OR (article_states.user_id = ? AND article_states.archived = ?)", Current.user.id, false)
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
    @categories = Current.user.subscriptions.distinct.pluck(:category).compact.sort
    subscriptions = Current.user.subscriptions.includes(:feed).order(:category, :custom_name).to_a
    @subscriptions_by_category = subscriptions.group_by(&:category)

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
      articles_query = articles_query.left_joins(:article_states)
                                    .where("article_states.id IS NULL OR (article_states.user_id = ? AND article_states.read = ?)", Current.user.id, false)
    elsif filter == "starred"
      articles_query = articles_query.joins(:article_states)
                                    .where(article_states: { user_id: Current.user.id, starred: true })
    elsif filter == "archived"
      articles_query = articles_query.joins(:article_states)
                                    .where(article_states: { user_id: Current.user.id, archived: true })
    end

    unless filter == "archived"
      articles_query = articles_query.left_joins(:article_states)
                                    .where("article_states.id IS NULL OR (article_states.user_id = ? AND article_states.archived = ?)", Current.user.id, false)
    end

    # Validate page parameter
    page = (params[:page] || 1).to_i
    page = 1 if page < 1

    puts "[InfiniteScroll Server] Fetching page #{page}, filter: #{filter}, feed_id: #{params[:feed_id]}, category: #{params[:category]}"
    puts "[InfiniteScroll Server] Total articles matching query: #{articles_query.count}"

    @pagy, @articles = pagy(articles_query, items: 20, page: page)

    puts "[InfiniteScroll Server] Page #{page} returned #{@articles.count} articles"
    puts "[InfiniteScroll Server] @pagy.next: #{@pagy.next.inspect}"
    puts "[InfiniteScroll Server] @pagy.last?: #{@pagy.last?}"

    preload_article_states(@articles, Current.user)

    respond_to do |format|
      format.turbo_stream
    end
  rescue StandardError => e
    # Handle any errors (invalid page, etc.)
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

  def preload_article_states(articles, user)
    # Get article IDs
    article_ids = articles.map(&:id)

    # Load all article states for these articles and this user in one query
    states = ArticleState.where(article_id: article_ids, user_id: user.id).to_a

    # Create a hash for quick lookup
    states_by_article_id = states.index_by(&:article_id)

    # Preload the states into the articles association
    articles.each do |article|
      state = states_by_article_id[article.id]
      article.association(:article_states).target = state ? [state] : []
      article.association(:article_states).loaded!
    end
  end
end
