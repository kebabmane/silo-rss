class ArticlesController < ApplicationController
  include ArticleStatePreloader

  rescue_from ActiveRecord::RecordNotFound, with: :raise_not_found if Rails.env.test?
  before_action :set_article_for_state, only: [:toggle_read, :toggle_starred, :toggle_archived]

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
      @articles = @articles.unread_for(Current.user)
    elsif params[:filter] == "starred"
      @articles = @articles.starred_for(Current.user).all_unarchived_for(Current.user)
    elsif params[:filter] == "archived"
      @articles = @articles.archived_for(Current.user)
    else
      # Default: exclude archived
      @articles = @articles.all_unarchived_for(Current.user)
    end

    @articles = @articles.limit(50)

    # Eager load article states for current user to prevent N+1 queries
    preload_article_states(@articles, Current.user)
  end

  def show
    @article = find_article_for_display!
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
    head :no_content
  end

  def toggle_starred
    state = @article.state_for(Current.user)
    state.update(starred: !state.starred)
    head :no_content
  end

  def toggle_archived
    state = @article.state_for(Current.user)
    state.update(archived: !state.archived)
    redirect_to articles_path
  end

  def fetch_content
    @article = find_article_for_display!
    # Clear existing full_content to force re-fetch
    @article.update(full_content: nil)

    # Enqueue background job for async content fetching
    ArticleContentFetchJob.perform_later(@article.id)

    redirect_to dashboard_path(article_id: @article.id), notice: "Full content fetch has been queued."
  end

  private

  def find_article_for_display!
    article = Article.includes(:feed).find(params[:id])
    raise ActiveRecord::RecordNotFound unless Current.user.feeds.exists?(article.feed_id)
    article
  end

  def set_article_for_state
    @article = Article.joins(feed: :subscriptions)
                      .where(subscriptions: { user_id: Current.user.id })
                      .find(params[:id])
  end

  def raise_not_found(exception)
    raise exception
  end
end
