class ArticlesController < ApplicationController
  before_action :set_article, only: [:show, :toggle_read, :toggle_starred, :toggle_archived, :fetch_content]

  def index
    @articles = Article.joins(feed: :subscriptions)
                      .where(subscriptions: { user_id: Current.user.id })
                      .includes(:feed)
                      .recent

    # Apply filters
    if params[:feed_id].present?
      @articles = @articles.where(feed_id: params[:feed_id])
    end

    if params[:category].present?
      # Avoid duplicate joins - already joined above
      @articles = @articles.where(subscriptions: { category: params[:category] })
    end

    if params[:filter] == "unread"
      @articles = @articles.left_joins(:article_states)
                          .where("article_states.id IS NULL OR (article_states.user_id = ? AND article_states.read = ?)", Current.user.id, false)
    elsif params[:filter] == "starred"
      @articles = @articles.joins(:article_states)
                          .where(article_states: { user_id: Current.user.id, starred: true })
    elsif params[:filter] == "archived"
      @articles = @articles.joins(:article_states)
                          .where(article_states: { user_id: Current.user.id, archived: true })
    else
      # Default: exclude archived
      @articles = @articles.left_joins(:article_states)
                          .where("article_states.id IS NULL OR (article_states.user_id = ? AND article_states.archived = ?)", Current.user.id, false)
    end

    @articles = @articles.limit(50)

    # Eager load article states for current user to prevent N+1 queries
    preload_article_states(@articles, Current.user)
  end

  def show
    @article_state = @article.state_for(Current.user)
  end

  def search
    query = params[:q]

    if query.present?
      @articles = Article.joins(feed: :subscriptions)
                        .where(subscriptions: { user_id: Current.user.id })
                        .search_text(query)
                        .includes(:feed)
                        .recent
                        .limit(50)

      # Eager load article states for current user
      preload_article_states(@articles, Current.user)
    else
      @articles = Article.none
    end

    # Select first article if available
    @selected_article = @articles.first

    respond_to do |format|
      format.html { render :search }
      format.turbo_stream
    end
  end

  def toggle_read
    state = @article.state_for(Current.user)
    state.update(read: !state.read)
    redirect_back fallback_location: dashboard_url, status: :see_other
  end

  def toggle_starred
    state = @article.state_for(Current.user)
    state.update(starred: !state.starred)
    redirect_back fallback_location: dashboard_url, status: :see_other
  end

  def toggle_archived
    state = @article.state_for(Current.user)
    state.update(archived: !state.archived)
    redirect_back fallback_location: dashboard_url, status: :see_other
  end

  def fetch_content
    # Clear existing full_content to force re-fetch
    @article.update(full_content: nil)

    # Fetch content synchronously for immediate feedback
    success = ArticleContentFetcherService.new(@article).fetch

    if success
      flash[:notice] = "Full content fetched successfully!"
    else
      flash[:alert] = "Failed to fetch full content. Please try again later."
    end

    # Redirect to reload the article with updated content
    redirect_to dashboard_path(article_id: @article.id)
  end

  private

  def set_article
    @article = Article
      .joins(feed: :subscriptions)
      .where(subscriptions: { user_id: Current.user.id })
      .includes(:feed)
      .find(params[:id])
  end

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
